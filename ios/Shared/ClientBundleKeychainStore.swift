import Foundation
import Security
import LocalAuthentication

public actor ClientBundleKeychainStore: ClientBundleWritableCredentialStore {
  public enum Accessibility: Sendable {
    case whenUnlockedThisDeviceOnly, afterFirstUnlockThisDeviceOnly
  }

  private struct Record: Codable {
    let sessionEpoch: UInt64
    let accountID: String
    let authorization: String
  }

  private let group: String
  private let accessibility: Accessibility
  private let service = "com.zolmid.zolnit.renewal.authorization.v1"

  public init(accessGroup: String, accessibility: Accessibility) throws {
    guard !accessGroup.isEmpty, !accessGroup.contains("*"),
      !accessGroup.unicodeScalars.contains(where: { $0.value < 33 || $0.value == 127 })
    else { throw ClientBundleCredentialError.unavailable }
    self.group = accessGroup
    self.accessibility = accessibility
  }

  public func read(for binding: ClientBundleRenewalState.Binding) async throws -> ClientBundleAuthorization {
    var query = query(binding.session.rawValue)
    query[kSecReturnData] = true
    query[kSecMatchLimit] = kSecMatchLimitOne
    let authentication = LAContext()
    authentication.interactionNotAllowed = true
    query[kSecUseAuthenticationContext] = authentication
    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecInteractionNotAllowed { throw ClientBundleCredentialError.locked }
    guard status == errSecSuccess, let data = result as? Data, data.count <= 32 * 1024,
      let record = try? JSONDecoder().decode(Record.self, from: data),
      record.sessionEpoch == binding.session.rawValue, !record.accountID.isEmpty,
      Self.validAuthorization(record.authorization)
    else { throw ClientBundleCredentialError.unavailable }
    return .init(accountID: record.accountID, binding: binding, value: record.authorization)
  }

  public func publish(
    accountID: String, authorization: String, binding: ClientBundleRenewalState.Binding
  ) async throws {
    guard !accountID.isEmpty, accountID.utf8.count <= 256,
      Self.validAuthorization(authorization)
    else { throw ClientBundleCredentialError.bindingMismatch }
    let record = Record(sessionEpoch: binding.session.rawValue,
      accountID: accountID, authorization: authorization)
    let data = try JSONEncoder().encode(record)
    var attributes: [CFString: Any] = [
      kSecValueData: data,
      kSecAttrAccessible: accessibility == .whenUnlockedThisDeviceOnly
        ? kSecAttrAccessibleWhenUnlockedThisDeviceOnly : kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
    ]
    let query = query(binding.session.rawValue)
    var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
    if status == errSecItemNotFound {
      attributes.merge(query) { current, _ in current }
      status = SecItemAdd(attributes as CFDictionary, nil)
    }
    if status == errSecInteractionNotAllowed { throw ClientBundleCredentialError.locked }
    guard status == errSecSuccess else { throw ClientBundleCredentialError.unavailable }
    let verified = try await read(for: binding)
    guard verified.accountID == accountID, verified.value == authorization else {
      throw ClientBundleCredentialError.bindingMismatch
    }
  }

  public func delete(for binding: ClientBundleRenewalState.Binding) async throws {
    let status = SecItemDelete(query(binding.session.rawValue) as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw ClientBundleCredentialError.unavailable
    }
  }

  private func query(_ epoch: UInt64) -> [CFString: Any] {
    [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: service,
      kSecAttrAccount: "session-\(epoch)",
      kSecAttrAccessGroup: group,
      kSecAttrSynchronizable: false,
    ]
  }

  private static func validAuthorization(_ value: String) -> Bool {
    value.hasPrefix("Bearer ") && value.utf8.count > 7 && value.utf8.count <= 16 * 1024 &&
      !value.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 })
  }
}
