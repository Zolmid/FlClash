import Foundation
import Darwin

public enum ClientBundleEpochError: Error { case unavailable, staleSession, exhausted }

public actor ClientBundleEpochStore: ClientBundleRenewalControl {
  private struct Record: Codable, Equatable {
    var epoch: UInt64 = 0
    var owner: UInt64 = 0
    var fence: UInt64 = 0
    var active = false
    var accountID = ""
    var retiringEpoch: UInt64?
    var retiringOwner: UInt64?
  }

  private let directory: URL
  private let stateFile: URL
  private let lockFile: URL
  private let allowsLockedAccess: Bool

  public init(directory: URL, allowsLockedAccess: Bool = false) throws {
    guard directory.isFileURL else { throw ClientBundleEpochError.unavailable }
    self.directory = directory
    self.stateFile = directory.appendingPathComponent("control.json")
    self.lockFile = directory.appendingPathComponent("control.lock")
    self.allowsLockedAccess = allowsLockedAccess
  }

  public func claimOwner(sessionEpoch: UInt64) throws -> ClientBundleRenewalState.Binding {
    try locked { record in
      guard record.active, record.epoch == sessionEpoch else { throw ClientBundleEpochError.staleSession }
      guard record.owner < UInt64.max else { throw ClientBundleEpochError.exhausted }
      record.owner += 1
      record.fence = 0
      return Self.binding(record)
    }
  }

  public func reserveSession(accountID: String) throws -> ClientBundleRenewalState.Binding {
    guard !accountID.isEmpty, accountID.utf8.count <= 256,
      !accountID.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 })
    else { throw ClientBundleEpochError.unavailable }
    return try locked { record in
      guard !record.active, record.retiringEpoch == nil else { throw ClientBundleEpochError.staleSession }
      guard record.epoch < UInt64.max, record.owner < UInt64.max else { throw ClientBundleEpochError.exhausted }
      record.epoch += 1
      record.owner += 1
      record.active = false
      record.accountID = accountID
      record.fence = 0
      return Self.binding(record)
    }
  }

  public func activateReservedSession(_ binding: ClientBundleRenewalState.Binding) throws {
    try locked { record in
      guard Self.binding(record) == binding, !record.accountID.isEmpty else {
        throw ClientBundleEpochError.staleSession
      }
      record.active = true
    }
  }

  public func pendingBinding() throws -> ClientBundleRenewalState.Binding? {
    try locked { !$0.active && !$0.accountID.isEmpty ? Self.binding($0) : nil }
  }

  public func retiringBinding() throws -> ClientBundleRenewalState.Binding? {
    try locked { record in
      guard let epoch = record.retiringEpoch, let owner = record.retiringOwner else { return nil }
      return .init(session: .init(epoch), owner: .init(owner))
    }
  }

  public func acknowledgeRetirement(_ binding: ClientBundleRenewalState.Binding) throws {
    try locked { record in
      guard record.retiringEpoch == binding.session.rawValue, record.retiringOwner == binding.owner.rawValue else { return }
      record.retiringEpoch = nil
      record.retiringOwner = nil
    }
  }

  public func currentBinding() throws -> ClientBundleRenewalState.Binding? {
    try locked { $0.active ? Self.binding($0) : nil }
  }

  public func invalidateSession(_ epoch: UInt64) throws {
    try locked { record in
      guard record.epoch == epoch else { return }
      guard record.epoch < UInt64.max else { throw ClientBundleEpochError.exhausted }
      record.retiringEpoch = record.epoch
      record.retiringOwner = record.owner
      record.epoch += 1
      record.active = false
      record.accountID = ""
    }
  }

  public func isCurrent(_ binding: ClientBundleRenewalState.Binding) async throws -> Bool {
    try locked { $0.active && Self.binding($0) == binding }
  }

  public func publishBarrier(
    _ binding: ClientBundleRenewalState.Binding, generation: UInt64, invalidatingSession: Bool
  ) async throws {
    try locked { record in
      guard record.epoch == binding.session.rawValue else { return }
      guard Self.binding(record) == binding else { throw ClientBundleEpochError.staleSession }
      record.fence = max(record.fence, generation)
      if invalidatingSession {
        guard record.epoch < UInt64.max else { throw ClientBundleEpochError.exhausted }
        record.retiringEpoch = record.epoch
        record.retiringOwner = record.owner
        record.epoch += 1
        record.active = false
        record.accountID = ""
      }
    }
  }

  private static func binding(_ record: Record) -> ClientBundleRenewalState.Binding {
    .init(session: .init(record.epoch), owner: .init(record.owner))
  }

  private func locked<T>(_ operation: (inout Record) throws -> T) throws -> T {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
      attributes: [.posixPermissions: 0o700])
    try protect(directory)
    let descriptor = open(lockFile.path, O_CREAT | O_RDWR | O_CLOEXEC | O_NOFOLLOW, 0o600)
    guard descriptor >= 0 else { throw ClientBundleEpochError.unavailable }
    defer { close(descriptor) }
    try protect(lockFile)
    guard flock(descriptor, LOCK_EX) == 0 else { throw ClientBundleEpochError.unavailable }
    defer { flock(descriptor, LOCK_UN) }
    var record = Record()
    if FileManager.default.fileExists(atPath: stateFile.path) {
      let input = open(stateFile.path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
      guard input >= 0 else { throw ClientBundleEpochError.unavailable }
      let handle = FileHandle(fileDescriptor: input, closeOnDealloc: true)
      guard let bytes = try handle.read(upToCount: 4097), bytes.count <= 4096,
        let decoded = try? JSONDecoder().decode(Record.self, from: bytes)
      else { throw ClientBundleEpochError.unavailable }
      record = decoded
    }
    let before = record
    let result = try operation(&record)
    if before != record {
      let bytes = try JSONEncoder().encode(record)
      try bytes.write(to: stateFile, options: [.atomic])
      try protect(stateFile)
      guard chmod(stateFile.path, 0o600) == 0 else { throw ClientBundleEpochError.unavailable }
      let output = open(stateFile.path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
      guard output >= 0 else { throw ClientBundleEpochError.unavailable }
      defer { close(output) }
      guard fsync(output) == 0 else { throw ClientBundleEpochError.unavailable }
      let parent = open(directory.path, O_RDONLY | O_CLOEXEC)
      guard parent >= 0 else { throw ClientBundleEpochError.unavailable }
      defer { close(parent) }
      guard fsync(parent) == 0 else { throw ClientBundleEpochError.unavailable }
    }
    return result
  }

  private func protect(_ url: URL) throws {
    #if os(iOS)
    try FileManager.default.setAttributes([.protectionKey: allowsLockedAccess
      ? FileProtectionType.completeUntilFirstUserAuthentication : FileProtectionType.complete],
      ofItemAtPath: url.path)
    #endif
  }
}
