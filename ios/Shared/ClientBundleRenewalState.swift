import Foundation

// One serial owner must retain this value, execute intents, and deliver all callbacks on that queue.
// ACKs attest actual completion; rejecting a ticket cannot cancel an already-running native apply.
// The adapter supplies nondecreasing server-aligned time and enforces expiry in Core even without callbacks.
public struct ClientBundleRenewalState: Sendable {
  public struct SessionEpoch: Equatable, Sendable {
    public let rawValue: UInt64
    public init(_ opaque: UInt64) { self.rawValue = opaque }
  }

  public struct OwnerInstance: Equatable, Sendable {
    public let rawValue: UInt64
    public init(_ opaque: UInt64) { self.rawValue = opaque }
  }

  public struct Binding: Equatable, Sendable {
    public let session: SessionEpoch
    public let owner: OwnerInstance
    public init(session: SessionEpoch, owner: OwnerInstance) {
      self.session = session
      self.owner = owner
    }
  }

  public struct BundleDescriptor: Equatable, Sendable {
    public let issuedAt: Date
    public let expiresAt: Date
    public init(issuedAt: Date, expiresAt: Date) {
      self.issuedAt = issuedAt
      self.expiresAt = expiresAt
    }

    fileprivate func valid(at now: Date) -> Bool {
      let ttl = expiresAt.timeIntervalSince(issuedAt)
      return now.timeIntervalSince1970.isFinite && issuedAt.timeIntervalSince1970.isFinite
        && expiresAt.timeIntervalSince1970.isFinite && issuedAt <= now
        && expiresAt > now && ttl > 0 && ttl <= 300
    }
  }

  public struct Ticket: Equatable, Sendable {
    public let binding: Binding
    public let generation: UInt64
    public let sequence: UInt64
    fileprivate init(binding: Binding, generation: UInt64, sequence: UInt64) {
      self.binding = binding
      self.generation = generation
      self.sequence = sequence
    }
  }

  public enum Phase: Equatable, Sendable { case inactive, ready, requesting, staged, terminating }
  public enum Credentials: Sendable { case available, unavailable, locked }
  public enum NetworkResult: Sendable {
    case validatedBundle(BundleDescriptor)
    case unauthorized
    case forbidden
    case rateLimited(retryAfter: Date?)
    case transportFailure
    case unknown
  }
  public enum CleanupStep: Equatable, Sendable {
    case publishGenerationBarrier, cancelURLRequest, fenceOrDrainInstall
    case revokeAutomaticLeaseAndCloseManagedFlows, deleteOldEpochAuthorization, clearOldBundle
  }
  public struct CleanupIntent: Equatable, Sendable {
    public let oldBinding: Binding
    public let generation: UInt64
    public let step: CleanupStep
    fileprivate init(oldBinding: Binding, generation: UInt64, step: CleanupStep) {
      self.oldBinding = oldBinding
      self.generation = generation
      self.step = step
    }
  }
  public enum Intent: Equatable, Sendable {
    case requestBundle(Ticket)
    case installBundle(Ticket, BundleDescriptor)
    case cleanup(CleanupIntent)
  }

  public private(set) var phase: Phase = .inactive
  public private(set) var binding: Binding?
  // This is an owner-local fence, not Main's durable SessionEpoch; its publication ACK must attest that barrier separately.
  public private(set) var generation: UInt64 = 0
  public private(set) var attemptSequence: UInt64 = 0
  public private(set) var installedBundle: BundleDescriptor?
  public private(set) var nextRequestAt: Date?
  public private(set) var pendingCleanup: CleanupIntent?
  private var ticket: Ticket?
  private var authorizationBinding: Binding?
  private var stagedBundle: BundleDescriptor?
  private var cleanupSteps: [CleanupStep] = []
  private var resumeAfterCleanup = false
  private var logoutAfterCleanup = false
  private var failures = 0

  public init() {}

  // Activation asserts validated login/owner context; an existing descriptor is staged, never presumed installed.
  @discardableResult
  public mutating func activate(
    _ context: Binding, existingBundle: BundleDescriptor? = nil, now: Date
  ) -> [Intent] {
    guard phase == .inactive, now.timeIntervalSince1970.isFinite else { return [] }
    generation += 1
    binding = context
    authorizationBinding = context
    phase = .ready
    failures = 0
    nextRequestAt = now
    guard let bundle = existingBundle, bundle.valid(at: now) else { return [] }
    let token = makeTicket(context)
    ticket = token
    stagedBundle = bundle
    phase = .staged
    nextRequestAt = now.addingTimeInterval(60)
    return [.installBundle(token, bundle)]
  }

  public func usableLease(at now: Date) -> BundleDescriptor? {
    guard binding != nil, phase != .terminating,
      let bundle = installedBundle, bundle.valid(at: now) else { return nil }
    return bundle
  }

  public mutating func beginRequest(now: Date, credentials: Credentials) -> [Intent] {
    guard phase == .ready, let context = binding,
      now.timeIntervalSince1970.isFinite, let due = nextRequestAt, now >= due,
      case .available = credentials else { return [] }
    let token = makeTicket(context)
    ticket = token
    phase = .requesting
    nextRequestAt = now.addingTimeInterval(60)
    return [.requestBundle(token)]
  }

