import Darwin
import Foundation
import NetworkExtension
import Shared

private final class RestartClock: @unchecked Sendable {
  private let lock = NSLock()
  private var time: UInt64 = 0

  func now() -> UInt64 { lock.withLock { time } }
  func advance(by duration: UInt64) { lock.withLock { time += duration } }
}

@MainActor final class RestartStore: TunnelManagerAccess {
  let manager = NETunnelProviderManager()
  var onLoad: (() -> Void)?
  func loadManager(createIfNeeded: Bool) async throws -> NETunnelProviderManager? {
    onLoad?()
    return manager
  }
  func invalidateCachedManager(forPreferenceError error: Error) -> Bool { false }
  func applyNetworkExtensionOptions(to manager: NETunnelProviderManager, enableOnDemand: Bool) {}
  func isManagedConnection(_ connection: NEVPNConnection) -> Bool { connection === manager.connection }
  func isCachedConnection(_ connection: NEVPNConnection) -> Bool { connection === manager.connection }
}

@main struct RestartTests {
  private static let hold: UInt64 = 20_000_000_000

  @MainActor static func until(_ condition: () -> Bool) async throws {
    for _ in 0..<1000 {
      if condition() { return }
      try await Task.sleep(nanoseconds: 5_000_000)
    }
    fatalError("restart fixture timeout")
  }

  @MainActor static func main() async throws {
    let mode = CommandLine.arguments[1]
    let directory = URL(fileURLWithPath: CommandLine.arguments[2])
    let clock = RestartClock()
    let authority = TunnelIntentAuthority(directory: directory, now: { clock.now() })
    let external = TunnelIntentAuthority(directory: directory, now: { clock.now() })
    let store = RestartStore()
    let manager = store.manager
    manager.connection.status = .connected
    manager.connection.stopUpdatesStatus =
      !["external-stop", "toggle-during-stop", "expired-then-toggle"].contains(mode)
    manager.pauseSave = false
    var externalStops = 0
    let coordinator = TunnelCoordinator(managerStore: store, authority: authority, isSafeMode: { false },
      onTunnelStateChanged: { _ in }, onConnectionStateChanged: { _ in },
      onExternalStart: {}, onExternalStop: { externalStops += 1 },
      restartHoldDuration: hold)
    guard let stop = await coordinator.stopForFlutterRestart() else { fatalError("stop not accepted") }
    let receipt = TunnelIntentAuthority.Token(id: UUID(uuidString: stop)!)
    try await until { manager.connection.stops > 0 }
    if mode == "external-stop" || mode == "toggle-during-stop" {
      clock.advance(by: hold + 1)
      var prepared = false
      let restarting = Task { await coordinator.startForFlutter(afterStop: stop) { prepared = true; return true } }
      let newer = try external.register(mode == "external-stop" ? .stop : .toggle)
      if mode == "toggle-during-stop" {
        let target = try external.resolve(newer, observedRunning: true)
        precondition(!target)
      }
      precondition(coordinator.submitRegisteredIntent(newer))
      manager.connection.status = .disconnected
      coordinator.handleTunnelStatusNotification(Notification(name: .NEVPNStatusDidChange, object: manager.connection))
      let result = await restarting.value
      precondition(result == nil)
      precondition(!prepared)
      try await until { !coordinator.hasPendingWork }
      precondition(manager.connection.starts == 0)
      let latest = try external.isLatest(newer)
      precondition(latest)
    } else if mode == "expired-then-toggle" {
      clock.advance(by: hold + 1)
      let inFlight = try external.isLatest(receipt)
      precondition(inFlight)
      try expectSuperseded { _ = try external.register(.start, replacing: receipt) }
      manager.connection.status = .disconnected
      coordinator.handleTunnelStatusNotification(Notification(name: .NEVPNStatusDidChange, object: manager.connection))
      try await until { !coordinator.hasPendingWork }
      clock.advance(by: hold - 1)
      let stillHeld = try external.isLatest(receipt)
      precondition(stillHeld)

      var prepared = false
      store.onLoad = { clock.advance(by: 1) }
      let staleResult = await coordinator.startForFlutter(afterStop: stop) { prepared = true; return true }
      store.onLoad = nil
      precondition(staleResult == nil && !prepared && manager.saves == 0)
      let expired = try !external.isLatest(receipt)
      precondition(expired)
      try expectSuperseded { _ = try external.register(.start, replacing: receipt) }
      do {
        try external.perform(receipt, running: false) { () -> Void in fatalError("expired stop dispatched") }
        fatalError("expired stop accepted")
      } catch TunnelIntentError.expired {}

      let newer = try external.register(.toggle)
      let target = try external.resolve(newer, observedRunning: false)
      precondition(target)
      precondition(coordinator.submitRegisteredIntent(newer))
      let result = await coordinator.startForFlutter(afterStop: stop)
      precondition(result == nil)
      try await until { manager.connection.starts == 1 }
      manager.connection.status = .connected
      coordinator.handleTunnelStatusNotification(Notification(name: .NEVPNStatusDidChange, object: manager.connection))
      try await until { !coordinator.hasPendingWork }
      try await checkRestartReceiptLifetime(authority, external, clock, directory, coordinator, manager,
        externalStops: { externalStops })
    } else if mode == "toggle-after-stop" {
      try await until { !coordinator.hasPendingWork }
      clock.advance(by: hold - 1)
      coordinator.requestStatusRefresh(notifyExternal: true)
      try await until { !coordinator.hasPendingWork }
      precondition(externalStops == 0)
      let newer = try external.register(.toggle)
      let target = try external.resolve(newer, observedRunning: false)
      precondition(!target)
      precondition(coordinator.submitRegisteredIntent(newer))
      let result = await coordinator.startForFlutter(afterStop: stop)
      precondition(result == nil)
      try await until { !coordinator.hasPendingWork }
      precondition(manager.connection.starts == 0)
      try await until { externalStops > 0 }
      precondition(externalStops == 1)
    } else if mode == "external-during-start" || mode == "toggle-during-start" {
      try await until { !coordinator.hasPendingWork }
      precondition(externalStops == 0)
      manager.pauseSave = true
      guard await coordinator.startForFlutter(afterStop: stop) != nil else { fatalError("restart not accepted") }
      try await until { !manager.saveCallbacks.isEmpty }
      let newer = try external.register(mode == "external-during-start" ? .stop : .toggle)
      if mode == "toggle-during-start" {
        let target = try external.resolve(newer, observedRunning: false)
        precondition(!target)
      }
      precondition(coordinator.submitRegisteredIntent(newer))
      let callbacks = manager.saveCallbacks
      manager.saveCallbacks.removeAll()
      for callback in callbacks { callback(nil) }
      try await until { !coordinator.hasPendingWork }
      precondition(manager.connection.starts == 0)
      let latest = try external.isLatest(newer)
      precondition(latest)
    } else {
      try await until { !coordinator.hasPendingWork }
      var prepared = false
      guard await coordinator.startForFlutter(afterStop: stop, prepare: { prepared = true; return true }) != nil else { fatalError("restart not accepted") }
      precondition(prepared)
      try await until { manager.connection.starts == 1 }
      manager.connection.status = .connected
      coordinator.handleTunnelStatusNotification(Notification(name: .NEVPNStatusDidChange, object: manager.connection))
      try await until { !coordinator.hasPendingWork }
    }
    print("PASS: \(mode)")
  }

