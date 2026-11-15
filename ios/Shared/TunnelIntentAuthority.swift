import Darwin
import Foundation

public enum TunnelIntentError: Error {
  case unavailable, busy, superseded, unsafe, expired
}

public final class TunnelIntentAuthority: @unchecked Sendable {
  public enum Command { case start, stop, toggle }
  public struct Token: Codable, Equatable, Sendable {
    public let id: UUID
  }

  private struct Record: Codable {
    var version = 1
    var token: Token
    var target: Bool?
    var inverted: Bool
    var pending = true
    var created: Date
    var expires: Date
  }

  private let directory: @Sendable () throws -> URL
  private let clock: @Sendable () -> Date
  private let lifetime: TimeInterval

  public init(
    directory: URL, lifetime: TimeInterval = 30,
    clock: @escaping @Sendable () -> Date = { Date() }
  ) {
    self.directory = { directory }
    self.lifetime = min(30, max(0.001, lifetime))
    self.clock = clock
  }

  public init(appGroup: String) {
    directory = {
      guard let container = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: appGroup
      ) else { throw TunnelIntentError.unavailable }
      return container.appendingPathComponent("tunnel-intents-v1", isDirectory: true)
    }
    lifetime = 30
    clock = { Date() }
  }

  public func register(_ command: Command) throws -> Token {
    try locked { record, file in
      let now = clock()
      let previous = record.flatMap { valid($0, at: now) && $0.pending ? $0 : nil }
      let target: Bool?
      let inverted: Bool
      switch command {
      case .start: target = true; inverted = false
      case .stop: target = false; inverted = false
      case .toggle:
        target = previous?.target.map { !$0 }
        inverted = target == nil ? !(previous?.inverted ?? false) : false
      }
      let next = Record(token: Token(id: UUID()), target: target, inverted: inverted,
        created: now, expires: now.addingTimeInterval(lifetime))
      try write(next, to: file)
      return next.token
    }
  }

  public func resolve(_ token: Token, observedRunning: Bool) throws -> Bool {
    try locked { record, file in
      var current = try require(token, record)
      if current.target == nil {
        current.target = observedRunning != current.inverted
        try write(current, to: file)
      }
      return current.target!
    }
  }

  public func isCurrent(_ token: Token) throws -> Bool {
    try locked { record, _ in
      guard let record else { return false }
      return record.token == token && record.pending && valid(record, at: clock())
    }
  }

  public func isLatest(_ token: Token) throws -> Bool {
    try locked { record, _ in
      guard let record else { return false }
      return record.token == token && valid(record, at: clock())
    }
  }

  public func perform<T>(_ token: Token, running: Bool, _ effect: () throws -> T) throws -> T {
    try locked { record, file in
      let current = try require(token, record)
      guard current.target == running else { throw TunnelIntentError.superseded }
      // Verify write availability before the synchronous OS command; never hold this lock across await.
      try write(current, to: file)
      guard valid(current, at: clock()) else { throw TunnelIntentError.expired }
      return try effect()
    }
  }

  public func finish(_ token: Token) throws {
    try locked { record, file in
      guard var current = record, current.token == token else { return }
      current.pending = false
      try write(current, to: file)
    }
  }

  private func valid(_ record: Record, at now: Date) -> Bool {
    record.version == 1 && now >= record.created && now < record.expires
      && record.expires.timeIntervalSince(record.created) <= 30
  }

  private func require(_ token: Token, _ record: Record?) throws -> Record {
    guard let record, record.token == token, record.pending else {
      throw TunnelIntentError.superseded
    }
    guard valid(record, at: clock()) else { throw TunnelIntentError.expired }
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
    let input = open(file.path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
    var record: Record?
    if input >= 0 {
      let handle = FileHandle(fileDescriptor: input, closeOnDealloc: true)
      guard let data = try handle.read(upToCount: 4097), data.count <= 4096,
        let decoded = try? JSONDecoder().decode(Record.self, from: data), decoded.version == 1
      else { throw TunnelIntentError.unavailable }
      record = decoded
    } else if errno != ENOENT {
      throw TunnelIntentError.unavailable
    }
    return try operation(record, file)
  }
}
