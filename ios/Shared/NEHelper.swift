import Foundation
import NetworkExtension

public enum NEHelper {
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
  private static let client = TunnelIntentClient(
    authority: TunnelIntentAuthority(appGroup: appGroupIdentifier),
    loadManager: { try await loadManager() },
    isManaged: { isManagedManager($0) },
    isSafeMode: { isSafeMode }
  )

  @MainActor
  @discardableResult
  public static func start() async throws -> Bool { try await client.request(.start) }

  @MainActor
  @discardableResult
  public static func stop() async throws -> Bool { try await client.request(.stop) }

  @MainActor
  public static func toggle() async throws { _ = try await client.request(.toggle) }

  @MainActor
  public static func setRunning(_ running: Bool) async throws {
    _ = try await client.request(running ? .start : .stop)
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

}
