import Foundation
import NetworkExtension
import Shared

@main struct ClientTests {
  enum Failure: Error { case timeout, expectedRejection }
  @MainActor static func until(_ condition: () -> Bool) async throws {
    for _ in 0..<500 {
      if condition() { return }
      try await Task.sleep(nanoseconds: 2_000_000)
    }
    throw Failure.timeout
  }

  @MainActor static func main() async throws {
    let root = URL(fileURLWithPath: CommandLine.arguments[1])
    for phase in ["save-stop", "reload-toggle", "retry-stop", "cancel", "fail", "retry-once", "retry-limit", "repeat", "two-toggles", "safe", "safe-during-save", "authority-read-failure", "authority-write-failure", "foreign-manager", "slow-save"] {
      let directory = root.appendingPathComponent(phase)
      let authority = TunnelIntentAuthority(directory: directory)
      let manager = NETunnelProviderManager()
      NETunnelProviderManager.manager = manager
      NETunnelProviderManager.pauseLoad = false
      NETunnelProviderManager.loadCount = 0
      let suite = "org.example.IntentFixture.\(UUID().uuidString)"
      let defaults = UserDefaults(suiteName: suite)!
      defer { defaults.removePersistentDomain(forName: suite) }
      let client = TunnelIntentClient(authority: authority,
        loadManager: { try await NETunnelProviderManager.loadAllFromPreferences().first },
        isManaged: { _ in phase != "foreign-manager" },
        isSafeMode: { defaults.bool(forKey: "safeMode") })
      let other = TunnelIntentClient(authority: TunnelIntentAuthority(directory: directory),
        loadManager: { manager }, isManaged: { _ in true }, isSafeMode: { false })
      if phase == "safe" {
        defaults.set(true, forKey: "safeMode")
        let accepted = try await client.request(.start)
        precondition(!accepted && manager.saves == 0)
        precondition(!FileManager.default.fileExists(atPath: directory.path))
        print("PASS: Shared safe mode performs no authority or manager writes")
        continue
      }
      if phase == "foreign-manager" {
        let accepted = try await client.request(.start)
        precondition(!accepted && manager.saves == 0)
        _ = try await client.request(.stop)
        precondition(manager.connection.stops == 0)
        print("PASS: Shared excludes unrelated manager")
        continue
      }
      if phase == "two-toggles" {
        NETunnelProviderManager.pauseLoad = true
        let first = Task { try await client.request(.toggle) }
        try await until { NETunnelProviderManager.loadCallbacks.count == 1 }
        let second = Task { try await client.request(.toggle) }
        try await until { NETunnelProviderManager.loadCallbacks.count == 2 }
        NETunnelProviderManager.pauseLoad = false
        NETunnelProviderManager.loadCallbacks.removeFirst()(nil)
        NETunnelProviderManager.loadCallbacks.removeFirst()(nil)
        _ = await first.result
        _ = try await second.value
        precondition(manager.saves == 0 && manager.connection.starts == 0 && manager.connection.stops == 1)
        print("PASS: unresolved toggle parity survives awaits")
        continue
      }
      let starting = Task { try await client.request(.start) }
      try await until { !manager.saveCallbacks.isEmpty }
      var expectsSuccess = false
      switch phase {
      case "slow-save":
        try await Task.sleep(nanoseconds: 31_000_000_000)
        manager.saveCallbacks.removeFirst()(nil)
        expectsSuccess = true
      case "save-stop":
        _ = try await other.request(.stop)
        manager.saveCallbacks.removeFirst()(nil)
      case "reload-toggle":
        manager.pauseReload = true
        manager.saveCallbacks.removeFirst()(nil)
        try await until { !manager.reloadCallbacks.isEmpty }
        _ = try await other.request(.toggle)
        manager.reloadCallbacks.removeFirst()(nil)
      case "retry-stop":
        NETunnelProviderManager.pauseLoad = true
        manager.saveCallbacks.removeFirst()(NSError(domain: NEVPNErrorDomain, code: 2))
        try await until { !NETunnelProviderManager.loadCallbacks.isEmpty }
        _ = try await other.request(.stop)
        NETunnelProviderManager.pauseLoad = false
        NETunnelProviderManager.loadCallbacks.removeFirst()(nil)
      case "cancel":
        starting.cancel()
        manager.saveCallbacks.removeFirst()(nil)
      case "fail":
        manager.saveCallbacks.removeFirst()(NSError(domain: NEVPNErrorDomain, code: 3))
      case "retry-once", "retry-limit":
        manager.saveCallbacks.removeFirst()(NSError(domain: NEVPNErrorDomain, code: 2))
        try await until { !manager.saveCallbacks.isEmpty }
        manager.saveCallbacks.removeFirst()(phase == "retry-limit" ? NSError(domain: NEVPNErrorDomain, code: 2) : nil)
        expectsSuccess = phase == "retry-once"
      case "repeat":
        let second = Task { try await other.request(.start) }
        try await until { manager.saveCallbacks.count == 2 }
        manager.saveCallbacks.removeFirst()(nil)
        manager.saveCallbacks.removeFirst()(nil)
        _ = try await second.value
      case "authority-read-failure":
        try Data("invalid".utf8).write(to: directory.appendingPathComponent("intent.json"))
        manager.saveCallbacks.removeFirst()(nil)
      case "authority-write-failure":
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: directory.path)
        manager.saveCallbacks.removeFirst()(nil)
      case "safe-during-save":
        defaults.set(true, forKey: "safeMode")
        manager.saveCallbacks.removeFirst()(nil)
      default: fatalError()
      }
      let result = await starting.result
      if phase == "authority-write-failure" {
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
      }
      if expectsSuccess {
        _ = try result.get()
      } else if case .success = result { throw Failure.expectedRejection }
      precondition(manager.connection.starts == ((expectsSuccess || phase == "repeat") ? 1 : 0))
      if phase == "retry-once" || phase == "retry-limit" { precondition(NETunnelProviderManager.loadCount == 2) }
      print("PASS: Shared \(phase)")
    }
    let manager = NETunnelProviderManager()
    manager.pauseSave = false
    let directory = root.appendingPathComponent("connecting-repeat")
    let first = TunnelIntentClient(authority: TunnelIntentAuthority(directory: directory),
      loadManager: { manager }, isManaged: { _ in true }, isSafeMode: { false })
    let second = TunnelIntentClient(authority: TunnelIntentAuthority(directory: directory),
      loadManager: { manager }, isManaged: { _ in true }, isSafeMode: { false })
    _ = try await first.request(.start)
    _ = try await second.request(.start)
    manager.connection.status = .disconnected
    _ = try await first.request(.toggle)
    precondition(manager.connection.starts == 1 && manager.connection.stops == 1)
    print("PASS: repeat during connecting preserves pending target across stale status")

