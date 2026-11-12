#include "include/openidconnect_windows/web_auth.h"

#include <windows.h>
#include <wrl.h>

#include <cstdlib>
#include <cstring>
#include <mutex>
#include <string>

#include <WebView2.h>

using Microsoft::WRL::Callback;
using Microsoft::WRL::ComPtr;

namespace {

constexpr wchar_t kWindowClass[] = L"OpenIdConnectWebAuthWindow";

std::wstring Utf8ToWide(const char* utf8) {
  if (utf8 == nullptr || utf8[0] == '\0') {
    return std::wstring();
  }
  const int length = MultiByteToWideChar(CP_UTF8, 0, utf8, -1, nullptr, 0);
  std::wstring output(static_cast<size_t>(length - 1), L'\0');
  MultiByteToWideChar(CP_UTF8, 0, utf8, -1, output.data(), length);
  return output;
}

std::string WideToUtf8(const wchar_t* wide) {
  if (wide == nullptr || wide[0] == L'\0') {
    return std::string();
  }
  const int length =
      WideCharToMultiByte(CP_UTF8, 0, wide, -1, nullptr, 0, nullptr, nullptr);
  std::string output(static_cast<size_t>(length - 1), '\0');
  WideCharToMultiByte(CP_UTF8, 0, wide, -1, output.data(), length, nullptr,
                      nullptr);
  return output;
}

bool CallbackMatchesRedirect(const std::string& callback,
                             const std::string& redirect) {
  if (callback == redirect) {
    return true;
  }
  if (callback.size() <= redirect.size()) {
    return false;
  }
  if (callback.compare(0, redirect.size(), redirect) != 0) {
    return false;
  }
  const char next = callback[redirect.size()];
  return next == '?' || next == '#' || next == '/';
}

char* CopyCString(const char* value) {
  if (value == nullptr) {
    return nullptr;
  }
  const size_t length = std::strlen(value);
  char* copy = static_cast<char*>(std::malloc(length + 1));
  if (copy == nullptr) {
    return nullptr;
  }
  std::memcpy(copy, value, length + 1);
  return copy;
}

void SendCompletion(OidcWebAuthCompletion completion, const char* callback_url,
                    const char* error, int32_t cancelled) {
  if (completion == nullptr) {
    return;
  }
  completion(CopyCString(callback_url), CopyCString(error), cancelled);
}

struct AuthSession {
  HWND hwnd = nullptr;
  ComPtr<ICoreWebView2Controller> controller;
  ComPtr<ICoreWebView2> webview;
  std::string redirect_url;
  std::wstring authorization_url;
  OidcWebAuthCompletion completion = nullptr;
  EventRegistrationToken navigation_token{};
  int width = 640;
  int height = 600;
  bool completed = false;
};

std::mutex g_mutex;
AuthSession* g_session = nullptr;
bool g_class_registered = false;

void InvokeCompletion(AuthSession* session, const char* callback_url,
                      const char* error, int32_t cancelled) {
  OidcWebAuthCompletion completion = nullptr;
  HWND hwnd = nullptr;
  {
    std::lock_guard<std::mutex> lock(g_mutex);
    if (session == nullptr || session->completed) {
      return;
    }
    session->completed = true;
    completion = session->completion;
    session->completion = nullptr;
    hwnd = session->hwnd;
  }
  SendCompletion(completion, callback_url, error, cancelled);
  if (hwnd != nullptr) {
    PostMessage(hwnd, WM_CLOSE, 0, 0);
  }
}

LRESULT CALLBACK AuthWndProc(HWND hwnd, UINT message, WPARAM wparam,
                             LPARAM lparam) {
  auto* session =
      reinterpret_cast<AuthSession*>(GetWindowLongPtr(hwnd, GWLP_USERDATA));

  switch (message) {
    case WM_SIZE:
      if (session != nullptr && session->controller != nullptr) {
        RECT bounds;
        GetClientRect(hwnd, &bounds);
        session->controller->put_Bounds(bounds);
      }
      return 0;
    case WM_CLOSE:
      if (session != nullptr && !session->completed) {
        InvokeCompletion(session, nullptr, nullptr, 1);
      }
      DestroyWindow(hwnd);
      return 0;
    case WM_DESTROY:
      if (session != nullptr) {
        if (session->webview != nullptr) {
          session->webview->remove_NavigationStarting(session->navigation_token);
        }
        session->controller = nullptr;
        session->webview = nullptr;
      }
      PostQuitMessage(0);
      return 0;
    default:
      return DefWindowProc(hwnd, message, wparam, lparam);
  }
}

void RegisterWindowClass() {
  if (g_class_registered) {
    return;
  }
  WNDCLASSEXW window_class = {};
  window_class.cbSize = sizeof(window_class);
  window_class.style = CS_HREDRAW | CS_VREDRAW;
  window_class.lpfnWndProc = AuthWndProc;
  window_class.hInstance = GetModuleHandle(nullptr);
  window_class.hCursor = LoadCursor(nullptr, IDC_ARROW);
  window_class.hbrBackground = reinterpret_cast<HBRUSH>(COLOR_WINDOW + 1);
  window_class.lpszClassName = kWindowClass;
  RegisterClassExW(&window_class);
  g_class_registered = true;
}

HRESULT AttachWebView(AuthSession* session) {
  wchar_t temp_path[MAX_PATH];
  GetTempPathW(MAX_PATH, temp_path);
  const std::wstring user_data =
      std::wstring(temp_path) + L"openidconnect_webview2";

  return CreateCoreWebView2EnvironmentWithOptions(
      nullptr, user_data.c_str(), nullptr,
      Callback<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler>(
          [session](HRESULT result, ICoreWebView2Environment* environment)
              -> HRESULT {
            if (FAILED(result) || environment == nullptr) {
              InvokeCompletion(
                  session, nullptr,
                  "The WebView2 runtime is missing or failed to start.", 0);
              return result;
            }
            return environment->CreateCoreWebView2Controller(
                session->hwnd,
                Callback<
                    ICoreWebView2CreateCoreWebView2ControllerCompletedHandler>(
                    [session](HRESULT result,
                              ICoreWebView2Controller* controller) -> HRESULT {
                      if (FAILED(result) || controller == nullptr) {
                        InvokeCompletion(
                            session, nullptr,
                            "Failed to create the WebView2 authentication window.",
                            0);
                        return result;
                      }
                      session->controller = controller;
                      controller->get_CoreWebView2(&session->webview);
                      RECT bounds;
                      GetClientRect(session->hwnd, &bounds);
                      controller->put_Bounds(bounds);

                      session->webview->add_NavigationStarting(
                          Callback<ICoreWebView2NavigationStartingEventHandler>(
                              [session](
                                  ICoreWebView2*,
                                  ICoreWebView2NavigationStartingEventArgs*
                                      args) -> HRESULT {
                                LPWSTR uri = nullptr;
                                args->get_Uri(&uri);
                                const std::string callback = WideToUtf8(uri);
                                CoTaskMemFree(uri);
                                if (CallbackMatchesRedirect(
                                        callback, session->redirect_url)) {
                                  args->put_Cancel(TRUE);
                                  InvokeCompletion(session, callback.c_str(),
                                                   nullptr, 0);
                                }
                                return S_OK;
                              })
                              .Get(),
                          &session->navigation_token);

                      session->webview->Navigate(
                          session->authorization_url.c_str());
                      return S_OK;
                    })
                    .Get());
          })
          .Get());
}

DWORD WINAPI AuthThreadProc(LPVOID param) {
  auto* session = static_cast<AuthSession*>(param);
  CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  RegisterWindowClass();

  const int window_width = session->width > 0 ? session->width : 640;
  const int window_height = session->height > 0 ? session->height : 600;
  HWND hwnd = CreateWindowExW(
      WS_EX_APPWINDOW, kWindowClass, L"Sign in",
      WS_OVERLAPPEDWINDOW | WS_VISIBLE, CW_USEDEFAULT, CW_USEDEFAULT,
      window_width, window_height, nullptr, nullptr, GetModuleHandle(nullptr),
      nullptr);
  if (hwnd == nullptr) {
    InvokeCompletion(session, nullptr,
                     "Failed to create the Windows authentication window.", 0);
    {
      std::lock_guard<std::mutex> lock(g_mutex);
      if (g_session == session) {
        g_session = nullptr;
      }
    }
    delete session;
    CoUninitialize();
    return 0;
  }

  session->hwnd = hwnd;
  SetWindowLongPtr(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(session));

  const HRESULT hr = AttachWebView(session);
  if (FAILED(hr)) {
    InvokeCompletion(session, nullptr,
                     "The WebView2 runtime is missing or failed to start.", 0);
  }

  MSG msg;
  while (GetMessage(&msg, nullptr, 0, 0) > 0) {
    TranslateMessage(&msg);
    DispatchMessage(&msg);
  }

  {
    std::lock_guard<std::mutex> lock(g_mutex);
    if (g_session == session) {
      g_session = nullptr;
    }
  }
  delete session;
  CoUninitialize();
  return 0;
}

}  // namespace

