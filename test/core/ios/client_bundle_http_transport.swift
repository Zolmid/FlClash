import Foundation
import Darwin

private actor SpilledRenewalFixture {
  let directory: URL
  var requests = 0
  var applied = false
  var installed = false
  let payload = String(repeating: "signed-fixture-", count: 160)

  init(_ directory: URL) { self.directory = directory }

  func answer(_ request: Data) throws -> Data {
    let call = try JSONSerialization.jsonObject(with: request) as! [String: Any]
    let arguments = call["arguments"] as? [String: Any] ?? [:]
    let result: [String: Any]
    switch call["method"] as! String {
    case "firstPartyHTTP":
      requests += 1
      let headers = arguments["headers"] as! [String: String]
      precondition(headers["Authorization"] == "Bearer SYNTHETIC_ONLY")
      precondition(headers["X-ZolNit-Subscription-Format"] == "signed-v2")
      precondition(headers["X-ZolNit-Device-Id"] != nil && headers["X-ZolNit-Installation"] != nil)
      let body = try JSONSerialization.data(withJSONObject: ["data": ["signed": payload]])
      var envelope = try JSONSerialization.data(withJSONObject: ["id": call["id"]!,
        "result": ["status": 200, "body": body.base64EncodedString()]])
      precondition(envelope.count > 2048 && envelope.count <= 4096)
      envelope.append(Data(repeating: 32, count: 4096 - envelope.count))
      let file = directory.appendingPathComponent("http-12345.json")
      try envelope.write(to: file)
      return try JSONSerialization.data(withJSONObject: ["id": call["id"]!, "file": file.path])
    case "applySignedSubscription":
      let envelope = try JSONSerialization.jsonObject(with: Data((arguments["envelope"] as! String).utf8)) as! [String: Any]
      precondition(envelope["signed"] as? String == payload)
      precondition(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("http-12345.json").path))
      applied = true
      result = ["installed": true]
    case "projectSignedSubscription":
      precondition(applied)
      result = ["issuedAt": 1000, "expiresAt": 1300]
    case "getClientBundleOwner":
      result = ["ownerSerial": 0, "instanceId": "fixture", "accountId": "fixture",
        "accountGeneration": 1, "configurationGeneration": 1]
    case "beginClientBundleOwner":
      var owner = arguments
      owner["serial"] = 1
      result = owner
    case "installSignedClientBundle":
      precondition(applied && arguments["body"] == nil && arguments["deviceId"] != nil)
      installed = true
      result = ["installed": true]
    case "getRoutingLease":
      result = ["instanceId": "fixture", "accountId": "fixture", "accountGeneration": 1,
        "configurationGeneration": 2, "bundleId": "lease", "configurationDigest": "digest", "expiresAt": 1300000]
    default: preconditionFailure("unexpected method")
    }
    return try JSONSerialization.data(withJSONObject: ["id": call["id"] ?? "", "result": result])
  }

  func verify() { precondition(requests == 1 && applied && installed) }
}

@main enum ClientBundleHTTPTransportCheck {
  static func main() async throws {
    let transport = try ClientBundleHTTPTransport(
      origin: URL(string: "https://link.zolmid.com")!, coreVersion: "fixture",
      platform: "ios", distribution: "direct")
    let binding = ClientBundleRenewalState.Binding(session: .init(1), owner: .init(1))
    let authorization = ClientBundleAuthorization(
      accountID: "fixture", binding: binding, value: "Bearer SYNTHETIC_ONLY")
    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    for path in ["bundle", "subscription/state"] {
      let request = try transport.makeRequest(
        URL(string: "https://link.zolmid.com/api/v1/zolnit/client/\(path)")!,
        authorization: authorization, headers: [:])
      precondition(request.value(forHTTPHeaderField: "User-Agent") == "ZolNit/v\(version) clash-verge Platform/ios")
    }
    let owned = try ClientBundleHTTPTransport(origin: URL(string: "https://link.zolmid.com")!,
      coreVersion: "fixture", platform: "ios", distribution: "direct", coreCall: { data in
        let value = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        precondition(value["method"] as? String == "firstPartyHTTP")
        let arguments = value["arguments"] as! [String: Any]
        precondition(arguments["owned-dns-only"] as? Bool == true)
        precondition((arguments["headers"] as! [String: String])["Authorization"] == "Bearer SYNTHETIC_ONLY")
        return try JSONSerialization.data(withJSONObject: ["id": value["id"]!,
          "result": ["status": 200, "body": Data("fixture".utf8).base64EncodedString(), "headers": [:]]])
      })
    let response = try await owned.fetch(authorization: authorization)
    precondition(response.status == 200 && response.body == Data("fixture".utf8))
    let failing = try ClientBundleHTTPTransport(origin: URL(string: "https://link.zolmid.com")!,
      coreVersion: "fixture", platform: "ios", distribution: "direct", coreCall: { data in
        let value = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        return try JSONSerialization.data(withJSONObject: ["id": value["id"]!, "error": ["code": "network"]])
      })
    do { _ = try await failing.fetch(authorization: authorization); preconditionFailure("strict request fell back") }
    catch ClientBundleTransportError.unavailable {}

    try await spilledChecks(authorization)
    print("PASS owned HTTP inline/auth, spilled signed renewal through installer, bounded reads, rejection and cleanup")
  }

