import Foundation

@main enum ClientBundleRenewalCheck {
  typealias State = ClientBundleRenewalState
  static let a = State.Binding(session: .init(1), owner: .init(1))
  static let b = State.Binding(session: .init(2), owner: .init(2))
  static func date(_ seconds: Double) -> Date { Date(timeIntervalSince1970: seconds) }
  static func bundle(_ issued: Double = 1000, _ expires: Double = 1300) -> State.BundleDescriptor {
    .init(issuedAt: date(issued), expiresAt: date(expires))
  }
  static func request(_ state: inout State, _ time: Double) -> State.Ticket {
    let intents = state.beginRequest(now: date(time), credentials: .available)
    guard intents.count == 1, case .requestBundle(let ticket) = intents[0] else {
      fatalError("expected request")
    }
    return ticket
  }
  static func stage(_ state: inout State, _ ticket: State.Ticket, _ descriptor: State.BundleDescriptor,
                    _ time: Double) {
    precondition(state.completeRequest(ticket, result: .validatedBundle(descriptor), now: date(time))
      == [.installBundle(ticket, descriptor)])
  }
  static func cleanup(_ state: inout State) -> [State.CleanupStep] {
    var steps: [State.CleanupStep] = []
    while let intent = state.pendingCleanup {
      steps.append(intent.step)
      _ = state.acknowledgeCleanup(intent)
    }
    return steps
  }

  static func main() {
    installAndEpochs()
    logoutOrdering()
    errorsAndExpiry()
    statusAndStop()
    print("PASS 4 Foundation scenarios: ACK gating/late callbacks, ordered drain/logout, TTL/backoff, 401/403/stop")
    print("Pure intent checks only; no native apply cancellation, IO, device, or runtime integration verified")
  }

  static func installAndEpochs() {
    var state = State()
    let initial = state.activate(a, existingBundle: bundle(), now: date(1000))
    guard case .installBundle(let initialTicket, _) = initial.first else { fatalError("stage existing") }
    precondition(state.installedBundle == nil && state.usableLease(at: date(1000)) == nil)
    precondition(state.beginRequest(now: date(1060), credentials: .available).isEmpty)
    _ = state.acknowledgeInstall(initialTicket, succeeded: true, now: date(1001))
    precondition(state.usableLease(at: date(1001)) == bundle())
    precondition(state.beginRequest(now: date(1059), credentials: .available).isEmpty)
    let old = request(&state, 1060)
    precondition(state.beginRequest(now: date(1120), credentials: .available).isEmpty)
    stage(&state, old, bundle(1060, 1360), 1061)
    precondition(state.installedBundle == bundle())
    _ = state.logout()
    _ = cleanup(&state)
    _ = state.activate(b, now: date(1100))
    let fresh = request(&state, 1100)
    for result: State.NetworkResult in [.validatedBundle(bundle(1100, 1400)), .unauthorized, .forbidden] {
      precondition(state.completeRequest(old, result: result, now: date(1101)).isEmpty)
    }
    precondition(state.acknowledgeInstall(old, succeeded: true, now: date(1101)).isEmpty)
    precondition(state.binding == b && state.phase == .requesting && fresh.sequence > old.sequence)
    stage(&state, fresh, bundle(1100, 1400), 1102)
    _ = state.acknowledgeInstall(fresh, succeeded: true, now: date(1103))
    precondition(state.usableLease(at: date(1103)) == bundle(1100, 1400))
    _ = state.stopOwner()
    _ = cleanup(&state)
    let changedOwner = State.Binding(session: b.session, owner: .init(3))
    _ = state.activate(changedOwner, now: date(1160))
    let ownerTicket = request(&state, 1160)
    precondition(ownerTicket.binding.owner != fresh.binding.owner)
    for result: State.NetworkResult in [.validatedBundle(bundle(1160, 1460)), .unauthorized, .forbidden] {
      precondition(state.completeRequest(fresh, result: result, now: date(1161)).isEmpty)
    }
    precondition(state.acknowledgeInstall(fresh, succeeded: true, now: date(1161)).isEmpty)
    _ = state.stopOwner()
    _ = cleanup(&state)
    _ = state.activate(b, now: date(1200))
    _ = request(&state, 1200)
    precondition(state.completeRequest(fresh, result: .forbidden, now: date(1201)).isEmpty)
  }

  static func logoutOrdering() {
    var state = State()
    _ = state.activate(a, now: date(1000))
    let token = request(&state, 1000)
    stage(&state, token, bundle(), 1001)
    let before = state.generation
    let first = state.logout()
    precondition(state.generation > before && state.binding == nil && state.usableLease(at: date(1002)) == nil)
    let expected: [State.CleanupStep] = [.publishGenerationBarrier, .cancelURLRequest, .fenceOrDrainInstall,
      .revokeAutomaticLeaseAndCloseManagedFlows, .deleteOldEpochAuthorization, .clearOldBundle]
    var oldIntent: State.CleanupIntent?
    for step in expected {
      guard let intent = state.pendingCleanup else { fatalError("missing cleanup") }
      precondition(intent.step == step && intent.oldBinding == a)
      precondition(state.activate(b, now: date(1003)).isEmpty && state.phase == .terminating)
      if let oldIntent = oldIntent { precondition(state.acknowledgeCleanup(oldIntent).isEmpty) }
      if step == .fenceOrDrainInstall {
        precondition(state.acknowledgeInstall(token, succeeded: true, now: date(1003)).isEmpty)
        precondition(state.pendingCleanup == intent && state.phase == .terminating)
      }
      oldIntent = intent
      _ = state.acknowledgeCleanup(intent)
    }
    precondition(first.count == 1 && state.phase == .inactive)
    _ = state.activate(b, now: date(1010))
    precondition(state.acknowledgeCleanup(oldIntent!).isEmpty && state.binding == b)
  }