  private static func expectSuperseded(_ operation: () throws -> Void) throws {
    do {
      try operation()
      fatalError("obsolete restart receipt accepted")
    } catch TunnelIntentError.superseded {}
  }

  @MainActor private static func checkRestartReceiptLifetime(
    _ authority: TunnelIntentAuthority, _ external: TunnelIntentAuthority, _ clock: RestartClock,
    _ directory: URL, _ coordinator: TunnelCoordinator, _ manager: NETunnelProviderManager,
    externalStops: () -> Int
  ) async throws {
    manager.connection.stopUpdatesStatus = false
    let previousStops = manager.connection.stops
    guard let handle = await coordinator.stopForFlutterRestart() else { fatalError("stop not accepted") }
    try await until { manager.connection.stops > previousStops }
    let file = directory.appendingPathComponent("intent.json")
    let descriptor = open(directory.appendingPathComponent("intent.lock").path, O_RDWR)
    precondition(descriptor >= 0)
    defer { close(descriptor) }
    precondition(flock(descriptor, LOCK_EX | LOCK_NB) == 0)
    manager.connection.status = .disconnected
    coordinator.handleTunnelStatusNotification(Notification(name: .NEVPNStatusDidChange, object: manager.connection))
    clock.advance(by: hold)
    precondition(flock(descriptor, LOCK_UN) == 0)
    try await until { !coordinator.hasPendingWork }
    precondition(manager.connection.stops == previousStops + 1)
    let token = TunnelIntentAuthority.Token(id: UUID(uuidString: handle)!)
    let expired = try !external.isLatest(token)
    precondition(expired)
    let previousCallbacks = externalStops()
    coordinator.requestStatusRefresh(notifyExternal: true)
    try await until { !coordinator.hasPendingWork }
    precondition(externalStops() == previousCallbacks + 1)

    let dead = try authority.register(.restartStop)
    try authority.completeRestartStop(dead, deadline: authority.restartStopDeadline(after: hold))
    authority.cancel(dead)
    try expectSuperseded { _ = try external.register(.start, replacing: dead) }
    let deadToggle = try external.register(.toggle)
    let startsAfterDeath = try external.resolve(deadToggle, observedRunning: false)
    precondition(startsAfterDeath)

    let legacy = try authority.register(.restartStop)
    var record = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as! [String: Any]
    record["version"] = 2
    try JSONSerialization.data(withJSONObject: record).write(to: file, options: [.atomic])
    try expectSuperseded { _ = try external.register(.start, replacing: legacy) }
    let legacyToggle = try external.register(.toggle)
    let startsAfterLegacy = try external.resolve(legacyToggle, observedRunning: false)
    precondition(startsAfterLegacy)
  }
}