    let completedManager = NETunnelProviderManager()
    let completedClient = TunnelIntentClient(
      authority: TunnelIntentAuthority(directory: root.appendingPathComponent("completed-stop")),
      loadManager: { completedManager }, isManaged: { _ in true }, isSafeMode: { false })
    _ = try await completedClient.request(.stop)
    completedManager.connection.status = .connected
    _ = try await completedClient.request(.toggle)
    precondition(completedManager.connection.stops == 2 && completedManager.connection.starts == 0)
    print("PASS: completed stop does not override later observed connected status")

    let transitioning = NETunnelProviderManager()
    transitioning.connection.status = .connected
    transitioning.connection.stopUpdatesStatus = false
    let transitioningClient = TunnelIntentClient(
      authority: TunnelIntentAuthority(directory: root.appendingPathComponent("transitioning-stop")),
      loadManager: { transitioning }, isManaged: { _ in true }, isSafeMode: { false })
    _ = try await transitioningClient.request(.stop)
    _ = try await transitioningClient.request(.toggle)
    precondition(transitioning.connection.stops == 1 && transitioning.connection.starts == 0)
    print("PASS: toggle preserves an unfinished stop while status remains connected")

    for phase in ["cancel-without-callback", "supersede-without-callback"] {
      let delayed = NETunnelProviderManager()
      let directory = root.appendingPathComponent(phase)
      let client = TunnelIntentClient(authority: TunnelIntentAuthority(directory: directory),
        loadManager: { delayed }, isManaged: { _ in true }, isSafeMode: { false })
      let other = TunnelIntentClient(authority: TunnelIntentAuthority(directory: directory),
        loadManager: { delayed }, isManaged: { _ in true }, isSafeMode: { false })
      let pending = Task { try await client.request(.start) }
      try await until { !delayed.saveCallbacks.isEmpty }
      if phase == "cancel-without-callback" { pending.cancel() }
      else { _ = try await other.request(.stop) }
      var finished = false
      let observer = Task { _ = await pending.result; finished = true }
      try await until { finished }
      delayed.saveCallbacks.removeFirst()(nil)
      _ = await observer.result
      precondition(delayed.connection.starts == 0)
      print("PASS: Shared \(phase) releases caller before late preference callback")
    }
  }
}
