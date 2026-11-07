import Foundation

private func check(_ condition: Bool, file: StaticString = #file, line: UInt = #line) {
  precondition(condition, file: file, line: line)
}

private let binding = ClientBundleRenewalState.Binding(session: .init(10), owner: .init(20))
private let secret = "aW5zdGFsbGF0aW9uLXNlY3JldC1maXh0dXJlLTMyYnk"
private let device = ClientBundleSignedDevice(deviceID: "0123456789abcdef0123456789abcdef", installationID: secret)!
private let authorization = ClientBundleAuthorization(
  accountID: "fixture-account", binding: binding, value: "Bearer SYNTHETIC_ONLY", device: device)

private actor Fixture: ClientBundleSignedFetcher {
  var requests: [String] = []
  var status = 200
  var kind = "bundle"
  var offline = false
  var applied: [String] = []
  var packageInstalled = false
  var revoked = false
  var needsRefresh = false

  func set(status: Int = 200, kind: String = "bundle", offline: Bool = false, needsRefresh: Bool = false) {
    self.status = status; self.kind = kind; self.offline = offline; self.needsRefresh = needsRefresh
  }
  func seed(installed: Bool) { packageInstalled = installed }
  func snapshot() -> ([String], [String]) { (requests, applied) }

  func fetchSigned(
    authorization: ClientBundleAuthorization, device: ClientBundleSignedDevice, state: Bool
  ) async throws -> ClientBundleHTTPResponse {
    requests.append(state ? "state" : "bundle")
    if offline { throw ClientBundleTransportError.unavailable }
    let body = status == 200 ? #"{"data":{"kind":"\#(state ? "state" : kind)","signed":{}}}"#
      : #"{"error":{"code":"unauthenticated"}}"#
    return .init(status: status, body: Data(body.utf8))
  }

  func core(_ request: Data) async throws -> Data {
    check(!String(decoding: request, as: UTF8.self).contains(secret))
    let call = try JSONSerialization.jsonObject(with: request) as! [String: Any]
    let arguments = call["arguments"] as! [String: Any]
    let result: Any
    switch call["method"] as! String {
    case "applySignedSubscription":
      let envelope = try JSONSerialization.jsonObject(with: Data((arguments["envelope"] as! String).utf8)) as! [String: Any]
      let kind = envelope["kind"] as! String
      applied.append(kind)
      if kind == "bundle" { packageInstalled = true; revoked = false }
      if kind == "revoked" { packageInstalled = false; revoked = true }
      result = ["installed": packageInstalled, "revoked": revoked, "needsRefresh": kind == "state" && needsRefresh]
    case "projectSignedSubscription":
      check(arguments["summary"] as? Bool == true)
      if revoked {
        return try JSONSerialization.data(withJSONObject: ["error": ["code": "subscription_tombstone"]])
      }
      guard packageInstalled else {
        return try JSONSerialization.data(withJSONObject: ["error": ["code": "signed_subscription_required"]])
      }
      result = ["issuedAt": 1000, "expiresAt": 1300, "state": ["installed": true]]
    default: preconditionFailure("unexpected Core call")
    }
    return try JSONSerialization.data(withJSONObject: ["result": result])
  }
}

private actor Methods {
  var called: [String] = []
  func answer(_ request: Data) throws -> Data {
    let call = try JSONSerialization.jsonObject(with: request) as! [String: Any]
    let method = call["method"] as! String
    called.append(method)
    let context: [String: Any] = ["ownerSerial": 0, "instanceId": "instance", "accountId": "fixture-account",
      "accountGeneration": 1, "configurationGeneration": 1]
    let result: Any
    switch method {
    case "getClientBundleOwner": result = context
    case "beginClientBundleOwner":
      var owner = call["arguments"] as! [String: Any]
      owner["serial"] = 1
      result = owner
    case "installSignedClientBundle":
      let arguments = call["arguments"] as! [String: Any]
      check(arguments["deviceId"] as? String == device.deviceID && arguments["body"] == nil)
      result = ["installed": true]
    case "getRoutingLease":
      result = ["instanceId": "instance", "accountId": "fixture-account", "accountGeneration": 1,
        "configurationGeneration": 2, "bundleId": "lease", "configurationDigest": "d", "expiresAt": 1300_000]
    default: preconditionFailure("unexpected adapter call \(method)")
    }
    return try JSONSerialization.data(withJSONObject: ["result": result])
  }
}