  static func errorsAndExpiry() {
    var state = State()
    _ = state.activate(a, now: date(1000))
    let token = request(&state, 1000)
    stage(&state, token, bundle(), 1001)
    _ = state.acknowledgeInstall(token, succeeded: true, now: date(1002))
    for credentials: State.Credentials in [.locked, .unavailable] {
      precondition(state.beginRequest(now: date(1060), credentials: credentials).isEmpty)
      precondition(state.binding == a && state.installedBundle == bundle())
    }
    let rate = request(&state, 1060)
    _ = state.completeRequest(rate, result: .rateLimited(retryAfter: date(1500)), now: date(1061))
    precondition(state.nextRequestAt == date(1500) && state.installedBundle == bundle())
    precondition(state.usableLease(at: date(1300)) == nil)
    precondition(state.beginRequest(now: date(1499), credentials: .available).isEmpty)
    let transport = request(&state, 1500)
    _ = state.completeRequest(transport, result: .transportFailure, now: date(1501))
    precondition(state.nextRequestAt == date(1621) && state.installedBundle == bundle())
    let unknown = request(&state, 1621)
    _ = state.completeRequest(unknown, result: .unknown, now: date(1622))
    precondition(state.nextRequestAt == date(1862) && state.usableLease(at: date(1622)) == nil)
    let fallback = request(&state, 1862)
    _ = state.completeRequest(fallback, result: .rateLimited(retryAfter: nil), now: date(1863))
    precondition(state.nextRequestAt == date(2163))
    let recovery = request(&state, 2163)
    stage(&state, recovery, bundle(2163, 2463), 2164)
    precondition(state.usableLease(at: date(2164)) == nil)
    _ = state.acknowledgeInstall(recovery, succeeded: true, now: date(2165))
    precondition(state.usableLease(at: date(2165)) == bundle(2163, 2463))
    for invalid in [bundle(1000, 1301), bundle(1000, 1000), bundle(999, 1000),
                    bundle(1001, 1300), bundle(.nan, 1300)] {
      var check = State()
      precondition(check.activate(a, existingBundle: invalid, now: date(1000)).isEmpty)
      let bad = request(&check, 1000)
      precondition(check.completeRequest(bad, result: .validatedBundle(invalid), now: date(1000)).isEmpty)
      precondition(check.phase == .ready && check.installedBundle == nil)
    }
    var expiredACK = State()
    _ = expiredACK.activate(a, now: date(1000))
    let expiring = request(&expiredACK, 1000)
    stage(&expiredACK, expiring, bundle(), 1001)
    _ = expiredACK.acknowledgeInstall(expiring, succeeded: true, now: date(1300))
    precondition(expiredACK.phase == .terminating && expiredACK.usableLease(at: date(1300)) == nil)
  }

  static func statusAndStop() {
    for unauthorized in [true, false] {
      var state = State()
      _ = state.activate(a, now: date(1000))
      let token = request(&state, 1000)
      precondition(state.windowEnteredBackground().isEmpty && state.phase == .requesting)
      _ = state.completeRequest(token, result: unauthorized ? .unauthorized : .forbidden, now: date(1001))
      let steps = cleanup(&state)
      precondition(steps.contains(.deleteOldEpochAuthorization) == unauthorized)
      precondition(state.binding == (unauthorized ? nil : a))
      precondition(state.phase == (unauthorized ? .inactive : .ready))
      if !unauthorized {
        let retry = request(&state, 1061)
        stage(&state, retry, bundle(1061, 1361), 1062)
        _ = state.acknowledgeInstall(retry, succeeded: true, now: date(1063))
        precondition(state.usableLease(at: date(1063)) != nil)
      }
    }
    var state = State()
    _ = state.activate(a, now: date(1000))
    _ = request(&state, 1000)
    _ = state.stopOwner()
    let steps = cleanup(&state)
    precondition(steps == [.publishGenerationBarrier, .cancelURLRequest, .fenceOrDrainInstall,
      .revokeAutomaticLeaseAndCloseManagedFlows, .clearOldBundle])
    precondition(state.phase == .inactive)
    precondition(state.stopOwner().isEmpty)
    _ = state.logout()
    precondition(cleanup(&state).contains(.deleteOldEpochAuthorization))
    _ = state.activate(a, now: date(1100))
    _ = state.stopOwner()
    while state.pendingCleanup?.step != .clearOldBundle {
      _ = state.acknowledgeCleanup(state.pendingCleanup!)
    }
    let alreadyDispatched = state.pendingCleanup!
    let previousGeneration = state.generation
    _ = state.logout()
    precondition(state.generation > previousGeneration)
    precondition(state.activate(b, now: date(1101)).isEmpty)
    _ = state.acknowledgeCleanup(alreadyDispatched)
    precondition(state.pendingCleanup?.step == .publishGenerationBarrier)
    precondition(cleanup(&state) == [.publishGenerationBarrier, .cancelURLRequest, .fenceOrDrainInstall,
      .revokeAutomaticLeaseAndCloseManagedFlows, .deleteOldEpochAuthorization, .clearOldBundle])
  }
}
