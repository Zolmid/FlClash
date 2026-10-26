import Foundation

public struct ClientBundleAuthorization: Sendable {
  public let accountID: String
  public let binding: ClientBundleRenewalState.Binding
  public let value: String

  public init(accountID: String, binding: ClientBundleRenewalState.Binding, value: String) {
    self.accountID = accountID
    self.binding = binding
    self.value = value
  }
}

public enum ClientBundleCredentialError: Error { case unavailable, locked, bindingMismatch }

public protocol ClientBundleCredentialStore: Sendable {
  func read(for binding: ClientBundleRenewalState.Binding) async throws -> ClientBundleAuthorization
  func delete(for binding: ClientBundleRenewalState.Binding) async throws
}

public protocol ClientBundleWritableCredentialStore: ClientBundleCredentialStore {
  func publish(accountID: String, authorization: String, binding: ClientBundleRenewalState.Binding) async throws
}

public struct ClientBundleHTTPResponse: Sendable {
  public let status: Int
  public let body: Data
  public let retryAfter: Date?

  public init(status: Int, body: Data, retryAfter: Date? = nil) {
    self.status = status
    self.body = body
    self.retryAfter = retryAfter
  }
}

public protocol ClientBundleRenewalTransport: Sendable {
  func fetch(authorization: ClientBundleAuthorization) async throws -> ClientBundleHTTPResponse
}

public protocol ClientBundleRenewalControl: Sendable {
  func isCurrent(_ binding: ClientBundleRenewalState.Binding) async throws -> Bool
  // A session invalidation must publish Main's durable epoch before returning.
  func publishBarrier(
    _ binding: ClientBundleRenewalState.Binding, generation: UInt64, invalidatingSession: Bool
  ) async throws
}

public protocol ClientBundleRenewalCore: Sendable {
  func start(_ binding: ClientBundleRenewalState.Binding, generation: UInt64) async throws
  // Implementations must validate the full body and actual Core owner guard before applying.
  func install(
    _ body: Data, accountID: String, ticket: ClientBundleRenewalState.Ticket
  ) async throws -> Bool
  func fenceOrDrain(_ binding: ClientBundleRenewalState.Binding, invalidatingSession: Bool) async throws
  func revokeAutomaticLeaseAndCloseManagedFlows(
    _ binding: ClientBundleRenewalState.Binding
  ) async throws
  func clearVolatileBundle(_ binding: ClientBundleRenewalState.Binding) async throws
  func isLeaseInstalled() async -> Bool
}

