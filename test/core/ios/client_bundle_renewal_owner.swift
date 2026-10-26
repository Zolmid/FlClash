import Foundation

private func check(_ condition: Bool, file: StaticString = #file, line: UInt = #line) {
  precondition(condition, file: file, line: line)
}

private typealias State = ClientBundleRenewalState
private let first = State.Binding(session: .init(10), owner: .init(20))

private actor Harness: ClientBundleCredentialStore, ClientBundleRenewalTransport,
  ClientBundleRenewalControl, ClientBundleRenewalCore
{
  var events: [String] = []
  var current = true
  var barrierFails = false
  var installationBlocked = false
  var fenced = false
  var response = ClientBundleHTTPResponse(status: 200, body: Data(
    #"{"data":{"schema_version":1,"account_id":"fixture-account","issued_at":1000,"expires_at":1300}}"#.utf8))
  var installContinuation: CheckedContinuation<Void, Never>?

  func configure(blocked: Bool = false, barrierFails: Bool = false, status: Int = 200, body: String? = nil) {
    installationBlocked = blocked
    self.barrierFails = barrierFails
    response = .init(status: status, body: body.map { Data($0.utf8) } ?? response.body)
  }
  func replaceOwner() { current = false }
  func allowBarrier() { barrierFails = false }
  func snapshot() -> [String] { events }
  func releaseInstall() { installContinuation?.resume(); installContinuation = nil }
  func read(for binding: State.Binding) async throws -> ClientBundleAuthorization {
    events.append("read")
    return .init(accountID: "fixture-account", binding: binding, value: "Bearer SYNTHETIC_ONLY")
  }
  func delete(for binding: State.Binding) async throws { events.append("delete-\(binding.session.rawValue)") }
  func fetch(authorization: ClientBundleAuthorization) async throws -> ClientBundleHTTPResponse {
    check(authorization.value == "Bearer SYNTHETIC_ONLY")
    events.append("request")
    return response
  }
  func isCurrent(_ binding: State.Binding) async throws -> Bool { current }
  func start(_ binding: State.Binding, generation: UInt64) async throws {}
  func publishBarrier(_ binding: State.Binding, generation: UInt64, invalidatingSession: Bool) async throws {
    events.append(invalidatingSession ? "session-barrier" : "owner-barrier")
    if barrierFails { throw ClientBundleCredentialError.unavailable }
  }
  func install(_ body: Data, accountID: String, ticket: State.Ticket) async throws -> Bool {
    check(accountID == "fixture-account")
    events.append("install-begin")
    if installationBlocked { await withCheckedContinuation { installContinuation = $0 } }
    events.append("install-end")
    return !fenced
  }
  func fenceOrDrain(_ binding: State.Binding, invalidatingSession: Bool) async throws {
    fenced = true; events.append("fence")
  }
  func revokeAutomaticLeaseAndCloseManagedFlows(_ binding: State.Binding) async throws { events.append("revoke") }
  func clearVolatileBundle(_ binding: State.Binding) async throws { events.append("clear") }
  func isLeaseInstalled() async -> Bool { !fenced && events.contains("install-end") }
}

private final class Clock: @unchecked Sendable {
  private let lock = NSLock()
  private var value: TimeInterval = 1000
  func now() -> Date { lock.lock(); defer { lock.unlock() }; return Date(timeIntervalSince1970: value) }
  func set(_ value: TimeInterval) { lock.lock(); self.value = value; lock.unlock() }
}

@main
@MainActor
private struct RenewalOwnerChecks {
  static func wait(_ condition: () async -> Bool) async {
    let deadline = ContinuousClock.now.advanced(by: .seconds(3))
    while ContinuousClock.now < deadline {
      if await condition() { return }
      try? await Task.sleep(nanoseconds: 1_000_000)
    }
    preconditionFailure("asynchronous fixture did not reach the expected state")
  }

  static func owner(_ harness: Harness, _ clock: Clock = Clock()) -> ClientBundleRenewalOwner {
    ClientBundleRenewalOwner(credentials: harness, transport: harness, control: harness, core: harness, clock: { clock.now() })
  }

  static func main() async {
    await installAcknowledgement()
    await logoutDrainsInstallation()
    await cleanupFailureBlocksDeletion()
    await authenticationAndEntitlement()
    await replacedOwnerPreservesAuthorization()
    await shortenedTTL()
    await automaticShortenedTTL()
    print("PASS 7 renewal owner scenarios: install ACK, logout drain, cleanup retry, 401/403, owner handoff, shortened TTL, automatic scheduling")
    print("Injected adapters only; no real credentials, network, native Core, Keychain or device execution")
  }

  static func installAcknowledgement() async {
    let h = Harness()
    await h.configure(blocked: true)
    let o = owner(h)
    await o.start(first, automaticScheduling: false)
    await wait { await h.snapshot().contains("install-begin") }
    check(await o.usableLease() == nil)
    await h.releaseInstall()
    await wait { await o.usableLease() != nil }
    await o.stop()
    let events = await h.snapshot()
    check(!events.contains("delete-10"))
    check(events.suffix(4) == ["owner-barrier", "fence", "revoke", "clear"])
  }

  static func logoutDrainsInstallation() async {
    let h = Harness()
    await h.configure(blocked: true)
    let o = owner(h)
    await o.start(first, automaticScheduling: false)
    await wait { await h.snapshot().contains("install-begin") }
    let logout = Task { await o.logout() }
    await wait { await h.snapshot().contains("fence") }
    check(!(await h.snapshot()).contains("delete-10"))
    await h.releaseInstall()
    await logout.value
    let events = await h.snapshot()
    let index = { (value: String) in events.firstIndex(of: value)! }
    check(index("session-barrier") < index("fence"))
    check(index("install-end") < index("revoke"))
    check(index("revoke") < index("delete-10") && index("delete-10") < index("clear"))
    check(await o.usableLease() == nil)
  }

  static func cleanupFailureBlocksDeletion() async {
    let h = Harness()
    let o = owner(h)
    await o.start(first, automaticScheduling: false)
    await wait { await o.usableLease() != nil }
    await h.configure(barrierFails: true)
    await o.logout()
    check(await o.phase() == .terminating)
    check(!(await h.snapshot()).contains("delete-10"))
    await h.allowBarrier()
    await o.retryCleanup()
    check(await o.phase() == .inactive)
    check((await h.snapshot()).filter { $0 == "delete-10" }.count == 1)
  }

  static func authenticationAndEntitlement() async {
    for status in [401, 403] {
      let h = Harness()
      await h.configure(status: status, body: #"{"error":{"code":"entitlement_unavailable"}}"#)
      let o = owner(h)
      await o.start(first, automaticScheduling: false)
      await wait { await h.snapshot().contains("clear") }
      let events = await h.snapshot()
      check(events.contains("delete-10") == (status == 401))
      check(await o.phase() == (status == 401 ? .inactive : .ready))
      await o.stop()
    }
    let h = Harness()
    await h.configure(status: 403, body: "<html>edge unavailable</html>")
    let o = owner(h)
    await o.start(first, automaticScheduling: false)
    await wait { await o.phase() == .ready }
    check(!(await h.snapshot()).contains("revoke"))
    await o.stop()
  }

  static func replacedOwnerPreservesAuthorization() async {
    let h = Harness()
    let o = owner(h)
    await o.start(first, automaticScheduling: false)
    await wait { await o.usableLease() != nil }
    await h.replaceOwner()
    await o.tick()
    check(await o.phase() == .inactive)
    check(!(await h.snapshot()).contains("delete-10"))
  }

  static func shortenedTTL() async {
    let h = Harness()
    await h.configure(body: #"{"data":{"schema_version":1,"account_id":"fixture-account","issued_at":1000,"expires_at":1010}}"#)
    let clock = Clock()
    let o = owner(h, clock)
    await o.start(first, automaticScheduling: false)
    await wait { await o.usableLease() != nil }
    clock.set(1005)
    await o.tick()
    await wait { (await h.snapshot()).filter { $0 == "request" }.count == 2 }
    clock.set(1011)
    check(await o.usableLease() == nil)
    await o.stop()
  }

  static func automaticShortenedTTL() async {
    let h = Harness()
    await h.configure(body: #"{"data":{"schema_version":1,"account_id":"fixture-account","issued_at":1000,"expires_at":1002}}"#)
    let clock = Clock()
    let o = owner(h, clock)
    await o.start(first)
    await wait { await o.usableLease() != nil }
    clock.set(1001)
    await wait { (await h.snapshot()).filter { $0 == "request" }.count == 2 }
    await o.stop()
  }
}
