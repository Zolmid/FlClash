import Foundation

public actor ClientBundleSessionPublisher {
  public typealias StopOwner = @Sendable (ClientBundleRenewalState.Binding) async throws -> Void
  private let authority: ClientBundleEpochStore
  private let credentials: any ClientBundleWritableCredentialStore
  private let stopOwner: StopOwner
  private var tail: Task<Void, Never>?

  public init(
    authority: ClientBundleEpochStore, credentials: any ClientBundleWritableCredentialStore,
    stopOwner: @escaping StopOwner
  ) {
    self.authority = authority
    self.credentials = credentials
    self.stopOwner = stopOwner
  }

  public func configure(accountID: String, authorization: String) async throws -> ClientBundleRenewalState.Binding {
    let previous = tail
    let operation = Task {
      await previous?.value
      return try await self.publish(accountID: accountID, authorization: authorization)
    }
    tail = Task { _ = try? await operation.value }
    return try await operation.value
  }

  public func logout(sessionEpoch: UInt64) async throws {
    let previous = tail
    let operation = Task {
      await previous?.value
      if let current = try await self.authority.currentBinding(), current.session.rawValue == sessionEpoch {
        try await self.authority.invalidateSession(sessionEpoch)
      }
      if let pending = try await self.authority.retiringBinding(), pending.session.rawValue == sessionEpoch {
        try await self.retirePendingOwner()
      }
    }
    tail = Task { _ = try? await operation.value }
    try await operation.value
  }

  private func publish(accountID: String, authorization: String) async throws -> ClientBundleRenewalState.Binding {
    guard !accountID.isEmpty, accountID.utf8.count <= 256, authorization.hasPrefix("Bearer "),
      authorization.utf8.count > 7, authorization.utf8.count <= 16 * 1024,
      !authorization.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 })
    else { throw ClientBundleCredentialError.bindingMismatch }
    try await retirePendingOwner()
    if let pending = try await authority.pendingBinding() {
      try await credentials.delete(for: pending)
    }
    if let current = try await authority.currentBinding() {
      let existing: ClientBundleAuthorization?
      do { existing = try await credentials.read(for: current) }
      catch ClientBundleCredentialError.locked { throw ClientBundleCredentialError.locked }
      catch { existing = nil }
      if existing?.accountID == accountID, existing?.value == authorization {
        return current
      }
      try await authority.invalidateSession(current.session.rawValue)
      try await retirePendingOwner()
    }
    let reserved = try await authority.reserveSession(accountID: accountID)
    try await credentials.publish(accountID: accountID, authorization: authorization, binding: reserved)
    let verified = try await credentials.read(for: reserved)
    guard verified.accountID == accountID, verified.value == authorization else {
      throw ClientBundleCredentialError.bindingMismatch
    }
    try await authority.activateReservedSession(reserved)
    return reserved
  }

  private func retirePendingOwner() async throws {
    guard let pending = try await authority.retiringBinding() else { return }
    try await stopOwner(pending)
    try await credentials.delete(for: pending)
    try await authority.acknowledgeRetirement(pending)
  }
}
