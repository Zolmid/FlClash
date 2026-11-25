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
  private static let emptySetupParams = Data("{}".utf8)

  typealias AuthorizationSource = () async throws -> ClientBundleAuthorization
  private let injectedDefaults: UserDefaults?
  private let authorizationSource: AuthorizationSource
  private let now: () -> Date

  init(defaults: UserDefaults? = nil, now: @escaping () -> Date = Date.init,
    authorization: AuthorizationSource? = nil) {
    injectedDefaults = defaults
    self.now = now
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

  func loadVPNOptionsSnapshot() -> (options: PacketTunnelVPNOptions, data: Data)? {
    guard let sharedData = userDefaults?.data(forKey: sharedStateKey),
      let shared = try? JSONSerialization.jsonObject(with: sharedData) as? [String: Any],
      let rawOptions = shared["vpnOptions"] as? [String: Any],
      let data = try? JSONSerialization.data(withJSONObject: rawOptions),
      let options = try? JSONDecoder().decode(PacketTunnelVPNOptions.self, from: data)
    else {
      return nil
    }
    return (options, data)
  }

  func loadSetupParams() -> Data {
    guard let userDefaults else {
      return Self.emptySetupParams
    }
    if let data = userDefaults.data(forKey: setupParamsKey) {
      return data
    }
    guard let sharedStateData = userDefaults.data(forKey: sharedStateKey),
      let json = try? JSONSerialization.jsonObject(with: sharedStateData)
        as? [String: Any],
      let setupParams = json[setupParamsKey],
      !(setupParams is NSNull),
      JSONSerialization.isValidJSONObject(setupParams),
      let data = try? JSONSerialization.data(withJSONObject: setupParams)
    else {
      return Self.emptySetupParams
    }
    userDefaults.set(data, forKey: setupParamsKey)
    return data
  }

  func loadRuntimeSetupParams() async throws -> Data {
    let data = loadSetupParams()
    guard var setup = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      throw ClientBundleCoreError.unavailable
    }
    guard let lease = setup["routing-lease"] as? [String: Any] else { return data }
    if lease["signedDeviceId"] != nil {
      guard let expires = lease["expiresAt"] as? NSNumber,
        expires.doubleValue > now().timeIntervalSince1970 * 1000 else {
        throw ClientBundleCoreError.unavailable
      }
    }
    guard let snapshotData = userDefaults?.data(forKey: "ownedDNSHandoff"),
      let snapshot = try JSONSerialization.jsonObject(with: snapshotData) as? [String: Any],
      NSDictionary(dictionary: ["lease": setup["routing-lease"] ?? NSNull(), "base": setup["base"] ?? NSNull()])
        == NSDictionary(dictionary: ["lease": snapshot["routing-lease"] ?? NSNull(), "base": snapshot["base"] ?? NSNull()])
    else { throw ClientBundleCoreError.unavailable }
    if snapshot["owned-dns"] is NSNull { return data }
    guard var ownedDNS = snapshot["owned-dns"] as? [String: Any],
      ownedDNS["strict"] as? Bool == true
    else { throw ClientBundleCoreError.unavailable }
    let credentials = try await authorizationSource()
    guard lease["accountId"] as? String == credentials.accountID,
      (lease["signedDeviceId"] as? String).map({ $0 == credentials.device?.deviceID }) ?? true,
      credentials.value.hasPrefix("Bearer "), credentials.value.utf8.count > 7,
      credentials.value.utf8.count <= 16384,
      !credentials.value.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 })
    else { throw ClientBundleCoreError.staleOwner }
    ownedDNS["authorization"] = credentials.value
    setup["owned-dns"] = ownedDNS
    return try JSONSerialization.data(withJSONObject: setup)
  }

  func makeInitParams() -> String {
    let homeDirectory = appGroupDirectory()?.path ?? ""
    var params: [String: Any] = ["home-dir": homeDirectory, "version": 0]
    if let setup = try? JSONSerialization.jsonObject(with: loadSetupParams()) as? [String: Any],
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
