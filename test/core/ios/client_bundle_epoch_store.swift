import Foundation

@main
private struct EpochStoreChecks {
  static func check(_ value: Bool) { precondition(value) }
  static func login(_ store: ClientBundleEpochStore, _ accountID: String) async throws
    -> ClientBundleRenewalState.Binding
  {
    let binding = try await store.reserveSession(accountID: accountID)
    try await store.activateReservedSession(binding)
    return binding
  }

  static func main() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      "zolnit-epoch-fixture-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let main = try ClientBundleEpochStore(directory: directory)
    let extensionOwner = try ClientBundleEpochStore(directory: directory)
    let first = try await login(main, "synthetic-account")
    check(first.session.rawValue == 1)
    let next = try await extensionOwner.claimOwner(sessionEpoch: first.session.rawValue)
    check(next.session == first.session && next.owner != first.owner)
    check(try await !main.isCurrent(first))
    check(try await extensionOwner.isCurrent(next))
    let restored = try await main.currentBinding()
    check(restored == next)
    try await main.invalidateSession(first.session.rawValue)
    check(try await !extensionOwner.isCurrent(next))
    try await main.acknowledgeRetirement(next)
    let newLogin = try await login(main, "synthetic-new-account")
    try await extensionOwner.publishBarrier(next, generation: 10, invalidatingSession: true)
    check(try await main.isCurrent(newLogin))
    let owners = try await withThrowingTaskGroup(of: UInt64.self) { group in
      for index in 0..<20 {
        let writer = index.isMultiple(of: 2) ? main : extensionOwner
        group.addTask { try await writer.claimOwner(sessionEpoch: newLogin.session.rawValue).owner.rawValue }
      }
      var values = Set<UInt64>()
      for try await value in group { values.insert(value) }
      return values
    }
    check(owners.count == 20)
    let bytes = try Data(contentsOf: directory.appendingPathComponent("control.json"))
    check(!String(decoding: bytes, as: UTF8.self).contains("Bearer"))
    try Data("{broken".utf8).write(to: directory.appendingPathComponent("control.json"))
    do {
      _ = try await main.reserveSession(accountID: "synthetic-account")
      preconditionFailure("corrupt authority must not reset its epoch")
    } catch ClientBundleEpochError.unavailable {}
    print("PASS durable epoch handoff, restore, stale logout, concurrent claims and corrupt-store fail-closed")
    print("Only a newly created fixture directory was used; no App Group or Keychain accessed")
  }
}
