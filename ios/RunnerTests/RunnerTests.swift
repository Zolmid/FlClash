import Foundation
import Shared
import XCTest
@testable import Runner

final class RunnerTests: XCTestCase {
  func testPrivateRenewalOnlyAcceptsBoundedStructured401AsAuthoritative() {
    XCTAssertTrue(
      ClientBundleRenewalOwner.isAuthoritativeUnauthorized(
        Data(#"{\"error\":{\"code\":\"unauthenticated\"}}"#.utf8)
      )
    )
    for body in ["", "<html>unauthorized</html>", #"{\"error\":{\"code\":\"edge_blocked\"}}"#] {
      XCTAssertFalse(ClientBundleRenewalOwner.isAuthoritativeUnauthorized(Data(body.utf8)))
    }
    XCTAssertFalse(ClientBundleRenewalOwner.isAuthoritativeUnauthorized(Data(repeating: 65, count: 8 * 1024 + 1)))
  }

  func testFailedRenewalInstallKeepsHealthyLeaseAndBacksOff() {
    let now = Date(timeIntervalSince1970: 1_000)
    let binding = ClientBundleRenewalState.Binding(
      session: .init(1), owner: .init(1)
    )
    var state = ClientBundleRenewalState()
    _ = state.activate(binding, now: now)

    let initial = request(&state, at: now)
    let installed = ClientBundleRenewalState.BundleDescriptor(
      issuedAt: now, expiresAt: now.addingTimeInterval(180)
    )
    let initialInstall = install(&state, initial, bundle: installed, at: now)
    XCTAssertTrue(state.acknowledgeInstall(initialInstall, succeeded: true, now: now).isEmpty)

    let renewalAt = now.addingTimeInterval(60)
    let renewal = request(&state, at: renewalAt)
    let replacement = ClientBundleRenewalState.BundleDescriptor(
      issuedAt: renewalAt, expiresAt: renewalAt.addingTimeInterval(180)
    )
    let failedInstall = install(&state, renewal, bundle: replacement, at: renewalAt)

    XCTAssertTrue(state.acknowledgeInstall(failedInstall, succeeded: false, now: renewalAt).isEmpty)
    XCTAssertEqual(state.phase, .ready)
    XCTAssertEqual(state.usableLease(at: renewalAt), installed)
    XCTAssertGreaterThan(state.nextRequestAt!, renewalAt)
  }

  func testFailedInitialInstallAndHardDenyRemainFailClosed() {
    let now = Date(timeIntervalSince1970: 1_000)
    let binding = ClientBundleRenewalState.Binding(
      session: .init(1), owner: .init(1)
    )
    let bundle = ClientBundleRenewalState.BundleDescriptor(
      issuedAt: now, expiresAt: now.addingTimeInterval(180)
    )

    var initial = ClientBundleRenewalState()
    _ = initial.activate(binding, now: now)
    let initialTicket = request(&initial, at: now)
    let initialInstall = install(&initial, initialTicket, bundle: bundle, at: now)
    XCTAssertFalse(initial.acknowledgeInstall(initialInstall, succeeded: false, now: now).isEmpty)
    XCTAssertEqual(initial.phase, .terminating)

    var active = ClientBundleRenewalState()
    _ = active.activate(binding, now: now)
    let activeTicket = request(&active, at: now)
    let activeInstall = install(&active, activeTicket, bundle: bundle, at: now)
    _ = active.acknowledgeInstall(activeInstall, succeeded: true, now: now)
    let denied = request(&active, at: now.addingTimeInterval(60))
    XCTAssertFalse(
      active.completeRequest(denied, result: .unauthorized, now: now.addingTimeInterval(60)).isEmpty
    )
    XCTAssertEqual(active.phase, .terminating)
  }

  func testFailedReplacementAfterLeaseExpiryRemainsFailClosed() {
    let now = Date(timeIntervalSince1970: 1_000)
    let binding = ClientBundleRenewalState.Binding(
      session: .init(1), owner: .init(1)
    )
    var state = ClientBundleRenewalState()
    _ = state.activate(binding, now: now)
    let initialTicket = request(&state, at: now)
    let initialBundle = ClientBundleRenewalState.BundleDescriptor(
      issuedAt: now, expiresAt: now.addingTimeInterval(60)
    )
    let initialInstall = install(&state, initialTicket, bundle: initialBundle, at: now)
    _ = state.acknowledgeInstall(initialInstall, succeeded: true, now: now)

    let expiredAt = now.addingTimeInterval(61)
    XCTAssertNil(state.usableLease(at: expiredAt))
    let renewal = request(&state, at: expiredAt)
    let replacement = ClientBundleRenewalState.BundleDescriptor(
      issuedAt: expiredAt, expiresAt: expiredAt.addingTimeInterval(60)
    )
    let failedInstall = install(&state, renewal, bundle: replacement, at: expiredAt)
    XCTAssertFalse(state.acknowledgeInstall(failedInstall, succeeded: false, now: expiredAt).isEmpty)
    XCTAssertEqual(state.phase, .terminating)
  }

  func testTransientRenewalRetriesBeforeShortLeaseExpiryAndRecovers() {
    let now = Date(timeIntervalSince1970: 1_000)
    let binding = ClientBundleRenewalState.Binding(
      session: .init(1), owner: .init(1)
    )
    var state = ClientBundleRenewalState()
    _ = state.activate(binding, now: now)
    let initialTicket = request(&state, at: now)
    let shortLease = ClientBundleRenewalState.BundleDescriptor(
      issuedAt: now, expiresAt: now.addingTimeInterval(25)
    )
    let initialInstall = install(&state, initialTicket, bundle: shortLease, at: now)
    _ = state.acknowledgeInstall(initialInstall, succeeded: true, now: now)

    let failureAt = now.addingTimeInterval(12.5)
    let failedTicket = request(&state, at: failureAt)
    XCTAssertTrue(state.completeRequest(failedTicket, result: .transportFailure, now: failureAt).isEmpty)
    let retryAt = try! XCTUnwrap(state.nextRequestAt)
    XCTAssertEqual(retryAt, failureAt.addingTimeInterval(6.25))
    XCTAssertLessThan(retryAt, shortLease.expiresAt)

    let retryTicket = request(&state, at: retryAt)
    let replacement = ClientBundleRenewalState.BundleDescriptor(
      issuedAt: retryAt, expiresAt: retryAt.addingTimeInterval(180)
    )
    let replacementInstall = install(&state, retryTicket, bundle: replacement, at: retryAt)
    XCTAssertTrue(state.acknowledgeInstall(replacementInstall, succeeded: true, now: retryAt).isEmpty)
    XCTAssertEqual(state.usableLease(at: retryAt), replacement)
  }

  private func request(
    _ state: inout ClientBundleRenewalState, at now: Date
  ) -> ClientBundleRenewalState.Ticket {
    guard case .requestBundle(let ticket) = state.beginRequest(now: now, credentials: .available).first
    else { fatalError("expected renewal request") }
    return ticket
  }

  private func install(
    _ state: inout ClientBundleRenewalState, _ ticket: ClientBundleRenewalState.Ticket,
    bundle: ClientBundleRenewalState.BundleDescriptor, at now: Date
  ) -> ClientBundleRenewalState.Ticket {
    guard case .installBundle(let installTicket, _) = state.completeRequest(
      ticket, result: .validatedBundle(bundle), now: now
    ).first else { fatalError("expected install") }
    return installTicket
  }

  func testQuickActionsKeepTheLatestIntentBeforeEngineStartup() {
    XCTAssertEqual(QuickAction.start.folded(onto: .stop), .start)
    XCTAssertEqual(QuickAction.stop.folded(onto: .start), .stop)
    XCTAssertEqual(QuickAction.toggle.folded(onto: .start), .stop)
    XCTAssertEqual(QuickAction.toggle.folded(onto: .stop), .start)
    XCTAssertNil(QuickAction.toggle.folded(onto: .toggle))
  }

  @MainActor
  func testRouteWatchMigratesBeforeReleasingThePreviousCore() async throws {
    let migrated = expectation(description: "route watch migrated")
    var calls: [(CoreRoute, Bool)] = []
    let coordinator = CoreNotificationCoordinator { data, route in
      let payload = try JSONSerialization.jsonObject(with: data) as! [String: Any]
      XCTAssertEqual(payload["method"] as? String, "watchRoute")
      let watch = payload["arguments"] as! Bool
      calls.append((route, watch))
      if !watch {
        migrated.fulfill()
      }
      return #"{"result":{},"error":null}"#
    }
    let watch = Data(#"{"method":"watchRoute","arguments":true}"#.utf8)
    coordinator.recordSuccessfulStart(.route, data: watch, route: .app)
    coordinator.setDesiredRoute(.networkExtension)

    await fulfillment(of: [migrated], timeout: 1)
    XCTAssertEqual(calls.count, 2)
    XCTAssertEqual(calls.first?.0, .networkExtension)
    XCTAssertEqual(calls.first?.1, true)
    XCTAssertEqual(calls.last?.0, .app)
    XCTAssertEqual(calls.last?.1, false)
  }

  @MainActor
  func testAgeKeyUtilitiesStayInTheAppWhileRuntimeQueriesUseTheTunnel() async {
    var routes: [CoreRoute] = []
    let router = CoreMessageRouter { _, route in
      routes.append(route)
      return #"{"result":null}"#
    }
    router.updateTunnelState(.running)

    for method in ["generateAgeKeyPair", "convertAgeSecretKeyToPublicKey", "getCoreVersion"] {
      _ = await router.invoke(Data("{\"method\":\"\(method)\",\"arguments\":null}".utf8))
    }

    XCTAssertEqual(routes, [.app, .app, .networkExtension])
  }

  @MainActor
  func testProfileConstructionStaysInTheAppWhileTheTunnelRuns() async {
    var routes: [CoreRoute] = []
    let router = CoreMessageRouter { _, route in
      routes.append(route)
      return #"{"result":null}"#
    }
    router.updateTunnelState(.running)

    for method in ["getProfileBase", "getProfileOutbounds", "buildProfile"] {
      _ = await router.invoke(Data("{\"method\":\"\(method)\",\"arguments\":null}".utf8))
    }

    XCTAssertEqual(routes, [.app, .app, .app])
  }

  @MainActor
  func testProviderFailureDoesNotAcknowledgeWritesFromTheAppCore() async throws {
    for method in [
      "changeProxy", "getRoutingLease", "getRoutingLeaseObservation", "invalidateRoutingLease", "closeConnection", "closeConnections", "updateExternalProvider",
      "getMemoryStats", "projectSignedSubscription",
    ] {
      var routes: [CoreRoute] = []
      let router = CoreMessageRouter { _, route in
        routes.append(route)
        if route == .networkExtension {
          throw ProviderMessageError(
            code: "network_extension_unavailable",
            message: "network extension disconnected"
          )
        }
        return #"{"id":"write","result":"app-success"}"#
      }
      let request = try JSONSerialization.data(withJSONObject: [
        "id": "write", "method": method, "arguments": NSNull(),
      ] as [String: Any])
      router.updateTunnelState(.running)

      let response = await router.invoke(request)
      let payload = try JSONSerialization.jsonObject(with: Data(response.utf8))
        as! [String: Any]
      let error = payload["error"] as? [String: Any]
      XCTAssertEqual(error?["code"] as? String, "network_extension_unavailable", method)
      XCTAssertEqual(payload["id"] as? String, "write", method)
      XCTAssertEqual(routes, [.networkExtension], method)

      routes.removeAll()
      router.updateTunnelState(.stopped)
      let stoppedResponse = await router.invoke(request)
      XCTAssertTrue(stoppedResponse.contains("app-success"), method)
      XCTAssertEqual(routes, [.app], method)
    }
  }

  func testStateEventsSurvivePausedTransientDelivery() throws {
    let directory = try makeEventDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let backlog = CoreEventBacklog(directory: directory, maxTransientFiles: 1)
    try backlog.enqueue(eventBatch([("log", "first")]))
    try backlog.enqueue(eventBatch([("log", "second")]))
    XCTAssertTrue(backlog.transientEventsPaused)

    try backlog.enqueue(eventBatch([("geoUpdate", ["type": "geoip", "updating": true])]))
    let result = try backlog.enqueue(eventBatch([
      ("geoUpdate", ["type": "geoip", "updating": false]),
      ("routeChanged", ["core-epoch": 1, "picks-version": 2]),
      ("loaded", "provider-a"),
    ]))

    XCTAssertTrue(result.wroteEvents)
    XCTAssertEqual(result.rejectedStateEvents, 0)
    let events = try pendingStateEvents(in: directory)
    XCTAssertEqual(events.filter { $0["type"] as? String == "geoUpdate" }.count, 1)
    let geo = events.first { $0["type"] as? String == "geoUpdate" }?["data"] as? [String: Any]
    XCTAssertEqual(geo?["updating"] as? Bool, false)
    XCTAssertTrue(events.contains { $0["type"] as? String == "routeChanged" })
    XCTAssertTrue(events.contains { $0["data"] as? String == "provider-a" })
  }

  func testStateBacklogPreservesIndependentProvidersWithinItsBound() throws {
    let directory = try makeEventDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let backlog = CoreEventBacklog(directory: directory, maxStateKeys: 2)
    try backlog.enqueue(eventBatch([("loaded", "provider-a"), ("loaded", "provider-b")]))
    let result = try backlog.enqueue(eventBatch([
      ("loaded", "provider-a"), ("loaded", "provider-c"),
    ]))

    XCTAssertEqual(result.rejectedStateEvents, 1)
    let providers = try pendingStateEvents(in: directory).compactMap { $0["data"] as? String }
    XCTAssertEqual(Set(providers), ["provider-a", "provider-b"])
    XCTAssertEqual(providers.count, 2)
  }

  func testAcknowledgingAnOldStateFileDoesNotDeleteItsReplacement() throws {
    let directory = try makeEventDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let backlog = CoreEventBacklog(directory: directory)
    try backlog.enqueue(eventBatch([("geoUpdate", ["type": "geoip", "updating": true])]))
    let oldFiles = try FileManager.default.contentsOfDirectory(
      at: directory,
      includingPropertiesForKeys: nil
    )
    try backlog.enqueue(eventBatch([("geoUpdate", ["type": "geoip", "updating": false])]))
    for file in oldFiles {
      try? FileManager.default.removeItem(at: file)
    }

    let events = try pendingStateEvents(in: directory)
    XCTAssertEqual(events.count, 1)
    let geo = events.first?["data"] as? [String: Any]
    XCTAssertEqual(geo?["updating"] as? Bool, false)
  }

  private func makeEventDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString,
      isDirectory: true
    )
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }

  private func eventBatch(_ events: [(String, Any)]) throws -> Data {
    try JSONSerialization.data(withJSONObject: [
      "method": "message",
      "arguments": events.map { ["type": $0.0, "data": $0.1] },
    ])
  }

  private func pendingStateEvents(in directory: URL) throws -> [[String: Any]] {
    let files = try FileManager.default.contentsOfDirectory(
      at: directory,
      includingPropertiesForKeys: nil
    ).filter { $0.lastPathComponent.contains("-state-") }
    return try files.flatMap { file in
      let data = try Data(contentsOf: file)
      let payload = try JSONSerialization.jsonObject(with: data) as! [String: Any]
      XCTAssertEqual(payload["method"] as? String, "message")
      return payload["arguments"] as! [[String: Any]]
    }
  }
}