  static func spilledChecks(_ authorization: ClientBundleAuthorization) async throws {
    let manager = FileManager.default
    let root = manager.temporaryDirectory.appendingPathComponent("ios-renewal-\(UUID().uuidString)").resolvingSymlinksInPath()
    let directory = root.appendingPathComponent("responses-ne")
    try manager.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? manager.removeItem(at: root) }
    let fixture = SpilledRenewalFixture(directory)
    let device = ClientBundleSignedDevice(deviceID: "0123456789abcdef0123456789abcdef",
      installationID: "aW5zdGFsbGF0aW9uLXNlY3JldC1maXh0dXJlLTMyYnk")!
    let signedAuthorization = ClientBundleAuthorization(accountID: "fixture", binding: authorization.binding,
      value: authorization.value, device: device)
    let transport = try ClientBundleHTTPTransport(origin: URL(string: "https://link.zolmid.com")!,
      coreVersion: "fixture", platform: "ios", distribution: "direct",
      coreCall: { try await fixture.answer($0) }, coreResponseDirectory: directory)
    let source = ClientBundleSignedSource(fetcher: transport, call: { try await fixture.answer($0) })
    let response = try await source.fetch(authorization: signedAuthorization)
    let adapter = ClientBundleCoreAdapter(binding: authorization.binding, accountID: "fixture",
      signedDeviceID: device.deviceID, call: { try await fixture.answer($0) })
    var machine = ClientBundleRenewalState()
    _ = machine.activate(authorization.binding, now: Date())
    let ticket = machine.beginRequest(now: Date(), credentials: .available).compactMap { intent in
      if case .requestBundle(let ticket) = intent { return ticket }; return nil
    }.first!
    let installed = try await adapter.install(response.body, accountID: "fixture", ticket: ticket)
    precondition(installed)
    await fixture.verify()
    let remaining = try manager.contentsOfDirectory(atPath: directory.path)
    precondition(remaining.isEmpty)

    let cases = ["malformed", "inner-id", "nested", "error", "outer-mixed", "inner-mixed", "bad-body",
      "bad-utf8", "large-body", "large-file", "empty", "status", "outer-id", "foreign", "app-role",
      "cache-role", "traversal", "symlink", "hardlink", "fifo", "directory", "directory-link", "no-trust"]
    for kind in cases {
      let home = root.appendingPathComponent(kind)
      let trusted = home.appendingPathComponent("responses-ne")
      try manager.createDirectory(at: trusted, withIntermediateDirectories: true)
      let target = home.appendingPathComponent("target.json")
      try Data("untouched".utf8).write(to: target)
      let regular = trusted.appendingPathComponent("http-123.json")
      let rejectedReference = ["outer-id", "traversal", "symlink",
        "hardlink", "fifo", "directory", "directory-link", "no-trust"].contains(kind)
      let checkTransport = try ClientBundleHTTPTransport(origin: URL(string: "https://link.zolmid.com")!,
        coreVersion: "fixture", platform: "ios", distribution: "direct", coreCall: { request in
          let manager = FileManager.default
          let call = try JSONSerialization.jsonObject(with: request) as! [String: Any]
          let id = call["id"] as! String
          var inner: [String: Any] = ["id": kind == "inner-id" ? "wrong" : id,
            "result": ["status": kind == "status" ? 999 : 200,
              "body": kind == "bad-body" ? "!" : Data(kind == "bad-utf8" ? [255] : [65]).base64EncodedString()]]
          if kind == "nested" { inner = ["id": id, "file": target.path] }
          if kind == "error" { inner = ["id": id, "error": ["code": "network"]] }
          if kind == "inner-mixed" { inner["error"] = ["code": "network"] }
          if kind == "large-body" {
            inner["result"] = ["status": 200, "body": Data(repeating: 65, count: 8 * 1024 * 1024 + 1).base64EncodedString()]
          }
          var bytes = try JSONSerialization.data(withJSONObject: inner)
          if kind == "malformed" { bytes = Data("{".utf8) }
          if kind == "empty" { bytes = Data() }
          if kind == "large-file" { bytes = Data(repeating: 65, count: 12 * 1024 * 1024 + 65537) }
          var path = regular.path
          switch kind {
          case "foreign": path = target.path
          case "app-role", "cache-role":
            let sibling = home.appendingPathComponent(kind == "app-role" ? "responses-app" : ".ios-cache/ne/responses-ne")
            try manager.createDirectory(at: sibling, withIntermediateDirectories: true)
            path = sibling.appendingPathComponent("http-123.json").path
            try bytes.write(to: URL(fileURLWithPath: path))
          case "traversal":
            try bytes.write(to: regular)
            path = trusted.path + "/../responses-ne/http-123.json"
          case "symlink": try manager.createSymbolicLink(at: regular, withDestinationURL: target)
          case "hardlink": try manager.linkItem(at: target, to: regular)
          case "fifo": precondition(mkfifo(regular.path, 0o600) == 0)
          case "directory": try manager.createDirectory(at: regular, withIntermediateDirectories: false)
          case "directory-link":
            try manager.removeItem(at: trusted)
            try manager.createSymbolicLink(at: trusted, withDestinationURL: home)
            try bytes.write(to: home.appendingPathComponent("http-123.json"))
          default: try bytes.write(to: regular)
          }
          var outer: [String: Any] = ["id": kind == "outer-id" ? "wrong" : id, "file": path]
          if kind == "outer-mixed" { outer["error"] = ["code": "network"] }
          return try JSONSerialization.data(withJSONObject: outer)
        }, coreResponseDirectory: kind == "no-trust" ? nil : trusted)
      do {
        _ = try await checkTransport.fetch(authorization: authorization)
        preconditionFailure("accepted \(kind)")
      } catch ClientBundleTransportError.unavailable {}
      let preserved = try Data(contentsOf: target)
      precondition(preserved == Data("untouched".utf8))
      precondition(manager.fileExists(atPath: regular.path) == rejectedReference, "cleanup \(kind)")
    }
  }
}
