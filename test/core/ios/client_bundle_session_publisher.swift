import Foundation

private typealias Binding = ClientBundleRenewalState.Binding
private func check(_ value: Bool, file: StaticString = #file, line: UInt = #line) {
  precondition(value, file: file, line: line)
}

private actor CredentialFixture: ClientBundleWritableCredentialStore {
  let authority: ClientBundleEpochStore
  var records: [UInt64: (String, String)] = [:]
  var events: [String] = []
  var failStop = false
  var failPublish = false
  init(_ authority: ClientBundleEpochStore) { self.authority = authority }

  func failures(stop: Bool = false, publish: Bool = false) {
    failStop = stop; failPublish = publish
  }
  func snapshot() -> [String] { events }
  func contains(_ epoch: UInt64) -> Bool { records[epoch] != nil }
  func read(for binding: Binding) async throws -> ClientBundleAuthorization {
    guard let value = records[binding.session.rawValue] else { throw ClientBundleCredentialError.unavailable }
    return .init(accountID: value.0, binding: binding, value: value.1)
  }
  func publish(accountID: String, authorization: String, binding: Binding) async throws {
    check(try await !authority.isCurrent(binding))
    events.append("staged")
    if failPublish { throw ClientBundleCredentialError.unavailable }
    records[binding.session.rawValue] = (accountID, authorization)
  }
  func delete(for binding: Binding) async throws {
    events.append("delete-\(binding.session.rawValue)")
    records.removeValue(forKey: binding.session.rawValue)
  }
  func stop(_ binding: Binding) async throws {
    check(try await authority.currentBinding() == nil)
    check(try await authority.retiringBinding() == binding)
    events.append("fence-\(binding.session.rawValue)")
    if failStop { throw ClientBundleCoreError.unavailable }
  }
}

@main
private struct PublisherChecks {
  static func main() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      "zolnit-session-publisher-fixture-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let authority = try ClientBundleEpochStore(directory: directory)
    let credentials = CredentialFixture(authority)
    let publisher = ClientBundleSessionPublisher(authority: authority, credentials: credentials,
      stopOwner: { try await credentials.stop($0) })
    let first = try await publisher.configure(accountID: "fixture-A", authorization: "Bearer SYNTHETIC_A")
    let extensionOwner = try await authority.claimOwner(sessionEpoch: first.session.rawValue)
    let restored = try await publisher.configure(accountID: "fixture-A", authorization: "Bearer SYNTHETIC_A")
    check(restored == extensionOwner)
    check(await credentials.snapshot() == ["staged"])
    await credentials.failures(stop: true)
    do {
      try await publisher.logout(sessionEpoch: first.session.rawValue)
      preconditionFailure("unacknowledged native fence must fail")
    } catch ClientBundleCoreError.unavailable {}
    check(try await authority.currentBinding() == nil)
    check(try await authority.retiringBinding() == extensionOwner)
    check(await credentials.contains(first.session.rawValue))
    let restartedAuthority = try ClientBundleEpochStore(directory: directory)
    let restarted = ClientBundleSessionPublisher(authority: restartedAuthority, credentials: credentials,
      stopOwner: { try await credentials.stop($0) })
    await credentials.failures()
    try await restarted.logout(sessionEpoch: first.session.rawValue)
    check(try await authority.retiringBinding() == nil)
    check(await !credentials.contains(first.session.rawValue))
    let second = try await restarted.configure(accountID: "fixture-B", authorization: "Bearer SYNTHETIC_B")
    try await publisher.logout(sessionEpoch: first.session.rawValue)
    check(try await authority.isCurrent(second))
    check(await credentials.contains(second.session.rawValue))
    try await restarted.logout(sessionEpoch: second.session.rawValue)
    await credentials.failures(publish: true)
    do {
      _ = try await restarted.configure(accountID: "fixture-C", authorization: "Bearer SYNTHETIC_C")
      preconditionFailure("failed credential publication must not activate a session")
    } catch ClientBundleCredentialError.unavailable {}
    check(try await authority.currentBinding() == nil)
    let pending = try await authority.pendingBinding()
    check(pending != nil)
    await credentials.failures()
    let recovered = try await restarted.configure(accountID: "fixture-C", authorization: "Bearer SYNTHETIC_C")
    check(recovered.session.rawValue > pending!.session.rawValue)
    let record = try String(contentsOf: directory.appendingPathComponent("control.json"), encoding: .utf8)
    check(!record.contains("Bearer") && !record.contains("SYNTHETIC"))
    print("PASS staged publication, restore, durable failed-logout retry, stale epoch isolation and publication recovery")
    print("Only synthetic credentials and a new fixture directory; no Keychain, App Group or network access")
  }
}
