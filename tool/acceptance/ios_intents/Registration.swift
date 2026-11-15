import Darwin
import Foundation
import NetworkExtension
import Shared

final class Store { var isSafeMode = false }
@MainActor final class RegistrationStore: TunnelManagerAccess {
  let manager = NETunnelProviderManager()
  func loadManager(createIfNeeded: Bool) async throws -> NETunnelProviderManager? { manager }
  func invalidateCachedManager(forPreferenceError error: Error) -> Bool { false }
  func applyNetworkExtensionOptions(to manager: NETunnelProviderManager, enableOnDemand: Bool) {}
  func isManagedConnection(_ connection: NEVPNConnection) -> Bool { connection === manager.connection }
  func isCachedConnection(_ connection: NEVPNConnection) -> Bool { connection === manager.connection }
}
@MainActor final class Controller {
  let store = RegistrationStore()
  lazy var coordinator = TunnelCoordinator(managerStore: store,
    authority: ServiceChannel.quickActionAuthority, isSafeMode: { false },
    onTunnelStateChanged: { _ in }, onConnectionStateChanged: { _ in },
    onExternalStart: {}, onExternalStop: {})
  func submitRegisteredIntent(_ token: TunnelIntentAuthority.Token) -> Bool {
    coordinator.submitRegisteredIntent(token)
  }
}

@main struct RegistrationTests {
  struct Snapshot: Decodable { let token: TunnelIntentAuthority.Token }
  static func check(_ value: Bool) { precondition(value) }
  @MainActor static func until(_ condition: () -> Bool) async throws {
    for _ in 0..<500 {
      if condition() { return }
      try await Task.sleep(nanoseconds: 5_000_000)
    }
    fatalError("fixture timeout")
  }

  @MainActor static func main() async throws {
    let parts = CommandLine.arguments[1].split(separator: "-")
    let lane = String(parts[0])
    let mode = String(parts[1])
    let directory = URL(fileURLWithPath: CommandLine.arguments[2])
    let authority = ServiceChannel.quickActionAuthority
    let controller = Controller()
    let manager = controller.store.manager
    let client = TunnelIntentClient(authority: TunnelIntentAuthority(directory: directory), loadManager: { manager },
      isManaged: { _ in true }, isSafeMode: { false })
    let service = ServiceChannel(controller: controller)
    func request(_ command: TunnelIntentAuthority.Command, entry: String? = nil) async -> Bool {
      switch entry ?? lane {
      case "runner": return await controller.coordinator.submitTunnelRequest(target: command == .start ? .running : .stopped)
      case "queue": return await ServiceChannel.request(command == .start ? .start : .stop)
      default:
        do { return try await client.request(command) } catch { return false }
      }
    }
    let original = Task { await request(.start) }
    if lane == "queue" { check(await original.value) }
    else { try await until { !manager.saveCallbacks.isEmpty } }
    let accepted = try JSONDecoder().decode(Snapshot.self,
      from: Data(contentsOf: directory.appendingPathComponent("intent.json"))).token
    var descriptor: Int32 = -1
    if mode == "io" { precondition(chmod(directory.path, 0o500) == 0) }
    else {
      descriptor = open(directory.appendingPathComponent("intent.lock").path, O_RDWR)
      precondition(descriptor >= 0 && flock(descriptor, LOCK_EX | LOCK_NB) == 0)
    }
    let nextLane = mode == "cross" ? (lane == "runner" ? "shared" : lane == "shared" ? "queue" : "runner") : lane
    let began = Date()
    var returned = false
    let waiting = Task { let result = await request(mode == "later" || mode == "cross" ? .start : .stop); returned = true; return result }
    try await Task.sleep(nanoseconds: 100_000_000)
    let premature = returned
    var newest: Task<Bool, Never>?
    if mode == "later" || mode == "cross" {
      newest = Task { await request(.stop, entry: nextLane) }
      try await Task.sleep(nanoseconds: 100_000_000)
    }
    if mode == "cancel" { waiting.cancel() }
    var result: Bool?
    if mode == "timeout" || mode == "io" { result = await waiting.value }
    if mode == "io" { precondition(chmod(directory.path, 0o700) == 0) }
    else { flock(descriptor, LOCK_UN); close(descriptor) }
    var external: TunnelIntentAuthority.Token?
    if mode == "external" { external = try authority.register(.start) }
    let outcome: Bool
    if let result { outcome = result } else { outcome = await waiting.value }
    if mode == "short" {
      print("OBSERVED \(lane) short premature=\(premature) accepted=\(outcome)")
      fflush(stdout)
      precondition(!premature && outcome)
    } else if mode == "later" || mode == "cross" {
      let latest = await newest!.value
      print("OBSERVED \(lane) later obsolete=\(outcome) latest=\(latest)")
      fflush(stdout)
      precondition(!outcome && latest)
    } else if mode == "external" {
      check(try !outcome && authority.isCurrent(external!))
    } else {
      check(try !outcome && authority.isCurrent(accepted))
      if mode == "timeout" { precondition(Date().timeIntervalSince(began) >= 0.9) }
      if lane == "queue" { precondition(ServiceChannel.pendingQuickAction.token == accepted) }
    }
    if lane == "queue" || nextLane == "queue" {
      ServiceChannel.instance = service
      service.initialize()
    }
    if mode == "short" || mode == "later" || mode == "cross" {
      try await until { manager.connection.stops == 1 }
      for callback in manager.saveCallbacks { callback(nil) }
      manager.saveCallbacks.removeAll()
      _ = await original.value
      precondition(manager.connection.starts == 0)
    } else if mode == "external" {
      try authority.finish(external!)
      for callback in manager.saveCallbacks { callback(nil) }
      manager.saveCallbacks.removeAll()
      _ = await original.value
      precondition(manager.connection.starts == 0 && manager.connection.stops == 0)
    } else {
      try await until { !manager.saveCallbacks.isEmpty }
      manager.saveCallbacks.removeFirst()(nil)
      _ = await original.value
      try await until { manager.connection.starts == 1 }
      manager.connection.status = .connected
      NotificationCenter.default.post(name: .NEVPNStatusDidChange, object: manager.connection)
      controller.coordinator.handleTunnelStatusNotification(Notification(name: .NEVPNStatusDidChange, object: manager.connection))
      precondition(manager.connection.stops == 0)
    }
    try await until { !controller.coordinator.hasPendingWork && service.quickActionDrain == nil }
    print("PASS: actual \(lane) entry \(mode); starts=\(manager.connection.starts) stops=\(manager.connection.stops); work drained")
  }
}
