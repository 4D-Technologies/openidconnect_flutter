#if os(macOS)
import Cocoa
import FlutterMacOS
#else
import Flutter
#endif

import AuthenticationServices
import Foundation
import Security

public class OpenIdConnectDarwinPlugin: NSObject, FlutterPlugin, ASWebAuthenticationPresentationContextProviding {
  private static let storageChannelName = "plugins.concerti.io/openidconnect_secure_storage"
  private static let authChannelName = "plugins.concerti.io/openidconnect_darwin_auth"
  private let secureStorage = OpenIdConnectDarwinSecureStorage()
  private var activeAuthenticationSession: ASWebAuthenticationSession?
  private var pendingAuthenticationResult: FlutterResult?

  public static func register(with registrar: FlutterPluginRegistrar) {
    #if os(macOS)
    let storageChannel = FlutterMethodChannel(
      name: storageChannelName,
      binaryMessenger: registrar.messenger
    )
    let authChannel = FlutterMethodChannel(
      name: authChannelName,
      binaryMessenger: registrar.messenger
    )
    #else
    let storageChannel = FlutterMethodChannel(
      name: storageChannelName,
      binaryMessenger: registrar.messenger()
    )
    let authChannel = FlutterMethodChannel(
      name: authChannelName,
      binaryMessenger: registrar.messenger()
    )
    #endif

    let instance = OpenIdConnectDarwinPlugin()
    registrar.addMethodCallDelegate(instance, channel: storageChannel)
    registrar.addMethodCallDelegate(instance, channel: authChannel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    do {
      switch call.method {
      case "authorizeInteractive":
        let args = try Self.arguments(from: call.arguments)
        try authorizeInteractive(args: args, result: result)
      case "initialize":
        result(nil)
      case "write":
        let args = try Self.arguments(from: call.arguments)
        try secureStorage.write(key: try Self.requiredString("key", from: args), value: try Self.requiredString("value", from: args))
        result(nil)
      case "read":
        let args = try Self.arguments(from: call.arguments)
        result(try secureStorage.read(key: try Self.requiredString("key", from: args)))
      case "delete":
        let args = try Self.arguments(from: call.arguments)
        try secureStorage.delete(key: try Self.requiredString("key", from: args))
        result(nil)
      case "containsKey":
        let args = try Self.arguments(from: call.arguments)
        result(try secureStorage.containsKey(key: try Self.requiredString("key", from: args)))
      default:
        result(FlutterMethodNotImplemented)
      }
    } catch {
      result(FlutterError(
        code: "secure_storage_error",
        message: error.localizedDescription,
        details: nil
      ))
    }
  }

  private static func arguments(from raw: Any?) throws -> [String: Any] {
    guard let args = raw as? [String: Any] else {
      throw OpenIdConnectDarwinStorageError.invalidArguments("Arguments were missing or malformed.")
    }
    return args
  }

  private static func requiredString(_ key: String, from args: [String: Any]) throws -> String {
    guard let value = args[key] as? String else {
      throw OpenIdConnectDarwinStorageError.invalidArguments("Missing required argument: \(key)")
    }
    return value
  }

  private func authorizeInteractive(args: [String: Any], result: @escaping FlutterResult) throws {
    if pendingAuthenticationResult != nil {
      throw OpenIdConnectDarwinStorageError.invalidArguments("An interactive authentication session is already in progress.")
    }

    let authorizationUrlString = try Self.requiredString("authorizationUrl", from: args)
    let redirectUrlString = try Self.requiredString("redirectUrl", from: args)
    let preferEphemeralSession = (args["preferEphemeralSession"] as? Bool) ?? false

    guard let authorizationUrl = URL(string: authorizationUrlString) else {
      throw OpenIdConnectDarwinStorageError.invalidArguments("authorizationUrl was invalid.")
    }

    guard let redirectUrl = URL(string: redirectUrlString) else {
      throw OpenIdConnectDarwinStorageError.invalidArguments("redirectUrl was invalid.")
    }

    let session = try createAuthenticationSession(
      authorizationUrl: authorizationUrl,
      redirectUrl: redirectUrl,
      preferEphemeralSession: preferEphemeralSession,
      result: result
    )

    pendingAuthenticationResult = result
    activeAuthenticationSession = session

    if !session.start() {
      cleanupAuthenticationSession()
      throw OpenIdConnectDarwinStorageError.authenticationFailed("Failed to start ASWebAuthenticationSession.")
    }
  }

  private func createAuthenticationSession(
    authorizationUrl: URL,
    redirectUrl: URL,
    preferEphemeralSession: Bool,
    result: @escaping FlutterResult
  ) throws -> ASWebAuthenticationSession {
    let completionHandler: ASWebAuthenticationSession.CompletionHandler = { [weak self] callbackUrl, error in
      guard let self else { return }
      defer { self.cleanupAuthenticationSession() }

      if let sessionError = error as? ASWebAuthenticationSessionError, sessionError.code == .canceledLogin {
        result(FlutterError(code: "user_cancelled", message: "The user cancelled authentication.", details: nil))
        return
      }

      if let error {
        result(FlutterError(code: "authorize_interactive_error", message: error.localizedDescription, details: nil))
        return
      }

      guard let callbackUrl else {
        result(FlutterError(code: "authorize_interactive_error", message: "Authentication completed without a callback URL.", details: nil))
        return
      }

      result(callbackUrl.absoluteString)
    }

    let session: ASWebAuthenticationSession
    let path = redirectUrl.path.isEmpty ? "/*" : redirectUrl.path

    switch redirectUrl.scheme?.lowercased() {
    case "http":
      throw OpenIdConnectDarwinStorageError.invalidArguments("HTTP localhost redirects are handled by the macOS loopback flow and should not be routed through the native Apple session bridge.")
    case "https":
      guard let host = redirectUrl.host, !host.isEmpty else {
        throw OpenIdConnectDarwinStorageError.invalidArguments("HTTPS redirect URLs must include a host.")
      }

      if #available(iOS 17.4, macOS 14.4, *) {
        session = ASWebAuthenticationSession(
          url: authorizationUrl,
          callback: .https(host: host, path: path),
          completionHandler: completionHandler
        )
      } else {
        throw OpenIdConnectDarwinStorageError.authenticationFailed("HTTPS redirect callbacks require iOS 17.4+ or macOS 14.4+.")
      }
    case let scheme? where !scheme.isEmpty:
      if #available(iOS 17.4, macOS 14.4, *) {
        session = ASWebAuthenticationSession(
          url: authorizationUrl,
          callback: .customScheme(scheme),
          completionHandler: completionHandler
        )
      } else {
        session = ASWebAuthenticationSession(
          url: authorizationUrl,
          callbackURLScheme: scheme,
          completionHandler: completionHandler
        )
      }
    default:
      throw OpenIdConnectDarwinStorageError.invalidArguments("Redirect URLs must include a URI scheme.")
    }

