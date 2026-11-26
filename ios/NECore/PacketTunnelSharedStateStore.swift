import Foundation
import Shared

enum PacketTunnelEnvironment {
  static let extensionBundleIdentifier = Bundle.main.bundleIdentifier!
  static let baseBundleIdentifier = String(
    extensionBundleIdentifier.dropLast(".NECore".count)
  )
  static let appGroupIdentifier = "group.\(baseBundleIdentifier)"
  static let widgetIdentifier = "\(baseBundleIdentifier).Widget"
  static let eventNotificationName =
    "\(extensionBundleIdentifier).event"
}

final class PacketTunnelSharedStateStore {
  typealias AuthorizationSource = () async throws -> ClientBundleAuthorization
  private let injectedDefaults: UserDefaults?
  private let authorizationSource: AuthorizationSource

  init(defaults: UserDefaults? = nil,
    authorization: AuthorizationSource? = nil) {
    injectedDefaults = defaults
    authorizationSource = authorization ?? Self.loadAuthorization
  }

  private static func loadAuthorization() async throws -> ClientBundleAuthorization {
    guard let configuration = ClientBundleRenewalConfiguration.configured() else {
      throw ClientBundleCoreError.unavailable
    }
    return try await runtimeAuthorization(authority: configuration.makeAuthority(),
      credentials: configuration.makeCredentials())
  }

  static func runtimeAuthorization(authority: ClientBundleEpochStore,
    credentials: any ClientBundleCredentialStore) async throws -> ClientBundleAuthorization {
    guard let binding = try await authority.currentBinding() else {
      throw ClientBundleCoreError.unavailable
    }
    let value = try await credentials.read(for: binding)
    guard value.binding == binding, try await authority.isCurrent(binding) else {
      throw ClientBundleCoreError.staleOwner
    }
    return value
  }

  private let sharedStateKey = "sharedState"
  private let setupParamsKey = "setupParams"
  private let runTimeKey = "runTime"
  private let activeVpnOptionsKey = "activeVpnOptions"

  var isSafeMode: Bool {
    userDefaults?.bool(forKey: "safeMode") ?? false
  }

  struct StartSnapshot {
    let options: PacketTunnelVPNOptions
    let data: Data
    let setup: Data
    let handoff: [String: Any]
  }

  func loadStartSnapshot() -> StartSnapshot? {
    guard let defaults = userDefaults else { return nil }
    let object: [String: Any]?
    if let data = defaults.data(forKey: "extensionStartSnapshot") {
      object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    } else {
      // Only pre-snapshot installs may migrate; a tombstone never falls back.
      guard let sharedData = defaults.data(forKey: sharedStateKey),
        let shared = try? JSONSerialization.jsonObject(with: sharedData) as? [String: Any],
        let setup = defaults.data(forKey: setupParamsKey).flatMap({
          try? JSONSerialization.jsonObject(with: $0) as? [String: Any]
        }) ?? shared["setupParams"] as? [String: Any]
      else { return nil }
      if let embedded = shared["setupParams"] as? [String: Any],
        !NSDictionary(dictionary: embedded).isEqual(to: setup) { return nil }
      let handoff = defaults.data(forKey: "ownedDNSHandoff").flatMap {
        try? JSONSerialization.jsonObject(with: $0) as? [String: Any]
      } ?? [:]
      if setup["routing-lease"] != nil && !(setup["routing-lease"] is NSNull) {
        guard NSDictionary(dictionary: ["lease": setup["routing-lease"]!, "base": setup["base"] ?? NSNull()])
          == NSDictionary(dictionary: ["lease": handoff["routing-lease"] ?? NSNull(), "base": handoff["base"] ?? NSNull()])
        else { return nil }
      }
      object = ["vpnOptions": shared["vpnOptions"] ?? NSNull(), "setupParams": setup,
        "ownedDNSHandoff": handoff]
    }
    guard let object, let raw = object["vpnOptions"] as? [String: Any],
      let data = try? JSONSerialization.data(withJSONObject: raw),
      let options = try? JSONDecoder().decode(PacketTunnelVPNOptions.self, from: data),
      let setup = object["setupParams"] as? [String: Any],
      let setupData = try? JSONSerialization.data(withJSONObject: setup),
      let handoff = object["ownedDNSHandoff"] as? [String: Any]
    else { return nil }
    return StartSnapshot(options: options, data: data, setup: setupData, handoff: handoff)
  }

