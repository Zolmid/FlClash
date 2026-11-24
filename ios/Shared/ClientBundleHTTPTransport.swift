import Foundation
import Darwin

public enum ClientBundleTransportError: Error {
  case invalidConfiguration, unavailable, tooLarge, cancelled, redirected
}

public struct ClientBundleHTTPTransport: ClientBundleRenewalTransport {
  private let url: URL
  private let stateURL: URL
  private let version: String
  private let platform: String
  private let distribution: String
  private let coreCall: ClientBundleCoreAdapter.Call?
  private let coreResponseDirectory: URL?

  public init(origin: URL, coreVersion: String, platform: String, distribution: String,
    coreCall: ClientBundleCoreAdapter.Call? = nil, coreResponseDirectory: URL? = nil) throws {
    guard origin.scheme == "https", origin.host != nil, origin.user == nil, origin.password == nil,
      origin.query == nil, origin.fragment == nil, ["", "/"].contains(origin.path),
      ["ios", "macos", "android", "windows", "linux"].contains(platform),
      ["direct", "apple-app-store"].contains(distribution), !coreVersion.isEmpty,
      coreVersion.utf8.count <= 128, !coreVersion.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 })
    else { throw ClientBundleTransportError.invalidConfiguration }
    self.url = origin.appendingPathComponent("api/v1/zolnit/client/bundle")
    self.stateURL = origin.appendingPathComponent("api/v1/zolnit/client/subscription/state")
    self.version = coreVersion
    self.platform = platform
    self.distribution = distribution
    self.coreCall = coreCall
    self.coreResponseDirectory = coreResponseDirectory
  }

  public func fetch(authorization: ClientBundleAuthorization) async throws -> ClientBundleHTTPResponse {
    try await exchange(url, authorization: authorization, headers: [:])
  }

  /// Signed state and bundle requests prove the installation in headers.
  public func fetchSigned(
    authorization: ClientBundleAuthorization, device: ClientBundleSignedDevice, state: Bool
  ) async throws -> ClientBundleHTTPResponse {
    var headers = ["X-ZolNit-Device-Id": device.deviceID, "X-ZolNit-Installation": device.installationID]
    if !state { headers["X-ZolNit-Subscription-Format"] = "signed-v2" }
    return try await exchange(state ? stateURL : url, authorization: authorization, headers: headers)
  }

  private func exchange(
    _ url: URL, authorization: ClientBundleAuthorization, headers: [String: String]
  ) async throws -> ClientBundleHTTPResponse {
    let request = try makeRequest(url, authorization: authorization, headers: headers)
    if let coreCall, let response = try await ownedExchange(request, call: coreCall) { return response }
    let operation = ClientBundleHTTPRequest(request)
    return try await withTaskCancellationHandler {
      try Task.checkCancellation()
      return try await operation.run()
    } onCancel: { operation.cancel() }
  }

  private func ownedExchange(_ request: URLRequest, call: @escaping ClientBundleCoreAdapter.Call) async throws -> ClientBundleHTTPResponse? {
    let id = UUID().uuidString
    let requestHeaders = (request.allHTTPHeaderFields ?? [:]).filter { $0.key.lowercased() != "cache-control" }
    let arguments: [String: Any] = ["client-id": "ios-owned-dns", "request-id": id,
      "owned-dns-only": true, "method": "GET", "url": request.url!.absoluteString,
      "headers": requestHeaders, "body": "", "timeout": 15000]
    let message = try JSONSerialization.data(withJSONObject: ["id": id, "method": "firstPartyHTTP", "arguments": arguments])
    let response = try await withTaskCancellationHandler {
      try Task.checkCancellation()
      return try await call(message)
    } onCancel: {
      Task {
        let cancel: [String: Any] = ["id": UUID().uuidString, "method": "cancelFirstPartyHTTP",
          "arguments": ["client-id": "ios-owned-dns", "request-id": id]]
        if let data = try? JSONSerialization.data(withJSONObject: cancel) { _ = try? await call(data) }
      }
    }
    let value = try ownedEnvelope(response, id: id)
    if let error = value["error"] as? [String: Any] {
      if error["code"] as? String == "owned_dns_disabled" { return nil }
      throw ClientBundleTransportError.unavailable
    }
    guard let result = value["result"] as? [String: Any], let status = result["status"] as? Int,
      let encoded = result["body"] as? String, encoded.utf8.count <= 12 * 1024 * 1024,
      let body = Data(base64Encoded: encoded), body.count <= 8 * 1024 * 1024,
      String(data: body, encoding: .utf8) != nil else { throw ClientBundleTransportError.unavailable }
    guard (100...599).contains(status) else { throw ClientBundleTransportError.unavailable }
    let responseHeaders = result["headers"] as? [String: String]
    return ClientBundleHTTPResponse(status: status, body: body,
      retryAfter: ClientBundleHTTPRequest.retryAfter(responseHeaders?["Retry-After"]))
  }

  private static let maximumEnvelopeBytes = 12 * 1024 * 1024 + 64 * 1024

  private func ownedEnvelope(_ data: Data, id: String) throws -> [String: Any] {
    func decode(_ data: Data) throws -> [String: Any] {
      guard data.count <= Self.maximumEnvelopeBytes,
        let value = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        value["id"] as? String == id
      else { throw ClientBundleTransportError.unavailable }
      return value
    }
    func present(_ value: Any?) -> Bool { value != nil && !(value is NSNull) }
    var value = try decode(data)
    if present(value["file"]) {
      guard let path = value["file"] as? String else { throw ClientBundleTransportError.unavailable }
      let spilled = try readOwnedResponse(path)
      guard !present(value["result"]), !present(value["error"]) else {
        throw ClientBundleTransportError.unavailable
      }
      value = try decode(spilled)
      guard !present(value["file"]) else { throw ClientBundleTransportError.unavailable }
    }
    guard present(value["result"]) != present(value["error"]),
      !present(value["error"]) || value["error"] is [String: Any]
    else { throw ClientBundleTransportError.unavailable }
    return value
  }

  private func readOwnedResponse(_ path: String) throws -> Data {
    guard let directory = coreResponseDirectory, directory.isFileURL,
      !path.utf8.contains(0), path.hasPrefix("/")
    else { throw ClientBundleTransportError.unavailable }
    let file = URL(fileURLWithPath: path)
    let name = file.lastPathComponent
    let parent = file.deletingLastPathComponent().path
    let trusted = directory.standardizedFileURL
    let canonical = trusted.resolvingSymlinksInPath()
    guard path == file.standardizedFileURL.path,
      parent == trusted.path || parent == canonical.path,
      name.hasPrefix("http-"), name.hasSuffix(".json"),
      !name.dropFirst(5).dropLast(5).isEmpty,
      name.dropFirst(5).dropLast(5).utf8.allSatisfy({ (48...57).contains($0) }),
      trusted.lastPathComponent == "responses-ne"
    else { throw ClientBundleTransportError.unavailable }
    let root = open(trusted.deletingLastPathComponent().resolvingSymlinksInPath().path,
      O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
    guard root >= 0 else { throw ClientBundleTransportError.unavailable }
    defer { close(root) }
    let folder = openat(root, "responses-ne", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
    guard folder >= 0 else { throw ClientBundleTransportError.unavailable }
    defer { close(folder) }
    let descriptor = openat(folder, name, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
    guard descriptor >= 0 else { throw ClientBundleTransportError.unavailable }
    defer { close(descriptor) }
    var info = stat()
    guard fstat(descriptor, &info) == 0, (info.st_mode & S_IFMT) == S_IFREG,
      info.st_uid == geteuid(), info.st_nlink == 1, info.st_mode & 0o022 == 0
    else { throw ClientBundleTransportError.unavailable }
    defer {
      var current = stat()
      if fstatat(folder, name, &current, AT_SYMLINK_NOFOLLOW) == 0,
        current.st_dev == info.st_dev, current.st_ino == info.st_ino {
        _ = unlinkat(folder, name, 0)
      }
    }
    guard info.st_size > 0, info.st_size <= Self.maximumEnvelopeBytes else {
      throw ClientBundleTransportError.unavailable
    }
    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 64 * 1024)
    while true {
      let count = read(descriptor, &buffer, min(buffer.count, Self.maximumEnvelopeBytes + 1 - data.count))
      if count < 0 && errno == EINTR { continue }
      guard count >= 0 else { throw ClientBundleTransportError.unavailable }
      if count == 0 { break }
      data.append(contentsOf: buffer.prefix(count))
      guard data.count <= Self.maximumEnvelopeBytes else { throw ClientBundleTransportError.unavailable }
    }
    guard data.count == info.st_size else { throw ClientBundleTransportError.unavailable }
    return data
  }

  func makeRequest(
    _ url: URL, authorization: ClientBundleAuthorization, headers: [String: String]
  ) throws -> URLRequest {
    guard authorization.value.hasPrefix("Bearer "), authorization.value.utf8.count > 7,
      authorization.value.utf8.count <= 16 * 1024,
      !authorization.value.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 })
    else { throw ClientBundleTransportError.invalidConfiguration }
    var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 15)
    request.httpMethod = "GET"
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    request.setValue("ZolNit/v\(appVersion) clash-verge Platform/\(platform)", forHTTPHeaderField: "User-Agent")
    request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
    request.setValue(authorization.value, forHTTPHeaderField: "Authorization")
    request.setValue(version, forHTTPHeaderField: "X-ZolNit-Core-Version")
    request.setValue(platform, forHTTPHeaderField: "X-ZolNit-Platform")
    request.setValue(distribution, forHTTPHeaderField: "X-ZolNit-Distribution")
    for (name, value) in headers { request.setValue(value, forHTTPHeaderField: name) }
    return request
  }
}

