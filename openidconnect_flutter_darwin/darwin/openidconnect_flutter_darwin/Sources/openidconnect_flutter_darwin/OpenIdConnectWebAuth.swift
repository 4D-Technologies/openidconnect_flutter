import AuthenticationServices
import Darwin
import Foundation

#if os(macOS)
import AppKit
#else
import UIKit
#endif

typealias OidcWebAuthCompletion = @convention(c) (
  UnsafePointer<CChar>?,
  UnsafePointer<CChar>?,
  Int32
) -> Void

private final class OpenIdConnectWebAuthController: NSObject,
  ASWebAuthenticationPresentationContextProviding
{
  func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
    #if os(macOS)
    return NSApp.keyWindow ?? NSApp.windows.first ?? NSWindow()
    #else
    for scene in UIApplication.shared.connectedScenes {
      guard let windowScene = scene as? UIWindowScene else {
        continue
      }
      if let keyWindow = windowScene.windows.first(where: \.isKeyWindow) {
        return keyWindow
      }
      if let firstWindow = windowScene.windows.first {
        return firstWindow
      }
    }
    return UIWindow()
    #endif
  }
}

private var activeSession: ASWebAuthenticationSession?
private var activeController: OpenIdConnectWebAuthController?
private var activeCompletion: OidcWebAuthCompletion?

private func copyCString(_ value: String?) -> UnsafeMutablePointer<CChar>? {
  guard let value else {
    return nil
  }
  return strdup(value)
}

private func send(
  _ completion: OidcWebAuthCompletion?,
  callback: String?,
  error: String?,
  cancelled: Int32
) {
  completion?(copyCString(callback), copyCString(error), cancelled)
}

private func finish(callback: String?, error: String?, cancelled: Int32) {
  let completion = activeCompletion
  activeSession = nil
  activeController = nil
  activeCompletion = nil
  send(completion, callback: callback, error: error, cancelled: cancelled)
}

private func supportsHttpsCallback() -> Bool {
  if #available(iOS 17.4, macOS 14.4, *) {
    return true
  }
  return false
}

@_cdecl("oidc_web_auth_start")
func oidcWebAuthStart(
  authorizationUrl: UnsafePointer<CChar>?,
  redirectUrl: UnsafePointer<CChar>?,
  preferEphemeral: Int32,
  completion: OidcWebAuthCompletion?
) {
  guard let completion else {
    return
  }

  DispatchQueue.main.async {
    if activeSession != nil || activeCompletion != nil {
      send(
        completion,
        callback: nil,
        error: "An interactive authentication session is already in progress.",
        cancelled: 0
      )
      return
    }

    let authorization = authorizationUrl.map(String.init(cString:))
    let redirect = redirectUrl.map(String.init(cString:))
    guard let authorization, !authorization.isEmpty,
          let authorizationURL = URL(string: authorization)
    else {
      send(completion, callback: nil, error: "authorizationUrl was invalid.", cancelled: 0)
      return
    }
    guard let redirect, !redirect.isEmpty,
          let redirectURL = URL(string: redirect),
          let scheme = redirectURL.scheme, !scheme.isEmpty
    else {
      send(
        completion,
        callback: nil,
        error: "Redirect URLs must include a URI scheme.",
        cancelled: 0
      )
      return
    }

    if scheme.lowercased() == "http" {
      send(
        completion,
        callback: nil,
        error:
          "HTTP localhost redirects are handled by the macOS loopback flow and should not be routed through ASWebAuthenticationSession.",
        cancelled: 0
      )
      return
    }

    activeCompletion = completion
    activeController = OpenIdConnectWebAuthController()

    let handler: ASWebAuthenticationSession.CompletionHandler = { callbackURL, error in
      if let error {
        let nsError = error as NSError
        if nsError.domain == ASWebAuthenticationSessionErrorDomain,
           nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue
        {
          finish(callback: nil, error: nil, cancelled: 1)
          return
        }
        finish(callback: nil, error: error.localizedDescription, cancelled: 0)
        return
      }
      guard let callback = callbackURL?.absoluteString, !callback.isEmpty else {
        finish(
          callback: nil,
          error: "Authentication completed without a callback URL.",
          cancelled: 0
        )
        return
      }
      finish(callback: callback, error: nil, cancelled: 0)
    }

    let path = redirectURL.path.isEmpty ? "/*" : redirectURL.path
    var session: ASWebAuthenticationSession?

    if scheme.lowercased() == "https" {
      guard let host = redirectURL.host, !host.isEmpty else {
        finish(callback: nil, error: "HTTPS redirect URLs must include a host.", cancelled: 0)
        return
      }
      guard supportsHttpsCallback() else {
        finish(
          callback: nil,
          error: "HTTPS redirect callbacks require iOS 17.4+ or macOS 14.4+.",
          cancelled: 0
        )
        return
      }
      if #available(iOS 17.4, macOS 14.4, *) {
        session = ASWebAuthenticationSession(
          url: authorizationURL,
          callback: .https(host: host, path: path),
          completionHandler: handler
        )
      }
    } else if supportsHttpsCallback() {
      if #available(iOS 17.4, macOS 14.4, *) {
        session = ASWebAuthenticationSession(
          url: authorizationURL,
          callback: .customScheme(scheme),
          completionHandler: handler
        )
      }
    } else {
      session = ASWebAuthenticationSession(
        url: authorizationURL,
        callbackURLScheme: scheme,
        completionHandler: handler
      )
    }

    guard let session else {
      finish(callback: nil, error: "Failed to create ASWebAuthenticationSession.", cancelled: 0)
      return
    }

    session.prefersEphemeralWebBrowserSession = preferEphemeral != 0
    session.presentationContextProvider = activeController
    activeSession = session

    if !session.start() {
      finish(callback: nil, error: "Failed to start ASWebAuthenticationSession.", cancelled: 0)
    }
  }
}

@_cdecl("oidc_web_auth_cancel")
func oidcWebAuthCancel() {
  DispatchQueue.main.async {
    activeSession?.cancel()
  }
}

@_cdecl("oidc_web_auth_string_free")
func oidcWebAuthStringFree(_ value: UnsafeMutablePointer<CChar>?) {
  free(value)
}
