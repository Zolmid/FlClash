import Foundation
import NetworkExtension

@MainActor
private final class IntentAwait<Value> {
  var continuation: CheckedContinuation<Value, Error>?
  var operation: Task<Void, Never>?
  var monitor: Task<Void, Never>?

  func finish(_ result: Result<Value, Error>) {
    guard let continuation else { return }
    self.continuation = nil
    operation?.cancel()
    monitor?.cancel()
    operation = nil
    monitor = nil
    continuation.resume(with: result)
  }
}

private final class IntentCompletionObservation: @unchecked Sendable {
  let connection: NEVPNConnection
  private let authority: TunnelIntentAuthority
  private let token: TunnelIntentAuthority.Token
  private let center: NotificationCenter
  private let lock = NSLock()
  private var observer: NSObjectProtocol?
  private var monitor: Task<Void, Never>?
  private var target: Bool?
  private var sawProgress = false
  private var startIssued = false
  private var startIssuedAt: UInt64?
  private let startConfirmationDelay: UInt64
  private var stopIssued = false
  private var startCompleted = false
  private var stopCompleted = false
  private var handedOff = false
  private var closed = false
  private var completed: Bool { target == true ? startCompleted : target == false && stopCompleted }

  init(
    connection: NEVPNConnection, authority: TunnelIntentAuthority,
    token: TunnelIntentAuthority.Token, center: NotificationCenter, startConfirmationDelay: UInt64
  ) {
    self.connection = connection
    self.authority = authority
    self.token = token
    self.center = center
    self.startConfirmationDelay = startConfirmationDelay
    observer = center.addObserver(forName: .NEVPNStatusDidChange, object: connection, queue: nil) { [weak self] note in
      guard let self, let source = note.object as? NEVPNConnection, source === self.connection else { return }
      // Capture on the posting thread: a later MainActor read can miss a transient terminal state.
      self.capture(source.status, isEvent: true)
    }
    capture(connection.status)
  }

  deinit { close() }

  var isComplete: Bool {
    lock.lock()
    defer { lock.unlock() }
    return completed
  }

  func setTarget(_ running: Bool) {
    lock.lock()
    defer { lock.unlock() }
    guard !closed, target == nil else { return }
    target = running
  }

  func willStart() {
    lock.lock()
    startIssued = true
    startIssuedAt = DispatchTime.now().uptimeNanoseconds
    lock.unlock()
  }

  func willStop() {
    lock.lock()
    stopIssued = true
    lock.unlock()
  }

  @discardableResult
  func sample() -> NEVPNStatus {
    let status = connection.status
    capture(status)
    return status
  }

  private func capture(_ status: NEVPNStatus, isEvent: Bool = false) {
    lock.lock()
    if !closed { record(status, isEvent: isEvent) }
    let shouldFinish = handedOff && completed
    lock.unlock()
    if shouldFinish { _ = reconcile() }
  }

  private func record(_ status: NEVPNStatus, isEvent: Bool) {
    let stopped = status == .disconnected || status == .invalid
    if status == .connecting || (startIssued && status == .disconnecting) { sawProgress = true }
    if status == .connected || status == .reasserting || (stopped && (sawProgress || (startIssued && isEvent))) {
      startCompleted = true
    }
    if stopped, startIssued, !sawProgress, let issuedAt = startIssuedAt,
      DispatchTime.now().uptimeNanoseconds &- issuedAt >= startConfirmationDelay {
      startCompleted = true
    }
    if stopIssued && stopped { stopCompleted = true }
  }

  @MainActor
  func handOff() {
    lock.lock()
    handedOff = true
    lock.unlock()
    sample()
    guard reconcile() else { return }
    let task = Task { @MainActor in
      defer { self.close() }
      while !Task.isCancelled {
        do { try await Task.sleep(nanoseconds: 250_000_000) } catch { return }
        self.sample()
        guard self.reconcile() else { return }
      }
    }
    lock.lock()
    if closed { task.cancel() } else { monitor = task }
    lock.unlock()
  }

