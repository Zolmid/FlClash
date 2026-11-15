import Darwin
import Foundation

public enum TunnelIntentError: Error {
  case unavailable, busy, superseded, unsafe, expired
}

@MainActor
public final class PendingTunnelIntent {
  public private(set) var token: TunnelIntentAuthority.Token?

  public init() {}

  public func register(_ operation: () throws -> TunnelIntentAuthority.Token) rethrows {
    let accepted = try operation()
    token = accepted
  }

  public func remove(_ expected: TunnelIntentAuthority.Token) {
    if token == expected { token = nil }
  }
}

public final class TunnelIntentAuthority: @unchecked Sendable {
  public enum Command { case start, stop, toggle }
  public struct Token: Codable, Equatable, Sendable {
    public let id: UUID
  }

  private struct Record: Codable {
    var version = 2
    var token: Token
    var target: Bool?
    var inverted: Bool
    var pending = true
  }

  private struct RegistrationBaseline { let token: Token? }
  @MainActor private static var registrationAttempts: [String: UUID] = [:]
  private static let ownersLock = NSLock()
  private static var owners: [UUID: Int32] = [:]
  private let directory: @Sendable () throws -> URL

  public init(directory: URL) {
    self.directory = { directory }
  }

  public init(appGroup: String) {
    directory = {
      guard let container = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: appGroup
      ) else { throw TunnelIntentError.unavailable }
      return container.appendingPathComponent("tunnel-intents-v1", isDirectory: true)
    }
  }

  @MainActor
  public func registerWithRetry(_ command: Command) async throws -> Token {
    let folder = try directory()
    guard folder.isFileURL else { throw TunnelIntentError.unavailable }
    let key = folder.standardizedFileURL.path
    let attempt = UUID()
    Self.registrationAttempts[key] = attempt
    defer {
      if Self.registrationAttempts[key] == attempt { Self.registrationAttempts.removeValue(forKey: key) }
    }
    let baseline = RegistrationBaseline(token: try readRecord(folder.appendingPathComponent("intent.json"))?.token)
    for retry in 0...20 {
      try Task.checkCancellation()
      guard Self.registrationAttempts[key] == attempt else { throw TunnelIntentError.superseded }
      do { return try register(command, baseline: retry == 0 ? nil : baseline) }
      catch TunnelIntentError.busy {
        guard retry < 20 else { throw TunnelIntentError.busy }
        try await Task.sleep(nanoseconds: 50_000_000)
      }
    }
    throw TunnelIntentError.busy
  }

  public func register(_ command: Command) throws -> Token {
    try register(command, baseline: nil)
  }

  private func register(_ command: Command, baseline: RegistrationBaseline?) throws -> Token {
    try locked { record, file in
      if let baseline, record?.token != baseline.token { throw TunnelIntentError.superseded }
      var previous: Record?
      if let record, record.pending, try alive(record, in: file.deletingLastPathComponent()) {
        previous = record
      }
      let target: Bool?
      let inverted: Bool
      switch command {
      case .start: target = true; inverted = false
      case .stop: target = false; inverted = false
      case .toggle:
        target = previous?.target.map { !$0 }
        inverted = target == nil ? !(previous?.inverted ?? false) : false
      }
      let next = Record(token: Token(id: UUID()), target: target, inverted: inverted)
      let ownerURL = ownerFile(next.token, in: file.deletingLastPathComponent())
      let descriptor = open(ownerURL.path, O_CREAT | O_EXCL | O_RDWR | O_CLOEXEC | O_NOFOLLOW, 0o600)
      guard descriptor >= 0 else { throw TunnelIntentError.unavailable }
      guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
        close(descriptor)
        try? FileManager.default.removeItem(at: ownerURL)
        throw TunnelIntentError.unavailable
      }
      do {
        try write(next, to: file)
      } catch {
        close(descriptor)
        try? FileManager.default.removeItem(at: ownerURL)
        throw error
      }
      Self.ownersLock.lock()
      Self.owners[next.token.id] = descriptor
      Self.ownersLock.unlock()
      if let record {
        release(record.token)
        try? FileManager.default.removeItem(at: ownerFile(record.token, in: file.deletingLastPathComponent()))
      }
      return next.token
    }
  }

  public func resolve(_ token: Token, observedRunning: Bool) throws -> Bool {
    try locked { record, file in
      var current = try require(token, record, in: file.deletingLastPathComponent())
      if current.target == nil {
        current.target = observedRunning != current.inverted
        try write(current, to: file)
      }
      return current.target!
    }
  }

  public func isCurrent(_ token: Token) throws -> Bool {
    try locked { record, file in
      guard let record, record.token == token, record.pending else {
        release(token)
        return false
      }
      return try alive(record, in: file.deletingLastPathComponent())
    }
  }

  public func isLatest(_ token: Token) throws -> Bool {
    try locked { record, file in
      guard let record, record.token == token else { return false }
      if !record.pending { return true }
      return try alive(record, in: file.deletingLastPathComponent())
    }
  }

  public func perform<T>(_ token: Token, running: Bool, _ effect: () throws -> T) throws -> T {
    try locked { record, file in
      let folder = file.deletingLastPathComponent()
      let current = try require(token, record, in: folder)
      guard current.target == running else { throw TunnelIntentError.superseded }
      try write(current, to: file)
      guard try alive(current, in: folder) else { throw TunnelIntentError.expired }
      return try effect()
    }
  }

  public func finish(_ token: Token) throws {
    do {
      try locked { record, file in
        guard var current = record, current.token == token else { return }
        current.pending = false
        try write(current, to: file)
        try? FileManager.default.removeItem(at: ownerFile(token, in: file.deletingLastPathComponent()))
      }
    } catch TunnelIntentError.busy {
      throw TunnelIntentError.busy
    } catch {
      release(token)
      throw error
    }
    release(token)
  }

  public func cancel(_ token: Token) { release(token) }

  private func ownerFile(_ token: Token, in folder: URL) -> URL {
    folder.appendingPathComponent("owner-\(token.id.uuidString)")
  }

  private func release(_ token: Token) {
    Self.ownersLock.lock()
    let descriptor = Self.owners.removeValue(forKey: token.id)
    Self.ownersLock.unlock()
    if let descriptor { close(descriptor) }
  }

  private func alive(_ record: Record, in folder: URL) throws -> Bool {
    guard record.version == 2 else { return false }
    Self.ownersLock.lock()
    let owned = Self.owners[record.token.id] != nil
    Self.ownersLock.unlock()
    if owned { return true }
    let descriptor = open(ownerFile(record.token, in: folder).path, O_RDWR | O_CLOEXEC | O_NOFOLLOW)
    if descriptor < 0 {
      if errno == ENOENT { return false }
      throw TunnelIntentError.unavailable
    }
    defer { close(descriptor) }
    if flock(descriptor, LOCK_EX | LOCK_NB) == 0 {
      flock(descriptor, LOCK_UN)
      return false
    }
    if errno == EWOULDBLOCK || errno == EAGAIN { return true }
    throw TunnelIntentError.unavailable
  }

  private func require(_ token: Token, _ record: Record?, in folder: URL) throws -> Record {
    guard let record, record.token == token, record.pending else {
      throw TunnelIntentError.superseded
    }
    guard try alive(record, in: folder) else { throw TunnelIntentError.expired }
    return record
  }

  private func write(_ record: Record, to file: URL) throws {
    let data = try JSONEncoder().encode(record)
    try data.write(to: file, options: [.atomic])
  }

  private func locked<T>(_ operation: (Record?, URL) throws -> T) throws -> T {
    let folder = try directory()
    guard folder.isFileURL else { throw TunnelIntentError.unavailable }
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true,
      attributes: [.posixPermissions: 0o700])
    let lock = folder.appendingPathComponent("intent.lock")
    let descriptor = open(lock.path, O_CREAT | O_RDWR | O_CLOEXEC | O_NOFOLLOW, 0o600)
    guard descriptor >= 0 else { throw TunnelIntentError.unavailable }
    defer { close(descriptor) }
    guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else { throw TunnelIntentError.busy }
    defer { flock(descriptor, LOCK_UN) }
    let file = folder.appendingPathComponent("intent.json")
    return try operation(readRecord(file), file)
  }

  private func readRecord(_ file: URL) throws -> Record? {
    let input = open(file.path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
    var record: Record?
    if input >= 0 {
      let handle = FileHandle(fileDescriptor: input, closeOnDealloc: true)
      guard let data = try handle.read(upToCount: 4097), data.count <= 4096,
        let decoded = try? JSONDecoder().decode(Record.self, from: data),
        decoded.version == 1 || decoded.version == 2
      else { throw TunnelIntentError.unavailable }
      record = decoded
    } else if errno != ENOENT {
      throw TunnelIntentError.unavailable
    }
    return record
  }
}