  public mutating func completeRequest(
    _ token: Ticket, result: NetworkResult, now: Date
  ) -> [Intent] {
    guard phase == .requesting, matches(token), now.timeIntervalSince1970.isFinite else { return [] }
    switch result {
    case .validatedBundle(let bundle):
      guard bundle.valid(at: now) else { finishFailure(now: now); return [] }
      stagedBundle = bundle
      phase = .staged
      return [.installBundle(token, bundle)]
    case .unauthorized:
      return terminate(deleteAuthorization: true, resume: false)
    case .forbidden:
      nextRequestAt = now.addingTimeInterval(60)
      return terminate(deleteAuthorization: false, resume: true)
    case .rateLimited(let deadline):
      finishFailure(now: now)
      if let deadline = deadline, deadline.timeIntervalSince1970.isFinite, deadline > now {
        nextRequestAt = max(nextRequestAt!, deadline)
      }
    case .transportFailure, .unknown:
      finishFailure(now: now)
    }
    return []
  }

  public mutating func acknowledgeInstall(
    _ token: Ticket, succeeded: Bool, now: Date
  ) -> [Intent] {
    guard phase == .staged, matches(token), let bundle = stagedBundle,
      now.timeIntervalSince1970.isFinite else { return [] }
    guard succeeded, bundle.valid(at: now) else {
      nextRequestAt = now.addingTimeInterval(60)
      return terminate(deleteAuthorization: false, resume: true)
    }
    installedBundle = bundle
    stagedBundle = nil
    ticket = nil
    phase = .ready
    failures = 0
    nextRequestAt = min(nextRequestAt ?? now, now.addingTimeInterval(
      min(60, max(1, bundle.expiresAt.timeIntervalSince(now) / 2))
    ))
    return []
  }

  public func windowEnteredBackground() -> [Intent] { [] }

  public mutating func logout() -> [Intent] {
    if phase == .terminating {
      generation += 1
      resumeAfterCleanup = false
      binding = nil
      authorizationBinding = nil
      if pendingCleanup?.step == .clearOldBundle {
        logoutAfterCleanup = true
        return []
      }
      if !cleanupSteps.contains(.deleteOldEpochAuthorization),
        let index = cleanupSteps.firstIndex(of: .clearOldBundle) {
        cleanupSteps.insert(.deleteOldEpochAuthorization, at: index)
      }
      return []
    }
    return terminate(deleteAuthorization: true, resume: false)
  }

  public mutating func stopOwner() -> [Intent] {
    guard phase != .inactive else { return [] }
    if phase == .terminating {
      resumeAfterCleanup = false
      binding = nil
      return []
    }
    return terminate(deleteAuthorization: false, resume: false)
  }

  // Missing/failed ACK leaves the exact intent pending and blocks activation and renewal.
  public mutating func acknowledgeCleanup(_ intent: CleanupIntent) -> [Intent] {
    guard phase == .terminating, pendingCleanup == intent else { return [] }
    cleanupSteps.removeFirst()
    if let step = cleanupSteps.first {
      let next = CleanupIntent(oldBinding: intent.oldBinding, generation: intent.generation, step: step)
      pendingCleanup = next
      return [.cleanup(next)]
    }
    pendingCleanup = nil
    if logoutAfterCleanup {
      logoutAfterCleanup = false
      phase = .ready
      binding = intent.oldBinding
      return terminate(deleteAuthorization: true, resume: false)
    }
    phase = resumeAfterCleanup ? .ready : .inactive
    resumeAfterCleanup = false
    return []
  }

  private mutating func makeTicket(_ context: Binding) -> Ticket {
    attemptSequence += 1
    return Ticket(binding: context, generation: generation, sequence: attemptSequence)
  }

  private func matches(_ token: Ticket) -> Bool {
    token == ticket && token.binding == binding && token.generation == generation
  }

  private mutating func finishFailure(now: Date) {
    failures = min(failures + 1, 4)
    let backoff: TimeInterval = [60, 120, 240, 300][failures - 1]
    nextRequestAt = max(nextRequestAt ?? now, now.addingTimeInterval(backoff))
    ticket = nil
    phase = .ready
  }

  private mutating func terminate(deleteAuthorization: Bool, resume: Bool) -> [Intent] {
    guard phase != .terminating, let old = binding ?? authorizationBinding else { return [] }
    generation += 1
    phase = .terminating
    ticket = nil
    stagedBundle = nil
    installedBundle = nil
    resumeAfterCleanup = resume
    if deleteAuthorization { authorizationBinding = nil }
    if !resume { binding = nil; nextRequestAt = nil }
    cleanupSteps = [.publishGenerationBarrier, .cancelURLRequest, .fenceOrDrainInstall,
      .revokeAutomaticLeaseAndCloseManagedFlows]
    if deleteAuthorization { cleanupSteps.append(.deleteOldEpochAuthorization) }
    cleanupSteps.append(.clearOldBundle)
    let first = CleanupIntent(oldBinding: old, generation: generation, step: cleanupSteps[0])
    pendingCleanup = first
    return [.cleanup(first)]
  }
}