private final class Uptime: @unchecked Sendable {
  private let lock = NSLock()
  private var value: TimeInterval = 0
  func now() -> TimeInterval { lock.lock(); defer { lock.unlock() }; return value }
  func advance(_ seconds: TimeInterval) { lock.lock(); value += seconds; lock.unlock() }
}

@main
private struct SignedSourceChecks {
  static func source(_ fixture: Fixture, _ uptime: Uptime) -> ClientBundleSignedSource {
    ClientBundleSignedSource(fetcher: fixture, call: { try await fixture.core($0) }, uptime: { uptime.now() })
  }

  static func lease(_ response: ClientBundleHTTPResponse) -> Int64? {
    guard response.status == 200,
      let root = try? JSONSerialization.jsonObject(with: response.body) as? [String: Any],
      let data = root["data"] as? [String: Any], data["connection"] == nil, data["outbounds"] == nil
    else { return nil }
    return (data["expires_at"] as? NSNumber)?.int64Value
  }

  static func main() async {
    check(!device.description.contains(secret))
    check(ClientBundleSignedDevice(deviceID: "short", installationID: secret) == nil)

    let fixture = Fixture(), uptime = Uptime()
    let signed = source(fixture, uptime)
    check(lease(try! await signed.fetch(authorization: authorization)) == 1300)
    for _ in 0..<4 {
      uptime.advance(60)
      check(lease(try! await signed.fetch(authorization: authorization)) == 1300)
    }
    var (requests, _) = await fixture.snapshot()
    check(requests == ["bundle"])
    uptime.advance(60)
    await fixture.set(needsRefresh: true)
    _ = try! await signed.fetch(authorization: authorization)
    (requests, _) = await fixture.snapshot()
    check(requests == ["bundle", "state", "bundle"])

    await fixture.set(status: 401)
    uptime.advance(300)
    check(lease(try! await signed.fetch(authorization: authorization)) == 1300)
    await fixture.set(offline: true)
    uptime.advance(300)
    check(lease(try! await signed.fetch(authorization: authorization)) == 1300)

    await fixture.set(kind: "revoked")
    let revocation = source(fixture, uptime)
    let forbidden = try! await revocation.fetch(authorization: authorization)
    check(forbidden.status == 403)
    check(String(decoding: forbidden.body, as: UTF8.self).contains("entitlement_unavailable"))

    let offline = Fixture()
    await offline.seed(installed: true)
    await offline.set(offline: true)
    check(lease(try! await source(offline, Uptime()).fetch(authorization: authorization)) == 1300)
    let empty = Fixture()
    await empty.set(offline: true)
    check((try? await source(empty, Uptime()).fetch(authorization: authorization)) == nil)
    let methods = Methods()
    let adapter = ClientBundleCoreAdapter(binding: binding, accountID: "fixture-account",
      signedDeviceID: device.deviceID, call: { try await methods.answer($0) })
    var machine = ClientBundleRenewalState()
    _ = machine.activate(binding, now: Date())
    let ticket = machine.beginRequest(now: Date(), credentials: .available).compactMap { intent in
      if case .requestBundle(let ticket) = intent { return ticket } else { return nil }
    }.first!
    check(try! await adapter.install(Data("{}".utf8), accountID: "fixture-account", ticket: ticket))
    check(await methods.called.contains("installSignedClientBundle"))
    check(!(await methods.called.contains("installClientBundle")))
    print("PASS signed renewal source: local lease renewal, 5-minute signed state, refresh on state, 401/offline retention, revocation as forbidden, no credentials in lease summary")
  }
}
