import Foundation

public enum ClientBundleTransportError: Error {
  case invalidConfiguration, unavailable, tooLarge, cancelled, redirected
}

public struct ClientBundleHTTPTransport: ClientBundleRenewalTransport {
  private let url: URL
  private let version: String
  private let platform: String
  private let distribution: String

  public init(origin: URL, coreVersion: String, platform: String, distribution: String) throws {
    guard origin.scheme == "https", origin.host != nil, origin.user == nil, origin.password == nil,
      origin.query == nil, origin.fragment == nil, ["", "/"].contains(origin.path),
      ["ios", "macos", "android", "windows", "linux"].contains(platform),
      ["direct", "apple-app-store"].contains(distribution), !coreVersion.isEmpty,
      coreVersion.utf8.count <= 128, !coreVersion.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 })
    else { throw ClientBundleTransportError.invalidConfiguration }
    self.url = origin.appendingPathComponent("api/v1/zolnit/client/bundle")
    self.version = coreVersion
    self.platform = platform
    self.distribution = distribution
  }

  public func fetch(authorization: ClientBundleAuthorization) async throws -> ClientBundleHTTPResponse {
    guard authorization.value.hasPrefix("Bearer "), authorization.value.utf8.count > 7,
      authorization.value.utf8.count <= 16 * 1024,
      !authorization.value.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 })
    else { throw ClientBundleTransportError.invalidConfiguration }
    var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 15)
    request.httpMethod = "GET"
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
    request.setValue(authorization.value, forHTTPHeaderField: "Authorization")
    request.setValue(version, forHTTPHeaderField: "X-ZolNit-Core-Version")
    request.setValue(platform, forHTTPHeaderField: "X-ZolNit-Platform")
    request.setValue(distribution, forHTTPHeaderField: "X-ZolNit-Distribution")
    let operation = ClientBundleHTTPRequest(request)
    return try await withTaskCancellationHandler {
      try Task.checkCancellation()
      return try await operation.run()
    } onCancel: { operation.cancel() }
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

  private static func retryAfter(_ value: String?) -> Date? {
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
