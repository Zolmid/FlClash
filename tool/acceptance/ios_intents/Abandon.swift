import Darwin
import Foundation
import NetworkExtension
import Shared

@MainActor final class AbandonStore: TunnelManagerAccess {
  let manager = NETunnelProviderManager()
  func loadManager(createIfNeeded: Bool) async throws -> NETunnelProviderManager? { manager }
  func invalidateCachedManager(forPreferenceError error: Error) -> Bool { false }
  func applyNetworkExtensionOptions(to manager: NETunnelProviderManager, enableOnDemand: Bool) {}
  func isManagedConnection(_ connection: NEVPNConnection) -> Bool { connection === manager.connection }
  func isCachedConnection(_ connection: NEVPNConnection) -> Bool { connection === manager.connection }
}

@main struct AbandonTests {
  @MainActor static func until(_ condition: () -> Bool) async throws {
    for _ in 0..<500 {
      if condition() { return }
      try await Task.sleep(nanoseconds: 5_000_000)
    }
    fatalError("fixture timeout")
  }

  @MainActor static func main() async throws {
    let mode = CommandLine.arguments[1]
    let directory = URL(fileURLWithPath: CommandLine.arguments[2])
    let authority = TunnelIntentAuthority(directory: directory)
    let store = AbandonStore()
    let manager = store.manager
    let coordinator = TunnelCoordinator(managerStore: store, authority: authority, isSafeMode: { false },
      onTunnelStateChanged: { _ in }, onConnectionStateChanged: { _ in },
      onExternalStart: {}, onExternalStop: {})
    func holdLock() -> Int32 {
      let descriptor = open(directory.appendingPathComponent("intent.lock").path, O_RDWR)
      precondition(descriptor >= 0 && flock(descriptor, LOCK_EX | LOCK_NB) == 0)
      return descriptor
    }
    var external: TunnelIntentAuthority.Token?
    if mode != "never" {
      let admitted = await coordinator.submitTunnelRequest(target: .running)
      precondition(admitted)
      try await until { !manager.saveCallbacks.isEmpty }
    }
    switch mode {
    case "unadmitted":
      let descriptor = holdLock()
      let obsolete = Task { await coordinator.submitTunnelRequest(target: .running) }
      try await Task.sleep(nanoseconds: 100_000_000)
      flock(descriptor, LOCK_UN)
      close(descriptor)
      external = try authority.register(.start)
      let obsoleteAdmitted = await obsolete.value
      precondition(!obsoleteAdmitted)
    case "superseded":
      external = try authority.register(.start)
    case "finished":
      manager.saveCallbacks.removeFirst()(nil)
      try await until { manager.connection.starts == 1 }
      manager.connection.status = .connected
      coordinator.handleTunnelStatusNotification(
        Notification(name: .NEVPNStatusDidChange, object: manager.connection))
      try await until { !coordinator.hasPendingWork }
    default:
      break
    }
    var descriptor: Int32 = -1
    if mode == "busy" { descriptor = holdLock() }
    let abandoning = Task { await coordinator.abandonStart() }
    if mode == "busy" {
      try await Task.sleep(nanoseconds: 120_000_000)
      flock(descriptor, LOCK_UN)
      close(descriptor)
    }
    let outcome = await abandoning.value
    print("OBSERVED \(mode) outcome=\(outcome.rawValue) stops=\(manager.connection.stops)")
    fflush(stdout)
    if mode == "never" {
      precondition(outcome == .notOwned && manager.connection.stops == 0)
      precondition(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("intent.json").path))
    } else if let external {
      let survived = try authority.isCurrent(external)
      precondition(outcome == .notOwned && survived)
      try await Task.sleep(nanoseconds: 150_000_000)
      let stillCurrent = try authority.isCurrent(external)
      precondition(stillCurrent && manager.connection.stops == 0)
    } else {
      precondition(outcome == .stopped)
      try await until { manager.connection.stops == 1 }
      let repeated = await coordinator.abandonStart()
      precondition(repeated == .notOwned)
    }
    print("PASS: abandonStart \(mode); starts=\(manager.connection.starts) stops=\(manager.connection.stops)")
  }
}
