import Foundation
import Shared
import XCTest
@testable import Runner

final class RunnerTests: XCTestCase {
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
      "changeProxy", "closeConnection", "closeConnections", "updateExternalProvider",
      "getMemoryStats",
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