  private func reconcile() -> Bool {
    lock.lock()
    guard !closed else { lock.unlock(); return false }
    do {
      if try authority.isCurrent(token) {
        if !completed { lock.unlock(); return true }
        try authority.finish(token)
      }
    } catch TunnelIntentError.busy {
      if !completed {
        lock.unlock()
        return true
      }
      // A terminal observation must stop influencing toggle even while the record lock is busy.
      authority.cancel(token)
    } catch {
      authority.cancel(token)
    }
    let resources = detach()
    lock.unlock()
    dispose(resources)
    return false
  }

  func close() {
    lock.lock()
    let resources = detach()
    lock.unlock()
    dispose(resources)
  }

  private func detach() -> (NSObjectProtocol?, Task<Void, Never>?) {
    closed = true
    let resources = (observer, monitor)
    observer = nil
    monitor = nil
    return resources
  }

  private func dispose(_ resources: (NSObjectProtocol?, Task<Void, Never>?)) {
    if let observer = resources.0 { center.removeObserver(observer) }
    resources.1?.cancel()
  }
}

@MainActor
public final class TunnelIntentClient {
  private let authority: TunnelIntentAuthority
  private let loadManager: () async throws -> NETunnelProviderManager?
  private let isManaged: (NETunnelProviderManager) -> Bool
  private let isSafeMode: () -> Bool
  private let notificationCenter: NotificationCenter
  private let startConfirmationDelay: UInt64

  public init(
    authority: TunnelIntentAuthority,
    loadManager: @escaping () async throws -> NETunnelProviderManager?,
    isManaged: @escaping (NETunnelProviderManager) -> Bool,
    isSafeMode: @escaping () -> Bool,
    notificationCenter: NotificationCenter = .default,
    startConfirmationDelay: UInt64 = 5_000_000_000
  ) {
    self.authority = authority
    self.loadManager = loadManager
    self.isManaged = isManaged
    self.isSafeMode = isSafeMode
    self.notificationCenter = notificationCenter
    self.startConfirmationDelay = startConfirmationDelay
  }

  @discardableResult
  public func request(_ command: TunnelIntentAuthority.Command) async throws -> Bool {
    guard !isSafeMode() else { return false }
    try Task.checkCancellation()
    let token = try await authority.registerWithRetry(command)
    return try await withTaskCancellationHandler {
      var issued = false
      var observation: IntentCompletionObservation?
      defer {
        if !issued {
          observation?.close()
          do { try authority.finish(token) } catch { authority.cancel(token) }
        }
      }
      var retry = true
      while true {
        do {
          try await checkEventually(token)
          let loadManager = self.loadManager
          let isManaged = self.isManaged
          let authority = self.authority
          let center = notificationCenter
          let startConfirmationDelay = self.startConfirmationDelay
          let previous = observation
          let prepared: (NETunnelProviderManager, IntentCompletionObservation)? = try await awaitOperation(token) {
            guard let manager = try await loadManager() else { return nil }
            try Task.checkCancellation()
            guard isManaged(manager) else { return nil }
            let bound = previous?.connection === manager.connection ? previous! :
              IntentCompletionObservation(connection: manager.connection,
                authority: authority, token: token, center: center, startConfirmationDelay: startConfirmationDelay)
            return (manager, bound)
          }
          guard let (manager, completion) = prepared else { return false }
          if observation !== completion { observation?.close(); observation = completion }
          try await checkEventually(token)
          let running = try authority.resolve(token, observedRunning: NEHelper.isRunning(completion.sample()))
          completion.setTarget(running)
          if !running {
            try authority.perform(token, running: false) {
              try checkSafety()
              guard isManaged(manager) else { throw TunnelIntentError.unsafe }
              completion.willStop()
              manager.connection.stopVPNTunnel()
            }
            issued = true
            completion.handOff()
            return true
          }
          var status = try await stableStatus(completion, token: token)
          if completion.isComplete || NEHelper.isRunning(status) {
            issued = true
            completion.handOff()
            return true
          }
          try await checkEventually(token)
          manager.isEnabled = true
          if let rules = manager.onDemandRules, !rules.isEmpty { manager.isOnDemandEnabled = true }
          try await awaitOperation(token) { try await manager.saveToPreferences() }
          try await checkEventually(token)
          try await awaitOperation(token) { try await manager.loadFromPreferences() }
          try await checkEventually(token)
          status = try await stableStatus(completion, token: token)
          if completion.isComplete || NEHelper.isRunning(status) {
            issued = true
            completion.handOff()
            return true
          }
          try authority.perform(token, running: true) {
            try checkSafety()
            guard isManaged(manager) else { throw TunnelIntentError.unsafe }
            completion.willStart()
            try manager.connection.startVPNTunnel()
          }
          issued = true
          completion.handOff()
          return true
        } catch {
          try await checkEventually(token)
          if case TunnelIntentError.busy = error {
            try await Task.sleep(nanoseconds: 50_000_000)
            continue
          }
          let nsError = error as NSError
          guard retry, nsError.domain == NEVPNErrorDomain,
            let code = NEVPNError.Code(rawValue: nsError.code),
            code == .configurationStale || code == .configurationInvalid
          else { throw error }
          retry = false
        }
      }
    } onCancel: {
      self.authority.cancel(token)
    }
  }

