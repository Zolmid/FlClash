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

@MainActor
public final class TunnelIntentClient {
  private let authority: TunnelIntentAuthority
  private let loadManager: () async throws -> NETunnelProviderManager?
  private let isManaged: (NETunnelProviderManager) -> Bool
  private let isSafeMode: () -> Bool

  public init(
    authority: TunnelIntentAuthority,
    loadManager: @escaping () async throws -> NETunnelProviderManager?,
    isManaged: @escaping (NETunnelProviderManager) -> Bool,
    isSafeMode: @escaping () -> Bool
  ) {
    self.authority = authority
    self.loadManager = loadManager
    self.isManaged = isManaged
    self.isSafeMode = isSafeMode
  }

  @discardableResult
  public func request(_ command: TunnelIntentAuthority.Command) async throws -> Bool {
    guard !isSafeMode() else { return false }
    try Task.checkCancellation()
    let token = try authority.register(command)
    return try await withTaskCancellationHandler {
      var issued = false
      defer {
        if !issued {
          do { try authority.finish(token) } catch { authority.cancel(token) }
        }
      }
      var retry = true
      while true {
        do {
          try await checkEventually(token)
          guard let manager = try await awaitOperation(token, { try await self.loadManager() }) else { return false }
          try await checkEventually(token)
          guard isManaged(manager) else { return false }
          let running = try authority.resolve(token, observedRunning: NEHelper.isRunning(manager.connection.status))
          if !running {
            try authority.perform(token, running: false) {
              try checkSafety()
              guard isManaged(manager) else { throw TunnelIntentError.unsafe }
              manager.connection.stopVPNTunnel()
            }
            if manager.connection.status == .disconnected || manager.connection.status == .invalid {
              try authority.finish(token)
            } else {
              issued = true
              observeCompletion(manager, token: token, target: false)
            }
            return true
          }
          var status = try await stableStatus(manager, token: token)
          if NEHelper.isRunning(status) {
            issued = status == .connecting
            if issued { observeCompletion(manager, token: token, target: true) }
            return true
          }
          try await checkEventually(token)
          manager.isEnabled = true
          if let rules = manager.onDemandRules, !rules.isEmpty { manager.isOnDemandEnabled = true }
          try await awaitOperation(token) { try await manager.saveToPreferences() }
          try await checkEventually(token)
          try await awaitOperation(token) { try await manager.loadFromPreferences() }
          try await checkEventually(token)
          status = try await stableStatus(manager, token: token)
          if NEHelper.isRunning(status) {
            issued = status == .connecting
            if issued { observeCompletion(manager, token: token, target: true) }
            return true
          }
          try authority.perform(token, running: true) {
            try checkSafety()
            guard isManaged(manager) else { throw TunnelIntentError.unsafe }
            try manager.connection.startVPNTunnel()
          }
          issued = true
          observeCompletion(manager, token: token, target: true)
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
    return try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        pending.continuation = continuation
        if Task.isCancelled {
          pending.finish(.failure(CancellationError()))
          return
        }
        pending.operation = Task {
          do {
            try await checkEventually(token)
            pending.finish(.success(try await operation()))
          }
          catch { pending.finish(.failure(error)) }
        }
        pending.monitor = Task {
          while !Task.isCancelled {
            do { try await Task.sleep(nanoseconds: 250_000_000) } catch { return }
            do {
              try check(token)
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

  private func observeCompletion(
    _ manager: NETunnelProviderManager, token: TunnelIntentAuthority.Token, target: Bool
  ) {
    Task { @MainActor in
      var sawTransition = false
      while !Task.isCancelled {
        do {
          guard try authority.isCurrent(token) else { return }
          let status = manager.connection.status
          if status == .connecting || status == .disconnecting { sawTransition = true }
          if (target && (status == .connected || status == .reasserting)) ||
            (!target && (status == .disconnected || status == .invalid)) ||
            (target && sawTransition && (status == .disconnected || status == .invalid)) {
            try authority.finish(token)
            return
          }
        } catch TunnelIntentError.busy {
        } catch {
          authority.cancel(token)
          return
        }
        do { try await Task.sleep(nanoseconds: 250_000_000) } catch { return }
      }
    }
  }

  private func checkSafety() throws {
    try Task.checkCancellation()
    guard !isSafeMode() else { throw TunnelIntentError.unsafe }
  }

  private func check(_ token: TunnelIntentAuthority.Token) throws {
    try checkSafety()
    guard try authority.isCurrent(token) else { throw TunnelIntentError.superseded }
  }

  private func checkEventually(_ token: TunnelIntentAuthority.Token) async throws {
    while true {
      do { try check(token); return }
      catch TunnelIntentError.busy {
        try await Task.sleep(nanoseconds: 50_000_000)
      }
    }
  }

  private func stableStatus(
    _ manager: NETunnelProviderManager, token: TunnelIntentAuthority.Token
  ) async throws -> NEVPNStatus {
    let deadline = Date().addingTimeInterval(5)
    while manager.connection.status == .disconnecting {
      try await checkEventually(token)
      guard Date() < deadline else { throw TunnelIntentError.expired }
      try await Task.sleep(nanoseconds: 100_000_000)
    }
    try await checkEventually(token)
    return manager.connection.status
  }
}