  func loadRuntimeSetupParams() async throws -> Data {
    guard let snapshot = loadStartSnapshot() else { throw ClientBundleCoreError.unavailable }
    return try await loadRuntimeSetupParams(snapshot: snapshot)
  }

  private func isCurrentOwner(of setup: [String: Any]) -> Bool {
    guard let current = loadStartSnapshot(),
      let currentSetup = try? JSONSerialization.jsonObject(with: current.setup) as? [String: Any]
    else { return false }
    let lease = setup["routing-lease"] as? [String: Any]
    let currentLease = currentSetup["routing-lease"] as? [String: Any]
    return ["accountId", "accountGeneration", "signedDeviceId", "signedIntent"].allSatisfy {
      NSDictionary(dictionary: ["value": lease?[$0] ?? NSNull()])
        == NSDictionary(dictionary: ["value": currentLease?[$0] ?? NSNull()])
    }
  }

  func loadRuntimeSetupParams(snapshot: StartSnapshot) async throws -> Data {
    let data = snapshot.setup
    guard var setup = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      isCurrentOwner(of: setup)
    else { throw ClientBundleCoreError.unavailable }
    guard let lease = setup["routing-lease"] as? [String: Any] else { return data }
    // Core reprojects the durable signed store; this lease expiry is only a past projection.
    guard NSDictionary(dictionary: ["lease": lease, "base": setup["base"] ?? NSNull()])
      == NSDictionary(dictionary: ["lease": snapshot.handoff["routing-lease"] ?? NSNull(),
        "base": snapshot.handoff["base"] ?? NSNull()])
    else { throw ClientBundleCoreError.unavailable }
    if snapshot.handoff["owned-dns"] is NSNull { return data }
    guard var ownedDNS = snapshot.handoff["owned-dns"] as? [String: Any],
      ownedDNS["strict"] as? Bool == true
    else { throw ClientBundleCoreError.unavailable }
    let credentials = try await authorizationSource()
    guard isCurrentOwner(of: setup) else { throw ClientBundleCoreError.staleOwner }
    guard lease["accountId"] as? String == credentials.accountID,
      (lease["signedDeviceId"] as? String).map({ $0 == credentials.device?.deviceID }) ?? true
    else { throw ClientBundleCoreError.staleOwner }
    guard credentials.value.hasPrefix("Bearer "), credentials.value.utf8.count > 7,
      credentials.value.utf8.count <= 16384,
      !credentials.value.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 })
    else { throw ClientBundleCoreError.staleOwner }
    ownedDNS["authorization"] = credentials.value
    setup["owned-dns"] = ownedDNS
    return try JSONSerialization.data(withJSONObject: setup)
  }

  func makeInitParams(setupParams: Data) -> String {
    let homeDirectory = appGroupDirectory()?.path ?? ""
    var params: [String: Any] = ["home-dir": homeDirectory, "version": 0]
    if let setup = try? JSONSerialization.jsonObject(with: setupParams) as? [String: Any],
      setup["routing-observation"] as? Bool == true
    {
      params["routing-observation"] = true
    }
    guard let encoded = try? JSONSerialization.data(withJSONObject: params),
      let value = String(data: encoded, encoding: .utf8)
    else { return "{}" }
    return value
  }

  func appGroupDirectory() -> URL? {
    FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier:
        PacketTunnelEnvironment.appGroupIdentifier
    )
  }

  func saveRunTime(vpnOptions: Data) {
    let milliseconds = Int(Date().timeIntervalSince1970 * 1000)
    userDefaults?.set(vpnOptions, forKey: activeVpnOptionsKey)
    userDefaults?.set(milliseconds, forKey: runTimeKey)
  }

  func clearRunTime() {
    userDefaults?.removeObject(forKey: runTimeKey)
    userDefaults?.removeObject(forKey: activeVpnOptionsKey)
  }

  private var userDefaults: UserDefaults? {
    injectedDefaults ?? UserDefaults(
      suiteName: PacketTunnelEnvironment.appGroupIdentifier
    )
  }
}

