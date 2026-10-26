import Foundation

public enum ClientBundleCoreError: Error { case unavailable, staleOwner, installationRejected }

public actor ClientBundleCoreAdapter: ClientBundleRenewalCore {
  public typealias Call = @Sendable (Data) async throws -> Data

  private struct Context: Codable, Equatable, Sendable {
    let ownerSerial: UInt64?
    let instanceId: String
    let accountId: String
    let accountGeneration: Int
    let configurationGeneration: Int
  }
  private struct Guard: Codable, Sendable {
    let instanceId: String
    let accountId: String
    let accountGeneration: Int
    let sessionEpoch: UInt64
    let ownerId: UInt64
    let generation: UInt64
    let serial: UInt64
  }
  private struct Begin: Encodable {
    let ownerSerial: UInt64?
    let instanceId: String
    let accountId: String
    let accountGeneration: Int
    let configurationGeneration: Int
    let sessionEpoch: UInt64
    let ownerId: UInt64
    let generation: UInt64
  }
  private struct Install: Encodable { let owner: Guard; let sequence: UInt64; let body: String }
  private struct Lease: Decodable, Equatable {
    let instanceId: String
    let accountId: String
    let accountGeneration: Int
    let configurationGeneration: Int
    let bundleId: String
    let configurationDigest: String
    let expiresAt: Int64
  }
  private struct End: Encodable {
    let owner: Guard?
    let context: Begin?
    let invalidateSession: Bool
  }
  private struct Method<Arguments: Encodable>: Encodable {
    let id: String
    let method: String
    let arguments: Arguments?
  }
  private struct MethodFailure: Decodable { let code: String }
  private struct Response<Value: Decodable>: Decodable {
    let result: Value?
    let error: MethodFailure?
    let file: String?
  }

  private let call: Call
  private let binding: ClientBundleRenewalState.Binding
  private let accountID: String
  private var context: Context?
  private var guardValue: Guard?
  private var tail: Task<Void, Never>?
  private var sequence: UInt64 = 0
  private var admittedGeneration: UInt64 = 0
  private var fencedGeneration: UInt64 = 0
  private var installedLease: Lease?

  public init(binding: ClientBundleRenewalState.Binding, accountID: String, call: @escaping Call) {
    self.binding = binding
    self.accountID = accountID
    self.call = call
  }

  public func start(_ binding: ClientBundleRenewalState.Binding, generation: UInt64) async throws {
    guard binding == self.binding else { throw ClientBundleCoreError.staleOwner }
    admittedGeneration = max(admittedGeneration, generation)
    let previous = tail
    let operation = Task {
      await previous?.value
      try await self.claim(generation)
    }
    tail = Task { _ = try? await operation.value }
    try await operation.value
  }

  public func install(
    _ body: Data, accountID: String, ticket: ClientBundleRenewalState.Ticket
  ) async throws -> Bool {
    guard ticket.binding == binding, accountID == self.accountID else { throw ClientBundleCoreError.staleOwner }
    admittedGeneration = max(admittedGeneration, ticket.generation)
    let previous = tail
    let operation = Task {
      await previous?.value
      guard ticket.generation > self.fencedGeneration else { throw ClientBundleCoreError.staleOwner }
      if self.guardValue?.generation != ticket.generation { try await self.claim(ticket.generation) }
      guard let owner = self.guardValue, let text = String(data: body, encoding: .utf8) else {
        throw ClientBundleCoreError.unavailable
      }
      let result: Bool = try await self.invoke("installClientBundle",
        arguments: Install(owner: owner, sequence: ticket.sequence, body: text))
      if result {
        let lease: Lease = try await self.invoke("getRoutingLease", arguments: Optional<Bool>.none)
        guard lease.instanceId == owner.instanceId, lease.accountId == self.accountID,
          lease.accountGeneration == owner.accountGeneration else { return false }
        self.installedLease = lease
      }
      return result
    }
    tail = Task { _ = try? await operation.value }
    return try await operation.value
  }

  public func fenceOrDrain(
    _ binding: ClientBundleRenewalState.Binding, invalidatingSession: Bool
  ) async throws {
    guard binding == self.binding else { throw ClientBundleCoreError.staleOwner }
    fencedGeneration = max(fencedGeneration, admittedGeneration)
    let previous = tail
    let operation = Task {
      await previous?.value
      if self.guardValue == nil, let context = self.context, invalidatingSession {
        let acknowledged: Bool = try await self.invoke("endClientBundleOwner", arguments: End(
          owner: nil, context: self.begin(context, generation: max(1, self.admittedGeneration)),
          invalidateSession: true))
        guard acknowledged else { throw ClientBundleCoreError.installationRejected }
        return
      } else if self.guardValue == nil, let context = self.context {
        let current: Context = try await self.invoke("getClientBundleOwner", arguments: Optional<Bool>.none)
        guard current == context else { return }
        try await self.claim(max(1, self.admittedGeneration))
      }
      if let owner = self.guardValue {
        let acknowledged: Bool = try await self.invoke("endClientBundleOwner",
          arguments: End(owner: owner, context: nil, invalidateSession: invalidatingSession))
        guard acknowledged else { throw ClientBundleCoreError.installationRejected }
      }
      self.guardValue = nil
      self.installedLease = nil
    }
    tail = Task { _ = try? await operation.value }
    try await operation.value
  }

  public func revokeAutomaticLeaseAndCloseManagedFlows(
    _ binding: ClientBundleRenewalState.Binding
  ) async throws {
    guard binding == self.binding, guardValue == nil else { throw ClientBundleCoreError.staleOwner }
  }

  public func clearVolatileBundle(_ binding: ClientBundleRenewalState.Binding) async throws {
    guard binding == self.binding else { throw ClientBundleCoreError.staleOwner }
  }

  public func isLeaseInstalled() async -> Bool {
    guard let expected = installedLease, guardValue != nil else { return false }
    do {
      let current: Lease = try await invoke("getRoutingLease", arguments: Optional<Bool>.none)
      return current == expected && installedLease == expected && guardValue != nil
    } catch { return false }
  }

  private func claim(_ generation: UInt64) async throws {
    let current: Context = try await invoke("getClientBundleOwner", arguments: Optional<Bool>.none)
    guard current.accountId == accountID, !current.instanceId.isEmpty else { throw ClientBundleCoreError.staleOwner }
    context = current
    guardValue = try await invoke("beginClientBundleOwner", arguments: begin(current, generation: generation))
  }

  private func begin(_ current: Context, generation: UInt64) -> Begin {
    Begin(
      ownerSerial: current.ownerSerial,
      instanceId: current.instanceId, accountId: current.accountId,
      accountGeneration: current.accountGeneration, configurationGeneration: current.configurationGeneration,
      sessionEpoch: binding.session.rawValue, ownerId: binding.owner.rawValue, generation: generation)
  }

  private func invoke<Arguments: Encodable, Value: Decodable>(
    _ method: String, arguments: Arguments?
  ) async throws -> Value {
    sequence += 1
    let request = try JSONEncoder().encode(Method(id: "renewal-\(sequence)", method: method, arguments: arguments))
    guard request.count <= 8 * 1024 * 1024 else { throw ClientBundleCoreError.unavailable }
    let data = try await call(request)
    guard data.count <= 512 * 1024,
      let response = try? JSONDecoder().decode(Response<Value>.self, from: data),
      response.error == nil, response.file == nil, let result = response.result
    else { throw ClientBundleCoreError.unavailable }
    return result
  }
}
