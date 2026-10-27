import XCTest
@testable import ZolnitNativeUiCore

final class NativeUiContractTests: XCTestCase {
    private func routeSnapshot(_ route: Any? = nil, revision: Int = 1, generation: Int = 1) throws -> String {
        let snapshot = NativeUiSnapshot(
            schemaVersion: 1, revision: revision, accountGeneration: generation, locale: "en",
            textDirection: .ltr, safeMode: false, sessionStatus: .signedIn,
            connectionState: .disconnected, destination: .connect, mode: .rule,
            selectedServerId: nil, servers: [], planName: nil, planExpiresAt: nil,
            usage: .init(usedBytes: nil, totalBytes: nil), traffic: .init(uploadBps: nil, downloadBps: nil),
            labels: Dictionary(uniqueKeysWithValues: NativeUiSnapshot.requiredLabels.map { ($0, $0) })
        )
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot)) as? [String: Any])
        json["returnRoute"] = route
        return try XCTUnwrap(String(data: JSONSerialization.data(withJSONObject: json), encoding: .utf8))
    }

    private var route: [String: Any] {
        ["title": "RETURN ROUTE", "enabled": true, "activationAvailable": true, "active": true, "options": [
            ["id": "direct", "label": "Direct"], ["id": "hk_lite", "label": "Lite"],
            ["id": "hk_optimized", "label": "Optimized"],
        ]]
    }

    func testOptionalReturnRouteHidesMalformedWithoutRejectingSnapshot() throws {
        XCTAssertNil(try NativeUiSnapshot.decode(json: routeSnapshot()).returnRoute)
        XCTAssertNil(try NativeUiSnapshot.decode(json: routeSnapshot(route)).returnRoute?.selectedId)
        for id in ["direct", "hk_lite", "hk_optimized"] {
            var value = route
            value["selectedId"] = id
            XCTAssertEqual(try NativeUiSnapshot.decode(json: routeSnapshot(value)).returnRoute?.selectedId, id)
        }
        var badEnabled = route; badEnabled["enabled"] = "true"
        var badSelected = route; badSelected["selectedId"] = "DIRECT"
        var badType = route; badType["selectedId"] = 1
        var duplicate = route; duplicate["options"] = [["id": "direct", "label": "A"], ["id": "direct", "label": "B"]]
        var empty = route; empty["options"] = [] as [[String: String]]; empty["activationAvailable"] = false
        for value in [NSNull(), false, [:], empty, badEnabled, badSelected, badType, duplicate] as [Any] {
            XCTAssertNil(try NativeUiSnapshot.decode(json: routeSnapshot(value)).returnRoute)
        }
    }

    func testReturnRouteDowngradeKeepsOnlySelectedLiteAndRejectsRemovedRoles() throws {
        let store = NativeUiStore()
        XCTAssertTrue(store.publish(json: try routeSnapshot(route)))
        XCTAssertEqual(store.snapshot?.returnRoute?.options.map(\.id), ["direct", "hk_lite", "hk_optimized"])
        var lite = route
        lite["options"] = [["id": "hk_lite", "label": "Lite"]]
        lite["selectedId"] = "hk_lite"
        XCTAssertTrue(store.publish(json: try routeSnapshot(lite, revision: 2)))
        XCTAssertEqual(store.snapshot?.returnRoute?.options.map(\.id), ["hk_lite"])
        XCTAssertEqual(store.snapshot?.returnRoute?.selectedId, "hk_lite")
        var sent: [NativeUiCommand] = []
        let bridge = NativeUiBridge(store: store) { json, _ in
            sent.append(try! JSONDecoder().decode(NativeUiCommand.self, from: Data(json.utf8)))
        }
        for id in ["direct", "hk_optimized"] {
            bridge.send(.selectReturnRoute, payload: ["optionId": id])
            var stale = lite; stale["selectedId"] = id
            XCTAssertNil(try NativeUiSnapshot.decode(json: routeSnapshot(stale)).returnRoute)
        }
        XCTAssertTrue(sent.isEmpty)
        bridge.send(.selectReturnRoute, payload: ["optionId": "hk_lite"])
        XCTAssertEqual(sent.first?.payload, ["optionId": "hk_lite"])
        XCTAssertEqual(sent.count, 1)
    }

    func testReturnRouteUsesExistingCommandAndBusyGenerationChannel() throws {
        let store = NativeUiStore()
        XCTAssertTrue(store.publish(json: try routeSnapshot(route)))
        var sent: [NativeUiCommand] = []
        var completion: ((String?) -> Void)?
        let bridge = NativeUiBridge(store: store) { json, finish in
            sent.append(try! JSONDecoder().decode(NativeUiCommand.self, from: Data(json.utf8)))
            completion = finish
        }
        bridge.send(.selectReturnRoute, payload: ["optionId": "DIRECT"])
        XCTAssertTrue(sent.isEmpty)
        bridge.send(.selectReturnRoute, payload: ["optionId": "hk_lite"])
        bridge.send(.selectReturnRoute, payload: ["optionId": "direct"])
        XCTAssertEqual(sent.count, 1)
        XCTAssertEqual(sent.first?.payload, ["optionId": "hk_lite"])
        XCTAssertEqual(sent.first?.accountGeneration, 1)
        XCTAssertNil(store.snapshot?.returnRoute?.selectedId)
        XCTAssertTrue(bridge.hasPendingCommand)
        XCTAssertTrue(store.publish(json: try routeSnapshot(route, revision: 2, generation: 2)))
        completion?(nil)
        let settled = expectation(description: "old receipt")
        DispatchQueue.main.async { settled.fulfill() }
        wait(for: [settled], timeout: 1)
        XCTAssertNil(bridge.feedback)
        XCTAssertFalse(bridge.hasPendingCommand)
        var disabled = route; disabled["enabled"] = false
        XCTAssertTrue(store.publish(json: try routeSnapshot(disabled, revision: 3, generation: 2)))
        bridge.send(.selectReturnRoute, payload: ["optionId": "direct"])
        XCTAssertEqual(sent.count, 1)
    }

    func testBinaryByteTextPreservesUnknownAndMeasuredZero() {
        XCTAssertEqual(NativeByteText.format(100 * 1024 * 1024 * 1024, locale: "en_US"), "100 GiB")
        XCTAssertEqual(NativeByteText.format(1024, locale: "en_US"), "1 KiB")
        XCTAssertEqual(NativeByteText.format(0, locale: "en_US"), "0 B")
        XCTAssertEqual(NativeByteText.format(nil, locale: "en_US"), "—")
    }

    func testUnknownMetricsRemainDistinctFromMeasuredZero() throws {
        let labels = NativeUiSnapshot.requiredLabels.reduce(into: [String: String]()) { $0[$1] = $1 }
        let snapshot = NativeUiSnapshot(
            schemaVersion: 1, revision: 1, accountGeneration: 1, locale: "en",
            textDirection: .ltr, safeMode: true, sessionStatus: .signedIn,
            connectionState: .disconnected, destination: .connect, mode: .rule,
            selectedServerId: nil, servers: [], planName: nil, planExpiresAt: nil,
            usage: .init(usedBytes: nil, totalBytes: nil),
            traffic: .init(uploadBps: nil, downloadBps: 0), labels: labels
        )
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try NativeUiSnapshot.decode(json: XCTUnwrap(String(data: data, encoding: .utf8)))
        XCTAssertNil(decoded.usage.usedBytes)
        XCTAssertNil(decoded.traffic.uploadBps)
        XCTAssertEqual(decoded.traffic.downloadBps, 0)
    }

    func testRejectsOlderRevisionAndAccountGeneration() throws {
        let store = NativeUiStore()
        let labels = NativeUiSnapshot.requiredLabels.reduce(into: [String: String]()) { $0[$1] = $1 }
        let first = NativeUiSnapshot(schemaVersion: 1, revision: 4, accountGeneration: 2, locale: "en", textDirection: .ltr, safeMode: false, sessionStatus: .signedIn, connectionState: .disconnected, destination: .connect, mode: .rule, selectedServerId: nil, servers: [], planName: nil, planExpiresAt: nil, usage: .init(usedBytes: 0, totalBytes: nil), traffic: .init(uploadBps: 0, downloadBps: 0), labels: labels)
        let oldAccount = NativeUiSnapshot(schemaVersion: 1, revision: 5, accountGeneration: 1, locale: "en", textDirection: .ltr, safeMode: false, sessionStatus: .signedOut, connectionState: .disconnected, destination: .connect, mode: .rule, selectedServerId: nil, servers: [], planName: nil, planExpiresAt: nil, usage: .init(usedBytes: 0, totalBytes: nil), traffic: .init(uploadBps: 0, downloadBps: 0), labels: labels)
        let encoder = JSONEncoder()
        let firstJson = try XCTUnwrap(String(data: encoder.encode(first), encoding: .utf8))
        let oldAccountJson = try XCTUnwrap(String(data: encoder.encode(oldAccount), encoding: .utf8))
        let acceptedFirst = store.publish(json: firstJson)
        let acceptedDuplicate = store.publish(json: firstJson)
        let acceptedOldAccount = store.publish(json: oldAccountJson)
        XCTAssertTrue(acceptedFirst)
        XCTAssertFalse(acceptedDuplicate)
        XCTAssertFalse(acceptedOldAccount)
    }


    func testActivationFieldsDefaultWhenAbsent() throws {
        var legacy = route
        legacy.removeValue(forKey: "activationAvailable")
        legacy.removeValue(forKey: "active")
        let snapshot = try NativeUiSnapshot.decode(json: routeSnapshot(legacy))
        XCTAssertEqual(snapshot.returnRoute?.activationAvailable, false)
        XCTAssertEqual(snapshot.returnRoute?.active, false)
        XCTAssertEqual(snapshot.returnRoute?.activationLabel, "RETURN ROUTE")
    }

    @MainActor func testActivationUsesBooleanAndWaitsForAuthoritativeSnapshot() throws {
        for requested in [true, false] {
            let store = NativeUiStore()
            var value = route
            value["active"] = !requested
            if !requested { value["options"] = [] as [[String: String]] }
            XCTAssertTrue(store.publish(json: try routeSnapshot(value)))
            var commands = [String]()
            let bridge = NativeUiBridge(store: store) { command, _ in commands.append(command) }
            bridge.sendReturnRouting(enabled: requested)
            XCTAssertEqual(commands.count, 1)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(commands[0].utf8)) as? [String: Any])
            XCTAssertEqual(json["action"] as? String, "setReturnRouting")
            let payload = try XCTUnwrap(json["payload"] as? [String: Any])
            XCTAssertEqual(payload["enabled"] as? Bool, requested)
            XCTAssertEqual(store.snapshot?.returnRoute?.active, !requested)
        }
    }

    func testActivationFieldsParsedWhenPresent() throws {
        var value = route
        value["activationAvailable"] = true
        value["active"] = true
        value["activationLabel"] = "Enable China Routing"
        let snapshot = try NativeUiSnapshot.decode(json: routeSnapshot(value))
        XCTAssertEqual(snapshot.returnRoute?.activationAvailable, true)
        XCTAssertEqual(snapshot.returnRoute?.active, true)
        XCTAssertEqual(snapshot.returnRoute?.activationLabel, "Enable China Routing")
    }

    func testMalformedActivationFieldsFailClosed() throws {
        var badAvailable = route; badAvailable["activationAvailable"] = "true"
        var badActive = route; badActive["active"] = 1
        var badLabelType = route; badLabelType["activationLabel"] = 42
        var badLabelEmpty = route; badLabelEmpty["activationLabel"] = ""
        for value in [badAvailable, badActive, badLabelType, badLabelEmpty] {
            XCTAssertNil(try NativeUiSnapshot.decode(json: routeSnapshot(value)).returnRoute)
        }
    }

    func testSetReturnRoutingActionRoundTrips() throws {
        let command = NativeUiCommand(accountGeneration: 1, action: .setReturnRouting, payload: [:])
        let data = try JSONEncoder().encode(command)
        let decoded = try JSONDecoder().decode(NativeUiCommand.self, from: data)
        XCTAssertEqual(decoded.action, .setReturnRouting)
    }
}