public actor ClientBundleRenewalOwner {
  private var state = ClientBundleRenewalState()
  private let credentials: any ClientBundleCredentialStore
  private let transport: any ClientBundleRenewalTransport
  private let control: any ClientBundleRenewalControl
  private let core: any ClientBundleRenewalCore
  private let clock: @Sendable () -> Date
  private var network: Task<Void, Never>?
  private var installation: Task<Void, Never>?
  private var timer: Task<Void, Never>?
  private var invalidatingSession = false
  private var cleaning = false
  private var stopped = false
  private var lifecycle: UInt64 = 0
  private var claimed = false
  private var established = false
  private var automaticScheduling = false
  private var retryNotBefore: Date?
  public private(set) var failure: String?

  public init(
    credentials: any ClientBundleCredentialStore, transport: any ClientBundleRenewalTransport,
    control: any ClientBundleRenewalControl, core: any ClientBundleRenewalCore,
    clock: @escaping @Sendable () -> Date = { Date() }
  ) {
    self.credentials = credentials
    self.transport = transport
    self.control = control
    self.core = core
    self.clock = clock
  }

  public func start(_ binding: ClientBundleRenewalState.Binding, automaticScheduling: Bool = true) async {
    guard state.phase == .inactive, !stopped else { return }
    lifecycle += 1
    let intent = lifecycle
    do {
      guard try await control.isCurrent(binding), intent == lifecycle, !stopped else { return }
      invalidatingSession = false
      _ = state.activate(binding, now: clock())
      do {
        try await core.start(binding, generation: state.generation)
      } catch {
        _ = state.stopOwner()
        await drainCleanup()
        failure = "native_renewal_unavailable"
        return
      }
      guard intent == lifecycle, state.phase == .ready, !stopped else { return }
      claimed = true
      established = true
      self.automaticScheduling = automaticScheduling
      await tick()
    } catch { failure = "owner_control_unavailable" }
  }

  public func tick() async {
    guard !stopped, state.phase == .ready, let binding = state.binding else { return }
    let generation = state.generation
    do {
      guard try await control.isCurrent(binding) else {
        if state.binding == binding, state.generation == generation { await stop() }
        return
      }
      guard let due = state.nextRequestAt, due <= clock(), retryNotBefore.map({ $0 <= clock() }) ?? true else {
        scheduleNext()
        return
      }
      if !claimed {
        try await core.start(binding, generation: generation)
        guard state.binding == binding, state.generation == generation, state.phase == .ready else { return }
        claimed = true
        established = true
      }
      let authorization = try await credentials.read(for: binding)
      guard authorization.binding == binding, !authorization.accountID.isEmpty,
        authorization.value.hasPrefix("Bearer "), authorization.value.count > 7,
        !authorization.value.contains("\r"), !authorization.value.contains("\n")
      else { failure = "credential_binding_mismatch"; return }
      guard state.binding == binding, state.phase == .ready else { return }
      for intent in state.beginRequest(now: clock(), credentials: .available) {
        guard case .requestBundle(let ticket) = intent else { continue }
        network = Task { [weak self, transport] in
          do {
            let response = try await transport.fetch(authorization: authorization)
            guard !Task.isCancelled else { return }
            await self?.receive(response, authorization: authorization, ticket: ticket)
          } catch {
            guard !Task.isCancelled else { return }
            await self?.receiveFailure(ticket)
          }
        }
      }
    } catch ClientBundleCredentialError.locked {
      failure = "credentials_locked"
      retryNotBefore = clock().addingTimeInterval(15)
    } catch {
      failure = "renewal_unavailable"
      retryNotBefore = clock().addingTimeInterval(15)
    }
    scheduleNext()
  }

  public func logout() async {
    lifecycle += 1
    automaticScheduling = false
    invalidatingSession = true
    timer?.cancel()
    timer = nil
    _ = state.logout()
    await drainCleanup()
  }

  public func stop() async {
    lifecycle += 1
    automaticScheduling = false
    stopped = true
    timer?.cancel()
    timer = nil
    _ = state.stopOwner()
    await drainCleanup()
  }

  public func retryCleanup() async { await drainCleanup() }
  public func phase() -> ClientBundleRenewalState.Phase { state.phase }
  public func usableLease() -> ClientBundleRenewalState.BundleDescriptor? { state.usableLease(at: clock()) }

  public func status() async -> ClientBundleRenewalStatus {
    let revision = lifecycle
    let current = (try? await control.isCurrent(state.binding ?? .init(session: .init(0), owner: .init(0)))) == true
    let lease = state.usableLease(at: clock())
    var installed = false
    if lease != nil { installed = await core.isLeaseInstalled() }
    let owns = established && !stopped && !invalidatingSession &&
      state.phase != .inactive && current && revision == lifecycle
    return .init(supported: true, sessionEpoch: state.binding?.session.rawValue,
      ownerId: state.binding?.owner.rawValue, ownsRenewal: owns, ready: owns && installed,
      state: state.phase == .inactive && invalidatingSession ? "logged_out"
        : failure ?? String(describing: state.phase),
      expiresAt: lease.map { Int64($0.expiresAt.timeIntervalSince1970 * 1000) })
  }

  private func scheduleNext() {
    timer?.cancel()
    timer = nil
    guard automaticScheduling, !stopped, state.phase == .ready, let due = state.nextRequestAt else { return }
    let deadline = max(due, retryNotBefore ?? due)
    let seconds = min(300, max(0.05, deadline.timeIntervalSince(clock())))
    timer = Task { [weak self] in
      do { try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000)) }
      catch { return }
      guard !Task.isCancelled else { return }
      await self?.tick()
    }
  }

  private func receiveFailure(_ ticket: ClientBundleRenewalState.Ticket) {
    guard accepts(ticket) else { return }
    _ = state.completeRequest(ticket, result: .transportFailure, now: clock())
    failure = "bundle_unavailable"
    scheduleNext()
  }

  private func receive(
    _ response: ClientBundleHTTPResponse, authorization: ClientBundleAuthorization,
    ticket: ClientBundleRenewalState.Ticket
  ) async {
    guard accepts(ticket), !stopped else { return }
    do {
      guard try await control.isCurrent(ticket.binding) else { await stop(); return }
      guard accepts(ticket), !stopped else { return }
    } catch { receiveFailure(ticket); return }
    let result: ClientBundleRenewalState.NetworkResult
    if response.status == 401 {
      invalidatingSession = true
      timer?.cancel()
      timer = nil
      result = .unauthorized
    } else if response.status == 403, Self.errorCode(response.body) == "entitlement_unavailable" {
      result = .forbidden
    } else if response.status == 429 {
      result = .rateLimited(retryAfter: response.retryAfter)
    } else if response.status == 200,
      let descriptor = Self.descriptor(response.body, accountID: authorization.accountID)
    {
      result = .validatedBundle(descriptor)
    } else { result = .unknown }
    let intents = state.completeRequest(ticket, result: result, now: clock())
    for intent in intents {
      if case .installBundle(let token, _) = intent {
        installation = Task { [weak self, core] in
          do {
            let applied = try await core.install(response.body, accountID: authorization.accountID, ticket: token)
            await self?.installed(token, success: applied)
          } catch { await self?.installed(token, success: false) }
        }
      }
    }
    await drainCleanup()
  }

  private func installed(_ ticket: ClientBundleRenewalState.Ticket, success: Bool) async {
    installation = nil
    _ = state.acknowledgeInstall(ticket, succeeded: success, now: clock())
    if success, state.phase == .ready { failure = nil }
    await drainCleanup()
    scheduleNext()
  }

  private func accepts(_ ticket: ClientBundleRenewalState.Ticket) -> Bool {
    state.phase == .requesting && state.binding == ticket.binding &&
      state.generation == ticket.generation && state.attemptSequence == ticket.sequence
  }

  private func drainCleanup() async {
    guard !cleaning else { return }
    cleaning = true
    defer { cleaning = false }
    while let intent = state.pendingCleanup {
      do {
        switch intent.step {
        case .publishGenerationBarrier:
          try await control.publishBarrier(
            intent.oldBinding, generation: intent.generation, invalidatingSession: invalidatingSession
          )
        case .cancelURLRequest:
          network?.cancel()
          network = nil
        case .fenceOrDrainInstall:
          try await core.fenceOrDrain(intent.oldBinding, invalidatingSession: invalidatingSession)
          claimed = false
          await installation?.value
          installation = nil
        case .revokeAutomaticLeaseAndCloseManagedFlows:
          try await core.revokeAutomaticLeaseAndCloseManagedFlows(intent.oldBinding)
        case .deleteOldEpochAuthorization:
          try await credentials.delete(for: intent.oldBinding)
        case .clearOldBundle:
          try await core.clearVolatileBundle(intent.oldBinding)
        }
        _ = state.acknowledgeCleanup(intent)
      } catch {
        failure = "renewal_cleanup_incomplete"
        return
      }
    }
    scheduleNext()
  }

  private static func errorCode(_ data: Data) -> String? {
    guard data.count <= 8 * 1024 * 1024,
      let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let error = root["error"] as? [String: Any] else { return nil }
    return error["code"] as? String
  }

  private static func descriptor(
    _ body: Data, accountID: String
  ) -> ClientBundleRenewalState.BundleDescriptor? {
    guard body.count <= 8 * 1024 * 1024,
      let root = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
      let value = root["data"] as? [String: Any],
      value["schema_version"] as? Int == 1, value["account_id"] as? String == accountID,
      let issued = value["issued_at"] as? Int64, let expires = value["expires_at"] as? Int64
    else { return nil }
    return .init(issuedAt: Date(timeIntervalSince1970: Double(issued)),
      expiresAt: Date(timeIntervalSince1970: Double(expires)))
  }
}