void oidc_windows_web_auth_start(const char* authorization_url,
                                 const char* redirect_url, int32_t width,
                                 int32_t height,
                                 OidcWebAuthCompletion completion) {
  if (completion == nullptr) {
    return;
  }

  AuthSession* session = nullptr;
  {
    std::lock_guard<std::mutex> lock(g_mutex);
    if (g_session != nullptr) {
      SendCompletion(
          completion, nullptr,
          "An interactive authentication session is already in progress.", 0);
      return;
    }
    if (authorization_url == nullptr || redirect_url == nullptr) {
      SendCompletion(completion, nullptr,
                     "authorizationUrl and redirectUrl are required.", 0);
      return;
    }

    session = new AuthSession();
    session->redirect_url = redirect_url;
    session->authorization_url = Utf8ToWide(authorization_url);
    session->completion = completion;
    session->width = width;
    session->height = height;
    g_session = session;
  }

  HANDLE thread = CreateThread(nullptr, 0, AuthThreadProc, session, 0, nullptr);
  if (thread == nullptr) {
    {
      std::lock_guard<std::mutex> lock(g_mutex);
      if (g_session == session) {
        g_session = nullptr;
      }
    }
    delete session;
    SendCompletion(completion, nullptr,
                   "Failed to start the Windows authentication thread.", 0);
    return;
  }
  CloseHandle(thread);
}

void oidc_windows_web_auth_cancel(void) {
  HWND hwnd = nullptr;
  {
    std::lock_guard<std::mutex> lock(g_mutex);
    if (g_session != nullptr) {
      hwnd = g_session->hwnd;
    }
  }
  if (hwnd != nullptr) {
    PostMessage(hwnd, WM_CLOSE, 0, 0);
  }
}

void oidc_windows_web_auth_string_free(char* value) { std::free(value); }