struct PacketTunnelVPNOptions: Decodable {
  let port: Int
  let ipv6: Bool
  let captureDns: Bool
  let systemProxy: Bool
  let bypassDomain: [String]
  let stack: String
  let mtu: Int
  let routeAddress: [String]
  let disableIcmpForwarding: Bool
  let endpointIndependentNat: Bool
  let congestionController: String
  let recvMsgX: Bool
  let sendMsgX: Bool
  let includeAllNetworks: Bool
  let excludeLocalNetworks: Bool
  let excludeAPNs: Bool
  let excludeCellularServices: Bool
  let enforceRoutes: Bool
  let excludeDeviceCommunication: Bool

  private enum CodingKeys: String, CodingKey {
    case port
    case ipv6
    case captureDns
    case dnsHijacking
    case systemProxy
    case bypassDomain
    case stack
    case mtu
    case routeAddress
    case disableIcmpForwarding
    case endpointIndependentNat
    case congestionController
    case recvMsgX
    case sendMsgX
    case includeAllNetworks
    case excludeLocalNetworks
    case excludeAPNs
    case excludeCellularServices
    case enforceRoutes
    case excludeDeviceCommunication
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    port = try container.decode(Int.self, forKey: .port)
    ipv6 = try container.decode(Bool.self, forKey: .ipv6)
    captureDns = try container.decodeIfPresent(Bool.self, forKey: .captureDns)
      ?? container.decode(Bool.self, forKey: .dnsHijacking)
    systemProxy = try container.decode(Bool.self, forKey: .systemProxy)
    bypassDomain = try container.decodeIfPresent(
      [String].self,
      forKey: .bypassDomain
    ) ?? []
    stack = try container.decode(String.self, forKey: .stack)
    let requestedMTU = try container.decodeIfPresent(Int.self, forKey: .mtu) ?? 0
    mtu = requestedMTU > 0 ? requestedMTU : 9000
    routeAddress = try container.decodeIfPresent(
      [String].self,
      forKey: .routeAddress
    ) ?? []
    disableIcmpForwarding = try container.decodeIfPresent(
      Bool.self,
      forKey: .disableIcmpForwarding
    ) ?? false
    endpointIndependentNat = try container.decodeIfPresent(
      Bool.self,
      forKey: .endpointIndependentNat
    ) ?? false
    congestionController = try container.decodeIfPresent(
      String.self,
      forKey: .congestionController
    ) ?? ""
    recvMsgX = try container.decodeIfPresent(Bool.self, forKey: .recvMsgX) ?? true
    sendMsgX = try container.decodeIfPresent(Bool.self, forKey: .sendMsgX) ?? false
    includeAllNetworks = try container.decodeIfPresent(
      Bool.self,
      forKey: .includeAllNetworks
    ) ?? false
    excludeLocalNetworks = try container.decodeIfPresent(
      Bool.self,
      forKey: .excludeLocalNetworks
    ) ?? true
    excludeAPNs = try container.decodeIfPresent(
      Bool.self,
      forKey: .excludeAPNs
    ) ?? true
    excludeCellularServices = try container.decodeIfPresent(
      Bool.self,
      forKey: .excludeCellularServices
    ) ?? true
    enforceRoutes = try container.decodeIfPresent(
      Bool.self,
      forKey: .enforceRoutes
    ) ?? false
    excludeDeviceCommunication = try container.decodeIfPresent(
      Bool.self,
      forKey: .excludeDeviceCommunication
    ) ?? true
  }
}
