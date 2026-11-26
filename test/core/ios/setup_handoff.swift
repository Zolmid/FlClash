import Foundation
import Shared

private actor Credentials: ClientBundleWritableCredentialStore {
  var values: [UInt64: ClientBundleAuthorization] = [:]
  var wrongBinding = false
  var locked = false
  func setLocked(_ value: Bool) { locked = value }
  func corruptBinding(_ value: Bool) { wrongBinding = value }
  func read(for binding: ClientBundleRenewalState.Binding) async throws -> ClientBundleAuthorization {
    guard !locked else { throw ClientBundleCredentialError.locked }
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

  static func equalRuntime(_ store: PacketTunnelSharedStateStore, _ expected: Data) async throws {
    let value = try await store.loadRuntimeSetupParams()
    let lhs = try JSONSerialization.jsonObject(with: value) as! [String: Any]
    let rhs = try JSONSerialization.jsonObject(with: expected) as! [String: Any]
    precondition(NSDictionary(dictionary: lhs) == NSDictionary(dictionary: rhs))
  }

  static func equalRuntime(_ store: PacketTunnelSharedStateStore, _ expected: [String: Any]) async throws {
    let data = try JSONSerialization.data(withJSONObject: expected)
    try await equalRuntime(store, data)
  }

  static func main() async throws {
    let store = SharedStateStore()
    func save(_ data: Data) { precondition(store.saveSharedState(data)) }
    let defaults = UserDefaults(suiteName: store.appGroupIdentifier)!
    defer { defaults.removePersistentDomain(forName: store.appGroupIdentifier) }
    let wire = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
    let payload = try JSONSerialization.jsonObject(with: wire) as! [String: Any]
    let expected = payload["setupParams"] as! [String: Any]
    let lease = expected["routing-lease"] as! [String: Any]
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("zn-handoff-authority-\(UUID())")
    defer { try? FileManager.default.removeItem(at: directory) }
    let authority = try ClientBundleEpochStore(directory: directory)
    let credentials = Credentials()
    let publisher = ClientBundleSessionPublisher(authority: authority, credentials: credentials, stopOwner: { _ in })
    let source = {
      try await PacketTunnelSharedStateStore.runtimeAuthorization(authority: authority, credentials: credentials)
    }
    let extensionStore = PacketTunnelSharedStateStore(defaults: defaults, authorization: source)
    precondition(store.saveSharedState(wire))
    let setup = try JSONSerialization.jsonObject(with: defaults.data(forKey: "setupParams")!) as! [String: Any]
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
    let pinned = extensionStore.loadStartSnapshot()!
    let beforeLock = defaults.data(forKey: "extensionStartSnapshot")!
    await credentials.setLocked(true)
    do {
      _ = try await extensionStore.loadRuntimeSetupParams(snapshot: pinned)
      fatalError("locked Keychain accepted widget start")
    } catch ClientBundleCredentialError.locked {}
    precondition(defaults.data(forKey: "extensionStartSnapshot") == beforeLock)
    await credentials.setLocked(false)
    try await equalRuntime(extensionStore, runtime)
    var next = expected
    next["test-url"] = "next-configuration"
    var nextLease = lease
    nextLease["configurationDigest"] = "next-digest"
    next["routing-lease"] = nextLease
    func shared(_ setup: [String: Any], _ options: Any) throws -> Data {
      try JSONSerialization.data(withJSONObject: ["setupParams": setup, "vpnOptions": options])
    }
    save(try shared(next, NSNull()))
    try await equalRuntime(extensionStore, runtime)
    var nextArguments = next
    nextArguments["owned-dns"] = ownedDNS
    store.saveOwnedDNSHandoff(try JSONSerialization.data(withJSONObject: ["arguments": nextArguments]))
    try await equalRuntime(extensionStore, runtime)
    save(try shared(next, payload["vpnOptions"]!))
    let nextRuntime = try await extensionStore.loadRuntimeSetupParams()
    let nextSetup = try JSONSerialization.jsonObject(with: nextRuntime) as! [String: Any]
    precondition(nextSetup["test-url"] as? String == "next-configuration")
    let pinnedRuntime = try await extensionStore.loadRuntimeSetupParams(snapshot: pinned)
    let pinnedObject = try JSONSerialization.jsonObject(with: pinnedRuntime) as! [String: Any]
    precondition(NSDictionary(dictionary: pinnedObject) == NSDictionary(dictionary: hydrated))
    var other = next
    var otherLease = nextLease
    otherLease["signedDeviceId"] = String(repeating: "e", count: 32)
    other["routing-lease"] = otherLease
    save(try shared(other, NSNull()))
    await reject { try await extensionStore.loadRuntimeSetupParams(snapshot: pinned) }
    precondition(store.saveSharedState(wire))
    store.saveOwnedDNSHandoff(try JSONSerialization.data(withJSONObject: ["arguments": arguments]))
    try await equalRuntime(extensionStore, runtime)
    save(try shared(["routing-lease": ["signedDeviceId": "unprepared"]], NSNull()))
    await reject { try await extensionStore.loadRuntimeSetupParams() }
    precondition(store.saveSharedState(wire))
    await reject { try await extensionStore.loadRuntimeSetupParams() }
    store.saveOwnedDNSHandoff(try JSONSerialization.data(withJSONObject: ["arguments": arguments]))
    store.saveOwnedDNSHandoff(try JSONSerialization.data(withJSONObject: ["arguments": nextArguments]))
    try await equalRuntime(extensionStore, runtime)
    save(try shared(next, payload["vpnOptions"]!))
    try await equalRuntime(extensionStore, nextRuntime)
    precondition(store.saveSharedState(wire))
    store.saveOwnedDNSHandoff(try JSONSerialization.data(withJSONObject: ["arguments": arguments]))
    let committed = defaults.data(forKey: "extensionStartSnapshot")!
    defaults.removeObject(forKey: "extensionStartSnapshot")
    defaults.set(try shared(other, payload["vpnOptions"]!), forKey: "sharedState")
    precondition(extensionStore.loadStartSnapshot() == nil)
    defaults.set(wire, forKey: "sharedState")
    try await equalRuntime(extensionStore, runtime)
    save(try shared(next, NSNull()))
    try await equalRuntime(extensionStore, runtime)
    defaults.set(committed, forKey: "extensionStartSnapshot")
    precondition(store.saveSharedState(wire))
    await credentials.corruptBinding(true)
    await reject { try await extensionStore.loadRuntimeSetupParams() }
    await credentials.corruptBinding(false)
    var staleProjection = expected
    var staleLease = lease
    staleLease["expiresAt"] = 1
    staleProjection["routing-lease"] = staleLease
    save(try shared(staleProjection, payload["vpnOptions"]!))
    var staleArguments = staleProjection
    staleArguments["owned-dns"] = ownedDNS
    store.saveOwnedDNSHandoff(try JSONSerialization.data(withJSONObject: ["arguments": staleArguments]))
    let expiredProjection = try await extensionStore.loadRuntimeSetupParams()
    let expiredObject = try JSONSerialization.jsonObject(with: expiredProjection) as! [String: Any]
    precondition((expiredObject["routing-lease"] as! [String: Any])["expiresAt"] as? Int == 1)
    precondition(store.saveSharedState(wire))
    store.saveOwnedDNSHandoff(try JSONSerialization.data(withJSONObject: ["arguments": arguments]))
    try await credentials.delete(for: binding)
    await reject { try await extensionStore.loadRuntimeSetupParams() }
    _ = try await publisher.configure(accountID: "wrong-account", authorization: "Bearer synthetic-other", device: device)
    await reject { try await extensionStore.loadRuntimeSetupParams() }
    _ = try await publisher.configure(accountID: lease["accountId"] as! String,
      authorization: "Bearer synthetic-fixture", device: ClientBundleSignedDevice(
        deviceID: String(repeating: "f", count: 32), installationID: String(repeating: "a", count: 43))!)
    await reject { try await extensionStore.loadRuntimeSetupParams() }
    store.saveOwnedDNSHandoff(Data("{}".utf8))
    await reject { try await extensionStore.loadRuntimeSetupParams() }
    _ = try await publisher.configure(accountID: lease["accountId"] as! String,
      authorization: "Bearer synthetic-fixture", device: device)
    store.saveOwnedDNSHandoff(try JSONSerialization.data(withJSONObject: ["arguments": expected]))
    let optional = try await extensionStore.loadRuntimeSetupParams()
    let optionalSetup = try JSONSerialization.jsonObject(with: optional) as! [String: Any]
    precondition(NSDictionary(dictionary: optionalSetup) == NSDictionary(dictionary: expected))
    var unsigned = expected
    var unsignedLease = lease
    unsignedLease.removeValue(forKey: "signedDeviceId")
    unsignedLease.removeValue(forKey: "signedSerial")
    unsignedLease.removeValue(forKey: "signedIntent")
    unsigned["routing-lease"] = unsignedLease
    let unsignedWire = try JSONSerialization.data(withJSONObject: ["setupParams": unsigned, "vpnOptions": payload["vpnOptions"]!])
    precondition(store.saveSharedState(unsignedWire))
    var unsignedArguments = unsigned
    unsignedArguments["owned-dns"] = ownedDNS
    store.saveOwnedDNSHandoff(try JSONSerialization.data(withJSONObject: ["arguments": unsignedArguments]))
    _ = try await publisher.configure(accountID: lease["accountId"] as! String,
      authorization: "Bearer synthetic-fixture", device: nil)
    let unsignedRuntime = try await extensionStore.loadRuntimeSetupParams()
    let unsignedSetup = try JSONSerialization.jsonObject(with: unsignedRuntime) as! [String: Any]
    precondition((unsignedSetup["owned-dns"] as! [String: Any])["strict"] as! Bool)
    save(try JSONSerialization.data(withJSONObject: [
      "setupParams": ["selected-map": [:], "test-url": ""], "vpnOptions": payload["vpnOptions"]!]))
    let legacy = try await extensionStore.loadRuntimeSetupParams()
    let legacySetup = try JSONSerialization.jsonObject(with: legacy) as! [String: Any]
    precondition(legacySetup["routing-lease"] == nil)
    let noKeychain = PacketTunnelSharedStateStore(defaults: defaults,
      authorization: { throw ClientBundleCredentialError.unavailable })
    func acceptOptional(_ setup: [String: Any]) throws {
      var arguments = setup
      arguments["owned-dns"] = NSNull()
      store.saveOwnedDNSHandoff(try JSONSerialization.data(withJSONObject: ["arguments": arguments]))
    }
    var nullSetup = expected
    nullSetup["base"] = NSNull()
    nullSetup["owned-dns"] = NSNull()
    nullSetup["routing-observation"] = NSNull()
    save(try shared(nullSetup, payload["vpnOptions"]!))
    try acceptOptional(nullSetup)
    try await equalRuntime(noKeychain, nullSetup)
    let optionalHeld = noKeychain.loadStartSnapshot()!
    save(try shared(["routing-lease": ["signedDeviceId": "unprepared"]], NSNull()))
    await reject { try await noKeychain.loadRuntimeSetupParams(snapshot: optionalHeld) }
    let currentBinding = try await authority.currentBinding()!
    try await publisher.logout(sessionEpoch: currentBinding.session.rawValue)
    _ = try await publisher.configure(accountID: lease["accountId"] as! String,
      authorization: "Bearer synthetic-fixture", device: device)
    var relogin = nullSetup
    var reloginLease = lease
    reloginLease["signedIntent"] = (lease["signedIntent"] as! NSNumber).intValue + 1
    relogin["routing-lease"] = reloginLease
    save(try shared(relogin, payload["vpnOptions"]!))
    await reject { try await noKeychain.loadRuntimeSetupParams() }
    try acceptOptional(relogin)
    await reject { try await noKeychain.loadRuntimeSetupParams(snapshot: optionalHeld) }
    try await equalRuntime(noKeychain, relogin)

    for key in ["accountId", "accountGeneration", "signedDeviceId", "signedIntent"] {
      for dnsFirst in [false, true] {
        save(try shared(nullSetup, payload["vpnOptions"]!))
        try acceptOptional(nullSetup)
        let held = noKeychain.loadStartSnapshot()!
        var changed = nullSetup
        var changedLease = lease
        if key == "accountId" { changedLease[key] = "other-account" }
        else if key == "signedDeviceId" { changedLease[key] = String(repeating: "e", count: 32) }
        else { changedLease[key] = (lease[key] as! NSNumber).intValue + 1 }
        changed["routing-lease"] = changedLease
        if dnsFirst { try acceptOptional(changed) }
        else { save(try shared(changed, payload["vpnOptions"]!)) }
        await reject { try await noKeychain.loadRuntimeSetupParams(snapshot: held) }
        await reject { try await noKeychain.loadRuntimeSetupParams() }
        if dnsFirst { save(try shared(changed, payload["vpnOptions"]!)) }
        else { try acceptOptional(changed) }
        await reject { try await noKeychain.loadRuntimeSetupParams(snapshot: held) }
        try await equalRuntime(noKeychain, changed)
      }
    }
    let publicSetup: [String: Any] = ["routing-lease": NSNull(), "base": NSNull(),
      "selected-map": [:], "test-url": "", "owned-dns": NSNull()]
    for legacyFirst in [false, true] {
      save(try shared(nullSetup, payload["vpnOptions"]!))
      try acceptOptional(nullSetup)
      if legacyFirst { save(try shared(publicSetup, payload["vpnOptions"]!)) }
      try acceptOptional(publicSetup)
      if !legacyFirst {
        await reject { try await noKeychain.loadRuntimeSetupParams() }
        save(try shared(publicSetup, payload["vpnOptions"]!))
      }
      try await equalRuntime(noKeychain, publicSetup)
      try acceptOptional(publicSetup)
      try await equalRuntime(noKeychain, publicSetup)
      save(try shared(publicSetup, NSNull()))
      try acceptOptional(publicSetup)
      try await equalRuntime(noKeychain, publicSetup)
    }
    save(try shared(["routing-lease": ["signedDeviceId": "unprepared"]], payload["vpnOptions"]!))
    try acceptOptional(publicSetup)
    await reject { try await noKeychain.loadRuntimeSetupParams() }
    var nullOptions = payload["vpnOptions"] as! [String: Any]
    for key in ["bypassDomain", "mtu", "excludeAPNs", "enforceRoutes"] { nullOptions[key] = NSNull() }
    save(try shared(publicSetup, nullOptions))
    try acceptOptional(publicSetup)
    let nullSnapshot = noKeychain.loadStartSnapshot()!
    precondition(nullSnapshot.options.mtu == 9000 && nullSnapshot.options.excludeAPNs)
    precondition(!nullSnapshot.options.enforceRoutes && nullSnapshot.options.bypassDomain.isEmpty)
    let rawOptions = try JSONSerialization.jsonObject(with: nullSnapshot.data) as! [String: Any]
    precondition(rawOptions["mtu"] is NSNull && rawOptions["excludeAPNs"] is NSNull)
    try await equalRuntime(noKeychain, publicSetup)
    print("PASS optional/no-Keychain, declared nulls/defaults, both write orders for account/device/generation/intent, held snapshots across relogin; legacy acceptance and managed pending; paired partial writes, expiry delegation, locked/unlock, migration")
  }
}