public protocol ClientBundleSignedFetcher: Sendable {
  func fetchSigned(
    authorization: ClientBundleAuthorization, device: ClientBundleSignedDevice, state: Bool
  ) async throws -> ClientBundleHTTPResponse
}

extension ClientBundleHTTPTransport: ClientBundleSignedFetcher {}

/// Renewal source for a signed installation. The network is used only for the
/// small signed state, or for a bundle that state reports as newer; each lease
/// is then scheduled from the Core's durable package. Failed or unsigned
/// responses leave that package in place, and a signed revocation or expiry
/// reaches the owner as the forbidden result it already drains on.
public actor ClientBundleSignedSource: ClientBundleRenewalTransport {
  public typealias Call = @Sendable (Data) async throws -> Data
  public static let stateInterval: TimeInterval = 300

  private struct Request<Arguments: Encodable>: Encodable {
    let id: String
    let method: String
    let arguments: Arguments
  }
  private struct Binding: Encodable {
    let accountId: String
    let deviceId: String
    let envelope: String?
    let summary: Bool?
  }
  private struct State: Decodable {
    let installed: Bool?
    let revoked: Bool?
    let needsRefresh: Bool?
  }
  private struct Summary: Decodable {
    let issuedAt: Int64
    let expiresAt: Int64
  }
  private struct Failure: Decodable { let code: String }
  private struct Response<Value: Decodable>: Decodable {
    let result: Value?
    let error: Failure?
    let file: String?
  }
  private enum CoreFailure: Error { case code(String), unavailable }

  private let fetcher: any ClientBundleSignedFetcher
  private let call: Call
  private let uptime: @Sendable () -> TimeInterval
  private var checkedAt: TimeInterval?
  private var installed = false
  private var bundleWanted = false
  private var sequence: UInt64 = 0

  public init(
    fetcher: any ClientBundleSignedFetcher, call: @escaping Call,
    uptime: @escaping @Sendable () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
  ) {
    self.fetcher = fetcher
    self.call = call
    self.uptime = uptime
  }

  public func fetch(authorization: ClientBundleAuthorization) async throws -> ClientBundleHTTPResponse {
    guard let device = authorization.device else { throw ClientBundleTransportError.invalidConfiguration }
    let due = !installed || bundleWanted || checkedAt.map { uptime() - $0 >= Self.stateInterval } ?? true
    if due {
      var state = installed && !bundleWanted
      for _ in 0..<2 {
        guard let response = try? await fetcher.fetchSigned(authorization: authorization, device: device, state: state),
          response.status == 200, let applied = try? await apply(response.body, authorization, device)
        else { break }
        checkedAt = uptime()
        bundleWanted = applied.needsRefresh == true && applied.revoked != true
        guard bundleWanted, state else { break }
        state = false
      }
    }
    do {
      let summary: Summary = try await invoke("projectSignedSubscription", Binding(
        accountId: authorization.accountID, deviceId: device.deviceID, envelope: nil, summary: true))
      installed = true
      return .init(status: 200, body: try JSONSerialization.data(withJSONObject: ["data": [
        "schema_version": 1, "account_id": authorization.accountID,
        "issued_at": summary.issuedAt, "expires_at": summary.expiresAt,
      ]]))
    } catch CoreFailure.code(let code) where ["subscription_tombstone", "subscription_expired"].contains(code) {
      installed = false
      return .init(status: 403, body: Data(#"{"error":{"code":"entitlement_unavailable"}}"#.utf8))
    } catch {
      installed = false
      bundleWanted = true
      throw ClientBundleTransportError.unavailable
    }
  }

  private func apply(
    _ body: Data, _ authorization: ClientBundleAuthorization, _ device: ClientBundleSignedDevice
  ) async throws -> State {
    guard let root = try JSONSerialization.jsonObject(with: body) as? [String: Any],
      let data = root["data"] as? [String: Any]
    else { throw CoreFailure.unavailable }
    let envelope = String(decoding: try JSONSerialization.data(withJSONObject: data), as: UTF8.self)
    return try await invoke("applySignedSubscription", Binding(
      accountId: authorization.accountID, deviceId: device.deviceID, envelope: envelope, summary: nil))
  }

  private func invoke<Value: Decodable>(_ method: String, _ arguments: Binding) async throws -> Value {
    sequence += 1
    let request = try JSONEncoder().encode(Request(id: "signed-\(sequence)", method: method, arguments: arguments))
    let data = try await call(request)
    guard data.count <= 512 * 1024, let response = try? JSONDecoder().decode(Response<Value>.self, from: data),
      response.file == nil
    else { throw CoreFailure.unavailable }
    if let failure = response.error { throw CoreFailure.code(failure.code) }
    guard let result = response.result else { throw CoreFailure.unavailable }
    return result
  }
}

private final class ClientBundleHTTPRequest: NSObject, URLSessionDataDelegate, @unchecked Sendable {
  private let lock = NSLock()
  private let request: URLRequest
  private var continuation: CheckedContinuation<ClientBundleHTTPResponse, Error>?
  private var session: URLSession?
  private var task: URLSessionDataTask?
  private var response: HTTPURLResponse?
  private var body = Data()
  private var finished = false
  private let maximumBytes = 8 * 1024 * 1024

  init(_ request: URLRequest) { self.request = request }

  func run() async throws -> ClientBundleHTTPResponse {
    try await withCheckedThrowingContinuation { continuation in
      lock.lock()
      guard !finished else {
        lock.unlock()
        continuation.resume(throwing: ClientBundleTransportError.cancelled)
        return
      }
      self.continuation = continuation
      let configuration = URLSessionConfiguration.ephemeral
      configuration.urlCache = nil
      configuration.httpCookieStorage = nil
      configuration.httpShouldSetCookies = false
      configuration.urlCredentialStorage = nil
      configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
      configuration.timeoutIntervalForResource = 20
      configuration.waitsForConnectivity = false
      let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
      self.session = session
      let task = session.dataTask(with: request)
      self.task = task
      lock.unlock()
      task.resume()
    }
  }

  func cancel() { finish(.failure(ClientBundleTransportError.cancelled)) }

  func urlSession(
    _ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void
  ) {
    completionHandler(nil)
    finish(.failure(ClientBundleTransportError.redirected))
  }

  func urlSession(
    _ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
  ) {
    guard let response = response as? HTTPURLResponse,
      response.expectedContentLength <= maximumBytes
    else {
      completionHandler(.cancel)
      finish(.failure(ClientBundleTransportError.tooLarge))
      return
    }
    lock.lock()
    self.response = response
    lock.unlock()
    completionHandler(.allow)
  }

  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
    lock.lock()
    let tooLarge = body.count + data.count > maximumBytes
    if !tooLarge && !finished { body.append(data) }
    lock.unlock()
    if tooLarge { finish(.failure(ClientBundleTransportError.tooLarge)) }
  }

  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    lock.lock()
    let response = response
    let body = body
    lock.unlock()
    guard error == nil, let response else {
      finish(.failure(ClientBundleTransportError.unavailable))
      return
    }
    finish(.success(.init(status: response.statusCode, body: body,
      retryAfter: Self.retryAfter(response.value(forHTTPHeaderField: "Retry-After")))))
  }

  private func finish(_ result: Result<ClientBundleHTTPResponse, Error>) {
    lock.lock()
    guard !finished else { lock.unlock(); return }
    finished = true
    let continuation = continuation
    let session = session
    self.continuation = nil
    self.session = nil
    self.task = nil
    body.removeAll(keepingCapacity: false)
    lock.unlock()
    session?.invalidateAndCancel()
    continuation?.resume(with: result)
  }

  fileprivate static func retryAfter(_ value: String?) -> Date? {
    guard let value else { return nil }
    let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if !text.isEmpty, text.utf8.allSatisfy({ (48...57).contains($0) }),
      let seconds = TimeInterval(text), seconds.isFinite
    { return Date().addingTimeInterval(seconds) }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
    return formatter.date(from: text)
  }
}