    session.prefersEphemeralWebBrowserSession = preferEphemeralSession
    session.presentationContextProvider = self
    return session
  }

  private func cleanupAuthenticationSession() {
    activeAuthenticationSession = nil
    pendingAuthenticationResult = nil
  }

  public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
    #if os(macOS)
    return NSApp.keyWindow ?? NSApp.windows.first ?? ASPresentationAnchor()
    #else
    let connectedScenes = UIApplication.shared.connectedScenes
    for scene in connectedScenes {
      guard let windowScene = scene as? UIWindowScene else { continue }
      if let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) {
        return keyWindow
      }
      if let firstWindow = windowScene.windows.first {
        return firstWindow
      }
    }
    return ASPresentationAnchor()
    #endif
  }
}

private final class OpenIdConnectDarwinSecureStorage {
  private static let service = "io.concerti.openidconnect"

  func write(key: String, value: String) throws {
    var query = baseQuery(for: key)
    query[kSecValueData as String] = Data(value.utf8)

    let status = SecItemAdd(query as CFDictionary, nil)
    if status == errSecDuplicateItem {
      let updateStatus = SecItemUpdate(
        baseQuery(for: key) as CFDictionary,
        [kSecValueData as String: Data(value.utf8)] as CFDictionary
      )
      guard updateStatus == errSecSuccess else {
        throw OpenIdConnectDarwinStorageError.osStatus(
          updateStatus,
          operation: "update keychain item"
        )
      }
      return
    }

    guard status == errSecSuccess else {
      throw OpenIdConnectDarwinStorageError.osStatus(status, operation: "create keychain item")
    }
  }

  func read(key: String) throws -> String? {
    var query = baseQuery(for: key)
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    query[kSecReturnData as String] = true

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    if status == errSecItemNotFound {
      return nil
    }

    guard status == errSecSuccess else {
      throw OpenIdConnectDarwinStorageError.osStatus(status, operation: "read keychain item")
    }

    guard let data = item as? Data else {
      throw OpenIdConnectDarwinStorageError.invalidData
    }

    return String(data: data, encoding: .utf8)
  }

  func delete(key: String) throws {
    let status = SecItemDelete(baseQuery(for: key) as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw OpenIdConnectDarwinStorageError.osStatus(status, operation: "delete keychain item")
    }
  }

  func containsKey(key: String) throws -> Bool {
    var query = baseQuery(for: key)
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    query[kSecReturnData as String] = false

    let status = SecItemCopyMatching(query as CFDictionary, nil)
    switch status {
    case errSecSuccess:
      return true
    case errSecItemNotFound:
      return false
    default:
      throw OpenIdConnectDarwinStorageError.osStatus(status, operation: "check keychain item")
    }
  }

  private func baseQuery(for key: String) -> [String: Any] {
    var query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: Self.service,
      kSecAttrAccount as String: key,
      kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
    ]

    #if os(macOS)
    if #available(macOS 10.15, *) {
      query[kSecUseDataProtectionKeychain as String] = true
    }
    #endif

    return query
  }
}

private enum OpenIdConnectDarwinStorageError: LocalizedError {
  case invalidArguments(String)
  case invalidData
  case authenticationFailed(String)
  case osStatus(OSStatus, operation: String)

  var errorDescription: String? {
    switch self {
    case let .invalidArguments(message):
      return message
    case .invalidData:
      return "The stored keychain value was invalid."
    case let .authenticationFailed(message):
      return message
    case let .osStatus(status, operation):
      let message = SecCopyErrorMessageString(status, nil) as String? ?? "Unknown security error"
      return "Unable to \(operation): \(status) (\(message))"
    }
  }
}