  private func awaitOperation<Value>(
    _ token: TunnelIntentAuthority.Token, _ operation: @escaping @MainActor () async throws -> Value
  ) async throws -> Value {
    let pending = IntentAwait<Value>()
    let authority = self.authority
    let isSafeMode = self.isSafeMode
    return try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        pending.continuation = continuation
        if Task.isCancelled {
          pending.finish(.failure(CancellationError()))
          return
        }
        pending.operation = Task {
          do {
            try await Self.checkEventually(token, authority: authority, isSafeMode: isSafeMode)
            pending.finish(.success(try await operation()))
          }
          catch { pending.finish(.failure(error)) }
        }
        pending.monitor = Task {
          while !Task.isCancelled {
            do { try await Task.sleep(nanoseconds: 250_000_000) } catch { return }
            do {
              try Self.check(token, authority: authority, isSafeMode: isSafeMode)
            } catch TunnelIntentError.busy {
              continue
            } catch {
              pending.finish(.failure(error))
              return
            }
          }
        }
      }
    } onCancel: {
      Task { @MainActor in pending.finish(.failure(CancellationError())) }
    }
  }

  private func checkSafety() throws {
    try Task.checkCancellation()
    guard !isSafeMode() else { throw TunnelIntentError.unsafe }
  }

  private static func check(
    _ token: TunnelIntentAuthority.Token, authority: TunnelIntentAuthority, isSafeMode: () -> Bool
  ) throws {
    try Task.checkCancellation()
    guard !isSafeMode() else { throw TunnelIntentError.unsafe }
    guard try authority.isCurrent(token) else { throw TunnelIntentError.superseded }
  }

  private func checkEventually(_ token: TunnelIntentAuthority.Token) async throws {
    try await Self.checkEventually(token, authority: authority, isSafeMode: isSafeMode)
  }

  private static func checkEventually(
    _ token: TunnelIntentAuthority.Token, authority: TunnelIntentAuthority, isSafeMode: () -> Bool
  ) async throws {
    while true {
      do { try check(token, authority: authority, isSafeMode: isSafeMode); return }
      catch TunnelIntentError.busy {
        try await Task.sleep(nanoseconds: 50_000_000)
      }
    }
  }

  private func stableStatus(
    _ observation: IntentCompletionObservation, token: TunnelIntentAuthority.Token
  ) async throws -> NEVPNStatus {
    let deadline = Date().addingTimeInterval(5)
    while observation.sample() == .disconnecting && !observation.isComplete {
      try await checkEventually(token)
      guard Date() < deadline else { throw TunnelIntentError.expired }
      try await Task.sleep(nanoseconds: 100_000_000)
    }
    try await checkEventually(token)
    return observation.sample()
  }
}
