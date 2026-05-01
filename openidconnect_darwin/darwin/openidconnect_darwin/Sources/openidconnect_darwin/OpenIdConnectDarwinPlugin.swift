#if os(macOS)
import Cocoa
import FlutterMacOS
#else
import Flutter
#endif

import Foundation
import Security

public class OpenIdConnectDarwinPlugin: NSObject, FlutterPlugin {
  private static let channelName = "plugins.concerti.io/openidconnect_secure_storage"
  private let secureStorage = OpenIdConnectDarwinSecureStorage()

  public static func register(with registrar: FlutterPluginRegistrar) {
    #if os(macOS)
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger
    )
    #else
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )
    #endif

    let instance = OpenIdConnectDarwinPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    do {
      switch call.method {
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
  case osStatus(OSStatus, operation: String)

  var errorDescription: String? {
    switch self {
    case let .invalidArguments(message):
      return message
    case .invalidData:
      return "The stored keychain value was invalid."
    case let .osStatus(status, operation):
      let message = SecCopyErrorMessageString(status, nil) as String? ?? "Unknown security error"
      return "Unable to \(operation): \(status) (\(message))"
    }
  }
}
