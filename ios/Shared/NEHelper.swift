import Foundation
import NetworkExtension

public enum NEHelper {
  @MainActor private static var intentGeneration: UInt64 = 0
  private enum PendingIntent {
    case target(Bool)
    case toggle(Bool)
  }
  @MainActor private static var pendingIntent: PendingIntent?

  @MainActor private static func beginIntent(_ intent: PendingIntent) -> UInt64 {
    intentGeneration &+= 1
    pendingIntent = intent
    return intentGeneration
  }

  @MainActor private static func isCurrent(_ generation: UInt64) -> Bool {
    generation == intentGeneration && !Task.isCancelled && !isSafeMode
  }

  @MainActor private static func finishIntent(_ generation: UInt64) {
    if generation == intentGeneration { pendingIntent = nil }
  }

  private static var appBundleId: String {
    let bundleId = Bundle.main.bundleIdentifier!
    for suffix in [".NECore", ".Widget"] where bundleId.hasSuffix(suffix) {
      return String(bundleId.dropLast(suffix.count))
    }
    return bundleId
  }

  public static var appGroupIdentifier: String { "group.\(appBundleId)" }
  public static var widgetIdentifier: String { "\(appBundleId).Widget" }
  public static var providerBundleIdentifier: String {
    "\(appBundleId).NECore"
  }

  private static var isSafeMode: Bool {
    UserDefaults(suiteName: appGroupIdentifier)?.bool(forKey: "safeMode") ?? false
  }

  @MainActor
  public static func loadManager() async throws -> NETunnelProviderManager? {
    let managers = try await NETunnelProviderManager.loadAllFromPreferences()
    return managers.first(where: isManagedManager)
  }

  public static func isRunning(_ status: NEVPNStatus) -> Bool {
    [.connecting, .connected, .reasserting].contains(status)
  }

  @MainActor
  @discardableResult
  public static func start() async throws -> Bool {
    guard !isSafeMode else {
      return false
    }
    let generation = beginIntent(.target(true))
    defer { finishIntent(generation) }
    return try await startWithPreferenceRetry(initialManager: nil, generation: generation)
  }

  @MainActor
  private static func startWithPreferenceRetry(
    initialManager: NETunnelProviderManager?, generation: UInt64
  ) async throws -> Bool {
    var manager = initialManager
    var allowPreferenceRetry = true
    while isCurrent(generation) {
      if manager == nil {
        manager = try await loadManager()
      }
      guard isCurrent(generation), let currentManager = manager else {
        return false
      }
      do {
        return try await start(manager: currentManager, generation: generation)
      } catch {
        guard isCurrent(generation) else { return false }
        guard allowPreferenceRetry,
          isRetryablePreferenceError(error)
        else {
          throw error
        }
        allowPreferenceRetry = false
        manager = nil
      }
    }
    return false
  }

  @MainActor
  @discardableResult
  public static func stop() async throws -> Bool {
    guard !isSafeMode else {
      return false
    }
    let generation = beginIntent(.target(false))
    defer { finishIntent(generation) }
    guard let manager = try await loadManager(), isCurrent(generation) else {
      return false
    }
    stop(manager: manager)
    return true
  }

  @MainActor
  public static func toggle() async throws {
    guard !isSafeMode else {
      return
    }
    let intent: PendingIntent
    switch pendingIntent {
    case .target(let target): intent = .target(!target)
    case .toggle(let invert): intent = .toggle(!invert)
    case nil: intent = .toggle(true)
    }
    let generation = beginIntent(intent)
    defer { finishIntent(generation) }
    guard let manager = try await loadManager(), isCurrent(generation) else {
      return
    }
    let target: Bool
    switch intent {
    case .target(let value): target = value
    case .toggle(let invert): target = isRunning(manager.connection.status) != invert
    }
    pendingIntent = .target(target)
    if target {
      _ = try await startWithPreferenceRetry(initialManager: manager, generation: generation)
    } else {
      stop(manager: manager)
    }
  }

  @MainActor
  public static func setRunning(_ running: Bool) async throws {
    if running {
      _ = try await start()
    } else {
      _ = try await stop()
    }
  }

  @MainActor
  private static func start(
    manager: NETunnelProviderManager, generation: UInt64
  ) async throws -> Bool {
    var status = manager.connection.status
    if status == .disconnecting {
      status = try await waitForStableStatus(manager: manager)
    }
    guard isCurrent(generation) else { return false }
    if isRunning(status) {
      return true
    }

    manager.isEnabled = true
    if let rules = manager.onDemandRules, !rules.isEmpty {
      manager.isOnDemandEnabled = true
    }
    try await manager.saveToPreferences()
    guard isCurrent(generation) else { return false }
    try await manager.loadFromPreferences()
    guard isCurrent(generation) else { return false }

    status = manager.connection.status
    if status == .disconnecting {
      status = try await waitForStableStatus(manager: manager)
    }
    guard isCurrent(generation) else { return false }
    if isRunning(status) {
      return true
    }
    try manager.connection.startVPNTunnel()
    return true
  }

  @MainActor
  private static func stop(manager: NETunnelProviderManager) {
    guard isRunning(manager.connection.status) else {
      return
    }
    manager.connection.stopVPNTunnel()
  }

  @MainActor
  private static func waitForStableStatus(
    manager: NETunnelProviderManager
  ) async throws -> NEVPNStatus {
    let deadline = Date().addingTimeInterval(5)
    var status = manager.connection.status
    while status == .disconnecting && Date() < deadline {
      try await Task.sleep(nanoseconds: 100_000_000)
      status = manager.connection.status
    }
    guard status != .disconnecting else {
      throw NEHelperError.transitionTimedOut
    }
    return status
  }

  private static func isManagedManager(
    _ manager: NETunnelProviderManager
  ) -> Bool {
    guard
      let proto = manager.protocolConfiguration
        as? NETunnelProviderProtocol
    else {
      return false
    }
    return proto.providerBundleIdentifier == providerBundleIdentifier
  }

  private static func isRetryablePreferenceError(_ error: Error) -> Bool {
    let error = error as NSError
    guard error.domain == NEVPNErrorDomain,
      let code = NEVPNError.Code(rawValue: error.code)
    else {
      return false
    }
    switch code {
    case .configurationInvalid, .configurationStale:
      return true
    default:
      return false
    }
  }
}

private enum NEHelperError: LocalizedError {
  case transitionTimedOut

  var errorDescription: String? {
    "Network Extension transition timed out"
  }
}
