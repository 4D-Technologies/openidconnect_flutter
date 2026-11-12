#ifndef OPENIDCONNECT_WINDOWS_WEB_AUTH_H_
#define OPENIDCONNECT_WINDOWS_WEB_AUTH_H_

#include <stdint.h>

#if defined(__cplusplus)
extern "C" {
#endif

#if defined(_WIN32)
#define OIDC_EXPORT __declspec(dllexport)
#else
#define OIDC_EXPORT
#endif

typedef void (*OidcWebAuthCompletion)(const char* callback_url, const char* error,
                                      int32_t cancelled);

OIDC_EXPORT void oidc_windows_web_auth_start(const char* authorization_url,
                                             const char* redirect_url,
                                             int32_t width, int32_t height,
                                             OidcWebAuthCompletion completion);

OIDC_EXPORT void oidc_windows_web_auth_cancel(void);

/// Frees a string returned through [OidcWebAuthCompletion].
OIDC_EXPORT void oidc_windows_web_auth_string_free(char* value);

#if defined(__cplusplus)
}
#endif

#endif  // OPENIDCONNECT_WINDOWS_WEB_AUTH_H_
