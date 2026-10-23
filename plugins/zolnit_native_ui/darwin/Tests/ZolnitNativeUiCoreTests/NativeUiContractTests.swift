import XCTest
@testable import ZolnitNativeUiCore

final class NativeUiContractTests: XCTestCase {
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
}
