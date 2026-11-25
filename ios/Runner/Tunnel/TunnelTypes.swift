import Foundation
import NetworkExtension
import Shared

@MainActor
protocol TunnelManagerAccess {
  func loadManager(createIfNeeded: Bool) async throws -> NETunnelProviderManager?
  func invalidateCachedManager(forPreferenceError error: Error) -> Bool
  func applyNetworkExtensionOptions(to manager: NETunnelProviderManager, enableOnDemand: Bool)
  func isManagedConnection(_ connection: NEVPNConnection) -> Bool
  func isCachedConnection(_ connection: NEVPNConnection) -> Bool
}

enum TunnelTarget {
  case running
  case stopped

  var description: String {
    switch self {
    case .running:
      return "running"
    case .stopped:
      return "stopped"
    }
  }
}

enum StartAbandonment: String {
  case stopped, notOwned, failed
}

extension NEVPNStatus {
  var tunnelState: TunnelTarget? {
    switch self {
    case .connected, .reasserting:
      return .running
    case .disconnected, .invalid:
      return .stopped
    case .connecting, .disconnecting:
      return nil
    @unknown default:
      return nil
    }
  }

  var isLifecycleActive: Bool {
    tunnelState != .stopped
  }

  var isTerminal: Bool {
    tunnelState == .stopped
  }
}

final class TunnelRequest {
  let generation: UInt64
  let token: TunnelIntentAuthority.Token
  var target: TunnelTarget?
  var description: String { target?.description ?? "toggle" }
  var preferenceRetryCount = 0
  var cancelOperation: (() -> Void)?

  init(
    generation: UInt64,
    token: TunnelIntentAuthority.Token,
    target: TunnelTarget?
  ) {
    self.generation = generation
    self.token = token
    self.target = target
  }
}

enum TunnelWaitPurpose {
  case starting
  case stopping
  case settleThenStart

  var description: String {
    switch self {
    case .starting:
      return "starting"
    case .stopping:
      return "stopping"
    case .settleThenStart:
      return "settleThenStart"
    }
  }
}

enum TunnelWaitResult {
  case status(NEVPNStatus)
  case superseded
}

final class TunnelWait {
  let request: TunnelRequest
  let purpose: TunnelWaitPurpose
  let manager: NETunnelProviderManager
  let continuation: CheckedContinuation<TunnelWaitResult, Never>
  var hasObservedProgress = false
  var confirmation: Task<Void, Never>?

  init(
    request: TunnelRequest,
    purpose: TunnelWaitPurpose,
    manager: NETunnelProviderManager,
    continuation: CheckedContinuation<TunnelWaitResult, Never>
  ) {
    self.request = request
    self.purpose = purpose
    self.manager = manager
    self.continuation = continuation
  }
}

struct ProviderMessageError: Error {
  let code: String
  let message: String
}
