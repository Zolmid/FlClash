import Foundation
import NetworkExtension

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
      defer { if !issued { try? authority.finish(token) } }
      var retry = true
      while true {
        do {
          try check(token)
          guard let manager = try await loadManager() else { return false }
          try check(token)
          guard isManaged(manager) else { return false }
          let running = try authority.resolve(token, observedRunning: NEHelper.isRunning(manager.connection.status))
          if !running {
            try authority.perform(token, running: false) {
              try checkSafety()
              guard isManaged(manager) else { throw TunnelIntentError.unsafe }
              manager.connection.stopVPNTunnel()
            }
            issued = true
            return true
          }
          var status = try await stableStatus(manager, token: token)
          if NEHelper.isRunning(status) {
            issued = status == .connecting
            return true
          }
          try check(token)
          manager.isEnabled = true
          if let rules = manager.onDemandRules, !rules.isEmpty { manager.isOnDemandEnabled = true }
          try await manager.saveToPreferences()
          try check(token)
          try await manager.loadFromPreferences()
          try check(token)
          status = try await stableStatus(manager, token: token)
          if NEHelper.isRunning(status) {
            issued = status == .connecting
            return true
          }
          try authority.perform(token, running: true) {
            try checkSafety()
            guard isManaged(manager) else { throw TunnelIntentError.unsafe }
            try manager.connection.startVPNTunnel()
          }
          issued = true
          return true
        } catch {
          try check(token)
          let nsError = error as NSError
          guard retry, nsError.domain == NEVPNErrorDomain,
            let code = NEVPNError.Code(rawValue: nsError.code),
            code == .configurationStale || code == .configurationInvalid
          else { throw error }
          retry = false
        }
      }
    } onCancel: {
      try? self.authority.finish(token)
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

  private func stableStatus(
    _ manager: NETunnelProviderManager, token: TunnelIntentAuthority.Token
  ) async throws -> NEVPNStatus {
    let deadline = Date().addingTimeInterval(5)
    while manager.connection.status == .disconnecting {
      try check(token)
      guard Date() < deadline else { throw TunnelIntentError.expired }
      try await Task.sleep(nanoseconds: 100_000_000)
    }
    try check(token)
    return manager.connection.status
  }
}
