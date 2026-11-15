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
  static func check(_ value: Bool) { precondition(value) }

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
    func release(_ descriptor: Int32) { flock(descriptor, LOCK_UN); close(descriptor) }
    func finishConnecting() async throws {
      let saves = manager.saveCallbacks
      manager.saveCallbacks.removeAll()
      for callback in saves { callback(nil) }
      try await until { manager.connection.starts == 1 }
      manager.connection.status = .connected
      let notification = Notification(name: .NEVPNStatusDidChange, object: manager.connection)
      NotificationCenter.default.post(notification)
      coordinator.handleTunnelStatusNotification(notification)
      try await until { !coordinator.hasPendingWork }
    }

    var handle: String?
    var survivor: TunnelIntentAuthority.Token?
    var widget: Task<Bool, Error>?
    if mode != "never" {
      handle = await coordinator.startForFlutter()
      precondition(handle != nil)
      try await until { !manager.saveCallbacks.isEmpty }
    }
    switch mode {
    case "unadmitted":
      let descriptor = holdLock()
      let obsolete = Task { await coordinator.startForFlutter() }
      try await Task.sleep(nanoseconds: 100_000_000)
      release(descriptor)
      survivor = try authority.register(.start)
      handle = await obsolete.value
      precondition(handle == nil)
    case "superseded":
      survivor = try authority.register(.start)
    case "finished", "prior":
      try await finishConnecting()
      if mode == "prior" {
        survivor = TunnelIntentAuthority.Token(id: UUID(uuidString: handle!)!)
        handle = nil
      }
    case "same-runner":
      let newer = await coordinator.startForFlutter()
      precondition(newer != nil && newer != handle)
      survivor = TunnelIntentAuthority.Token(id: UUID(uuidString: newer!)!)
      try await until { manager.saveCallbacks.count == 2 }
    case "quick":
      let token = try authority.register(.start)
      precondition(coordinator.submitRegisteredIntent(token))
      survivor = token
      try await until { manager.saveCallbacks.count == 2 }
    case "widget":
      let client = TunnelIntentClient(authority: TunnelIntentAuthority(directory: directory),
        loadManager: { manager }, isManaged: { _ in true }, isSafeMode: { false })
      widget = Task { try await client.request(.start) }
      try await until { manager.saveCallbacks.count == 2 }
      struct Snapshot: Decodable { let token: TunnelIntentAuthority.Token }
      survivor = try JSONDecoder().decode(Snapshot.self,
        from: Data(contentsOf: directory.appendingPathComponent("intent.json"))).token
    default:
      break
    }
    var descriptor: Int32 = -1
    if ["busy", "busy-superseded", "cancel"].contains(mode) { descriptor = holdLock() }
    let cleanupHandle = handle
    let abandoning = Task { await coordinator.abandonStart(cleanupHandle) }
    if descriptor >= 0 {
      try await Task.sleep(nanoseconds: 120_000_000)
      if mode == "cancel" { abandoning.cancel() }
      release(descriptor)
      if mode == "busy-superseded" { survivor = try authority.register(.start) }
    }
    let outcome = await abandoning.value
    print("OBSERVED \(mode) outcome=\(outcome.rawValue) stops=\(manager.connection.stops)")
    fflush(stdout)
    if mode == "never" {
      precondition(outcome == .notOwned && manager.connection.stops == 0)
      precondition(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("intent.json").path))
    } else if let survivor {
      check(try outcome == .notOwned && authority.isLatest(survivor))
      precondition(manager.connection.stops == 0)
      if ["same-runner", "quick", "widget"].contains(mode) {
        try await finishConnecting()
        if let widget { check(try await widget.value) }
        check(try authority.isLatest(survivor))
        precondition(manager.connection.starts == 1 && manager.connection.stops == 0)
        if mode == "same-runner" {
          check(await coordinator.abandonStart(survivor.id.uuidString) == .stopped)
          try await until { manager.connection.stops == 1 }
        }
      } else {
        try authority.finish(survivor)
      }
    } else if mode == "cancel" {
      precondition(outcome == .failed && manager.connection.stops == 0)
      try await finishConnecting()
    } else {
      precondition(outcome == .stopped)
      try await until { manager.connection.stops == 1 }
      check(await coordinator.abandonStart(handle) == .notOwned)
    }
    for callback in manager.saveCallbacks { callback(nil) }
    manager.saveCallbacks.removeAll()
    try await until { !coordinator.hasPendingWork }
    print("PASS: abandonStart \(mode); starts=\(manager.connection.starts) stops=\(manager.connection.stops); work drained")
  }
}
