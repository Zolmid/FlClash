import Foundation
import Shared

private actor Credentials: ClientBundleWritableCredentialStore {
  var values: [UInt64: ClientBundleAuthorization] = [:]
  var wrongBinding = false
  func corruptBinding(_ value: Bool) { wrongBinding = value }
  func read(for binding: ClientBundleRenewalState.Binding) async throws -> ClientBundleAuthorization {
    guard let value = values[binding.session.rawValue] else { throw ClientBundleCredentialError.unavailable }
    if wrongBinding {
      return .init(accountID: value.accountID,
        binding: .init(session: binding.session, owner: .init(binding.owner.rawValue + 1)),
        value: value.value, device: value.device)
    }
    return value
  }
  func publish(accountID: String, authorization: String, device: ClientBundleSignedDevice?,
    binding: ClientBundleRenewalState.Binding) async throws {
    values[binding.session.rawValue] = .init(accountID: accountID, binding: binding, value: authorization, device: device)
  }
  func delete(for binding: ClientBundleRenewalState.Binding) async throws {
    values.removeValue(forKey: binding.session.rawValue)
  }
}

@main struct SetupHandoffFixture {
  static func reject(_ operation: () async throws -> Data) async {
    do { _ = try await operation(); fatalError("invalid runtime handoff accepted") } catch {}
  }

  static func main() async throws {
    let store = SharedStateStore()
    let defaults = UserDefaults(suiteName: store.appGroupIdentifier)!
    defer { defaults.removePersistentDomain(forName: store.appGroupIdentifier) }
    let wire = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
    let payload = try JSONSerialization.jsonObject(with: wire) as! [String: Any]
    let expected = payload["setupParams"] as! [String: Any]
    let lease = expected["routing-lease"] as! [String: Any]
    let expires = (lease["expiresAt"] as! NSNumber).doubleValue
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("zn-handoff-authority-\(UUID())")
    defer { try? FileManager.default.removeItem(at: directory) }
    let authority = try ClientBundleEpochStore(directory: directory)
    let credentials = Credentials()
    let publisher = ClientBundleSessionPublisher(authority: authority, credentials: credentials, stopOwner: { _ in })
    let source = {
      try await PacketTunnelSharedStateStore.runtimeAuthorization(authority: authority, credentials: credentials)
    }
    let extensionStore = PacketTunnelSharedStateStore(defaults: defaults,
      now: { Date(timeIntervalSince1970: expires / 1000 - 1) }, authorization: source)
    precondition(store.saveSharedState(wire))
    let setup = try JSONSerialization.jsonObject(with: extensionStore.loadSetupParams()) as! [String: Any]
    precondition(NSDictionary(dictionary: setup) == NSDictionary(dictionary: expected))
    var arguments = expected
    let ownedDNS: [String: Any] = ["hosts": ["link.zolmid.com"],
      "relay": "https://link.zolmid.com/api/v1/zolnit/client/httpdns", "strict": true,
      "authorization": "Bearer synthetic-fixture"]
    arguments["owned-dns"] = ownedDNS
    store.saveOwnedDNSHandoff(try JSONSerialization.data(withJSONObject: ["arguments": arguments]))
    precondition(!String(decoding: defaults.data(forKey: "ownedDNSHandoff")!, as: UTF8.self).contains("synthetic-fixture"))
    let previous = try await authority.currentBinding()
    precondition(previous == nil)
    await reject { try await extensionStore.loadRuntimeSetupParams() }
    let device = ClientBundleSignedDevice(deviceID: lease["signedDeviceId"] as! String,
      installationID: String(repeating: "a", count: 43))!
    let binding = try await publisher.configure(accountID: lease["accountId"] as! String,
      authorization: "Bearer synthetic-fixture", device: device)
    let runtime = try await extensionStore.loadRuntimeSetupParams()
    let hydrated = try JSONSerialization.jsonObject(with: runtime) as! [String: Any]
    precondition(NSDictionary(dictionary: hydrated["routing-lease"] as! [String: Any]) == NSDictionary(dictionary: lease))
    precondition(NSDictionary(dictionary: hydrated["owned-dns"] as! [String: Any]) == NSDictionary(dictionary: ownedDNS))
    try runtime.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
    await credentials.corruptBinding(true)
    await reject { try await extensionStore.loadRuntimeSetupParams() }
    await credentials.corruptBinding(false)
    let expired = PacketTunnelSharedStateStore(defaults: defaults,
      now: { Date(timeIntervalSince1970: expires / 1000) }, authorization: source)
    await reject { try await expired.loadRuntimeSetupParams() }
    try await credentials.delete(for: binding)
    await reject { try await extensionStore.loadRuntimeSetupParams() }
    _ = try await publisher.configure(accountID: "wrong-account", authorization: "Bearer synthetic-other", device: device)
    await reject { try await extensionStore.loadRuntimeSetupParams() }
    _ = try await publisher.configure(accountID: lease["accountId"] as! String,
      authorization: "Bearer synthetic-fixture", device: ClientBundleSignedDevice(
        deviceID: String(repeating: "f", count: 32), installationID: String(repeating: "a", count: 43))!)
    await reject { try await extensionStore.loadRuntimeSetupParams() }
    defaults.removeObject(forKey: "ownedDNSHandoff")
    await reject { try await extensionStore.loadRuntimeSetupParams() }
    store.saveOwnedDNSHandoff(try JSONSerialization.data(withJSONObject: ["arguments": expected]))
    let optional = try await extensionStore.loadRuntimeSetupParams()
    precondition(optional == extensionStore.loadSetupParams())
    var unsigned = expected
    var unsignedLease = lease
    unsignedLease.removeValue(forKey: "signedDeviceId")
    unsignedLease.removeValue(forKey: "signedSerial")
    unsignedLease.removeValue(forKey: "signedIntent")
    unsigned["routing-lease"] = unsignedLease
    let unsignedWire = try JSONSerialization.data(withJSONObject: ["setupParams": unsigned])
    precondition(store.saveSharedState(unsignedWire))
    var unsignedArguments = unsigned
    unsignedArguments["owned-dns"] = ownedDNS
    store.saveOwnedDNSHandoff(try JSONSerialization.data(withJSONObject: ["arguments": unsignedArguments]))
    _ = try await publisher.configure(accountID: lease["accountId"] as! String,
      authorization: "Bearer synthetic-fixture", device: nil)
    let unsignedRuntime = try await extensionStore.loadRuntimeSetupParams()
    let unsignedSetup = try JSONSerialization.jsonObject(with: unsignedRuntime) as! [String: Any]
    precondition((unsignedSetup["owned-dns"] as! [String: Any])["strict"] as! Bool)
    precondition(store.saveSharedState(Data(#"{"setupParams":{"selected-map":{},"test-url":""}}"#.utf8)))
    let legacy = try await extensionStore.loadRuntimeSetupParams()
    precondition(legacy == extensionStore.loadSetupParams())
    print("PASS fresh protected publication → strict runtime; missing, expired, account/device/binding guards; optional DNS and legacy")
  }
}
