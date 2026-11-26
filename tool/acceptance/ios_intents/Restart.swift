import Foundation
import NetworkExtension
import Shared

@MainActor final class RestartStore: TunnelManagerAccess {
  let manager = NETunnelProviderManager()
  var loads = 0
  func loadManager(createIfNeeded: Bool) async throws -> NETunnelProviderManager? { loads += 1; return manager }
  func invalidateCachedManager(forPreferenceError error: Error) -> Bool { false }
  func applyNetworkExtensionOptions(to manager: NETunnelProviderManager, enableOnDemand: Bool) {}
  func isManagedConnection(_ connection: NEVPNConnection) -> Bool { connection === manager.connection }
  func isCachedConnection(_ connection: NEVPNConnection) -> Bool { connection === manager.connection }
}

@main struct RestartTests {
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
    let authority = TunnelIntentAuthority(directory: directory)
    let external = TunnelIntentAuthority(directory: directory)
    let store = RestartStore()
    let manager = store.manager
    manager.connection.status = .connected
    manager.connection.stopUpdatesStatus = mode != "external-stop" && mode != "toggle-during-stop"
    manager.pauseSave = false
    var externalStops = 0
    let coordinator = TunnelCoordinator(managerStore: store, authority: authority, isSafeMode: { false },
      onTunnelStateChanged: { _ in }, onConnectionStateChanged: { _ in },
      onExternalStart: {}, onExternalStop: { externalStops += 1 },
      restartHoldDuration: mode == "expired-then-toggle" ? 50_000_000 : 20_000_000_000)
    guard let stop = await coordinator.stopForFlutterRestart() else { fatalError("stop not accepted") }
    try await until { manager.connection.stops > 0 }
    if mode == "external-stop" || mode == "toggle-during-stop" {
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
      try await until { !coordinator.hasPendingWork }
      try await Task.sleep(nanoseconds: 150_000_000)
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
    } else if mode == "toggle-after-stop" {
      try await until { !coordinator.hasPendingWork }
      let previousLoads = store.loads
      coordinator.requestStatusRefresh(notifyExternal: true)
      try await until { store.loads > previousLoads }
      try await Task.sleep(nanoseconds: 50_000_000)
      precondition(externalStops == 0)
      let newer = try external.register(.toggle)
      let target = try external.resolve(newer, observedRunning: false)
      precondition(!target)
      precondition(coordinator.submitRegisteredIntent(newer))
      let result = await coordinator.startForFlutter(afterStop: stop)
      precondition(result == nil)
      try await until { !coordinator.hasPendingWork }
      precondition(manager.connection.starts == 0)
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
  }
}
