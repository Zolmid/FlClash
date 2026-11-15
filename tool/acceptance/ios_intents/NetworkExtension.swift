import Foundation

public enum NEVPNStatus: Int { case invalid, disconnected, connecting, connected, reasserting, disconnecting }
public extension Notification.Name {
  static let NEVPNStatusDidChange = Notification.Name("NEVPNStatusDidChangeNotification")
}
public let NEVPNErrorDomain = "NEVPNErrorDomain"
public enum NEVPNError { public enum Code: Int { case configurationInvalid = 1, configurationStale = 2, configurationDisabled = 3 } }
public class NEVPNProtocol { public init() {} }
public final class NETunnelProviderProtocol: NEVPNProtocol {
  public var providerBundleIdentifier: String?
  public override init() { super.init() }
}
public final class NEVPNConnection: NSObject {
  public var status: NEVPNStatus = .disconnected
  public weak var manager: NETunnelProviderManager!
  public var starts = 0
  public var stops = 0
  public var startUpdatesStatus = true
  public var stopUpdatesStatus = true
  public var startError: Error?
  public var onStart: (() -> Void)?
  public var onStop: (() -> Void)?
  public func startVPNTunnel() throws {
    if let error = startError { throw error }
    starts += 1
    if startUpdatesStatus { status = .connecting }
    onStart?()
  }
  public func stopVPNTunnel() {
    stops += 1
    if stopUpdatesStatus { status = .disconnected }
    onStop?()
  }
}
public final class NETunnelProviderManager {
  public static var manager: NETunnelProviderManager?
  public static var pauseLoad = false
  public static var loadCount = 0
  public static var loadCallbacks: [(Error?) -> Void] = []
  public let connection = NEVPNConnection()
  public var protocolConfiguration: NEVPNProtocol?
  public var isEnabled = false
  public var isOnDemandEnabled = false
  public var onDemandRules: [Int]?
  public var pauseSave = true
  public var pauseReload = false
  public var saves = 0
  public var reloads = 0
  public var saveCallbacks: [@Sendable (Error?) -> Void] = []
  public var reloadCallbacks: [@Sendable (Error?) -> Void] = []
  public static func loadAllFromPreferences() async throws -> [NETunnelProviderManager] {
    loadCount += 1
    if pauseLoad {
      try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
        loadCallbacks.append { error in
          if let error { continuation.resume(throwing: error) } else { continuation.resume() }
        }
      }
    }
    return manager.map { [$0] } ?? []
  }
  public func saveToPreferences(completionHandler: @escaping @Sendable (Error?) -> Void) {
    saves += 1
    if pauseSave { saveCallbacks.append(completionHandler) } else { completionHandler(nil) }
  }
  public func loadFromPreferences(completionHandler: @escaping @Sendable (Error?) -> Void) {
    reloads += 1
    if pauseReload { reloadCallbacks.append(completionHandler) } else { completionHandler(nil) }
  }
  public func saveToPreferences() async throws {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      saveToPreferences { error in
        if let error { continuation.resume(throwing: error) } else { continuation.resume() }
      }
    }
  }
  public func loadFromPreferences() async throws {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      loadFromPreferences { error in
        if let error { continuation.resume(throwing: error) } else { continuation.resume() }
      }
    }
  }
  public init() { connection.manager = self }
}
