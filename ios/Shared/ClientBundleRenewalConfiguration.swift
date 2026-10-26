import Foundation

public struct ClientBundleRenewalConfiguration: Sendable {
  public let accessGroup: String
  public let appGroup: String
  public let allowsLockedAccess: Bool
  public let distribution: String
  public let origin = URL(string: "https://link.zolmid.com")!

  public static func configured(in bundle: Bundle = .main) -> Self? {
    guard let identifier = bundle.bundleIdentifier,
      !identifier.hasSuffix(".Widget"), !identifier.hasSuffix(".LeaseObserver"),
      let group = bundle.object(forInfoDictionaryKey: "ZolNitRenewalKeychainAccessGroup") as? String,
      !group.isEmpty, !group.contains("$("), !group.contains("*"),
      let distribution = bundle.object(forInfoDictionaryKey: "ZolNitDistribution") as? String,
      ["direct", "apple-app-store"].contains(distribution)
    else { return nil }
    let base = identifier.hasSuffix(".NECore") ? String(identifier.dropLast(".NECore".count)) : identifier
    guard group.hasSuffix(".\(base).renewal") else { return nil }
    return .init(accessGroup: group, appGroup: "group.\(base)",
      allowsLockedAccess: bundle.object(forInfoDictionaryKey: "ZolNitRenewalWhileLocked") as? Bool == true,
      distribution: distribution)
  }

  public func makeAuthority() throws -> ClientBundleEpochStore {
    guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
    else { throw ClientBundleEpochError.unavailable }
    return try ClientBundleEpochStore(directory: container.appendingPathComponent("renewal", isDirectory: true),
      allowsLockedAccess: allowsLockedAccess)
  }

  public func makeCredentials() throws -> ClientBundleKeychainStore {
    try .init(accessGroup: accessGroup, accessibility: allowsLockedAccess
      ? .afterFirstUnlockThisDeviceOnly : .whenUnlockedThisDeviceOnly)
  }
}

public struct ClientBundleRenewalStatus: Codable, Sendable {
  public let supported: Bool
  public let sessionEpoch: UInt64?
  public let ownerId: UInt64?
  public let ownsRenewal: Bool
  public let ready: Bool
  public let state: String
  public let expiresAt: Int64?

  public init(
    supported: Bool, sessionEpoch: UInt64? = nil, ownerId: UInt64? = nil,
    ownsRenewal: Bool = false, ready: Bool = false, state: String, expiresAt: Int64? = nil
  ) {
    self.supported = supported
    self.sessionEpoch = sessionEpoch
    self.ownerId = ownerId
    self.ownsRenewal = ownsRenewal
    self.ready = ready
    self.state = state
    self.expiresAt = expiresAt
  }
}
