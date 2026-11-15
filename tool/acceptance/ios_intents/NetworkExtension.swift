import Foundation

public enum NEVPNStatus { case invalid, disconnected, connecting, connected, reasserting, disconnecting }
public let NEVPNErrorDomain = "NEVPNErrorDomain"
public enum NEVPNError { public enum Code: Int { case configurationInvalid = 1, configurationStale = 2, configurationDisabled = 3 } }
public class NEVPNProtocol { public init() {} }
public final class NETunnelProviderProtocol: NEVPNProtocol { public var providerBundleIdentifier: String?; public override init() { super.init() } }
public final class NEVPNConnection {
  public var status: NEVPNStatus = .disconnected
  public var starts = 0
  public var stops = 0
  public func startVPNTunnel() throws { starts += 1; status = .connecting }
  public func stopVPNTunnel() { stops += 1; status = .disconnected }
}
public final class NETunnelProviderManager {
  @MainActor public static var manager: NETunnelProviderManager?
  @MainActor public static var saveContinuation: CheckedContinuation<Void, Error>?
  @MainActor public static var reloadContinuation: CheckedContinuation<Void, Error>?
  @MainActor public static var pauseReload = false
  @MainActor public static var pauseLoad = false
  @MainActor public static var loadContinuation: CheckedContinuation<Void, Error>?
  @MainActor public static var loadCount = 0
  public let connection = NEVPNConnection()
  public var protocolConfiguration: NEVPNProtocol?
  public var isEnabled = false
  public var isOnDemandEnabled = false
  public var onDemandRules: [Int]?
  @MainActor public static func loadAllFromPreferences() async throws -> [NETunnelProviderManager] {
    loadCount += 1
    if pauseLoad { try await withCheckedThrowingContinuation { loadContinuation = $0 } }
    return manager.map { [$0] } ?? []
  }
  @MainActor public func saveToPreferences() async throws { try await withCheckedThrowingContinuation { Self.saveContinuation = $0 } }
  @MainActor public func loadFromPreferences() async throws {
    if Self.pauseReload { try await withCheckedThrowingContinuation { Self.reloadContinuation = $0 } }
  }
  public init() {}
}
