import Foundation
import NetworkExtension
#if !LEGACY_INTENTS
import Shared
#endif

@MainActor final class TestManagerStore {
  let manager: NETunnelProviderManager
  var loadError: Error?
  init(_ manager: NETunnelProviderManager) { self.manager = manager }
  func loadManager(createIfNeeded: Bool = true) async throws -> NETunnelProviderManager? {
    if let loadError { throw loadError }
    return try await NETunnelProviderManager.loadAllFromPreferences().first
  }
  func invalidateCachedManager(forPreferenceError error: Error) -> Bool {
    let error = error as NSError
    return error.domain == NEVPNErrorDomain && [1, 2].contains(error.code)
  }
  func applyNetworkExtensionOptions(to manager: NETunnelProviderManager, enableOnDemand: Bool) {}
  func isManagedConnection(_ connection: NEVPNConnection) -> Bool {
    (connection.manager.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == NEHelper.providerBundleIdentifier
  }
  func isCachedConnection(_ connection: NEVPNConnection) -> Bool { connection === manager.connection }
}
#if LEGACY_INTENTS
typealias TunnelManagerStore = TestManagerStore
#else
extension TestManagerStore: TunnelManagerAccess {}
#endif

@main struct CrossEntry {
  static func check(_ value: Bool) { precondition(value) }
  @MainActor static func until(_ condition: () -> Bool) async throws {
    for _ in 0..<500 {
      if condition() { return }
      try await Task.sleep(nanoseconds: 2_000_000)
    }
    throw Failure.timeout
  }
  enum Failure: Error { case timeout, lateStart }

  @MainActor static func main() async throws {
    let root = URL(fileURLWithPath: CommandLine.arguments[1])
    #if !LEGACY_INTENTS
    if CommandLine.arguments.count > 2 {
      try await childStop(root, mode: CommandLine.arguments[2])
      return
    }
    #endif
    var failures = 0
    for direction in ["runner-shared", "shared-runner"] {
      let manager = NETunnelProviderManager()
      let config = NETunnelProviderProtocol()
      config.providerBundleIdentifier = NEHelper.providerBundleIdentifier
      manager.protocolConfiguration = config
      NETunnelProviderManager.manager = manager
      let store = TestManagerStore(manager)
      #if LEGACY_INTENTS
      let runner = TunnelCoordinator(managerStore: store,
        onTunnelStateChanged: { _ in }, onConnectionStateChanged: { _ in },
        onExternalStart: {}, onExternalStop: {})
      #else
      let directory = root.appendingPathComponent(direction)
      let client = TunnelIntentClient(authority: TunnelIntentAuthority(directory: directory),
        loadManager: { manager }, isManaged: { store.isManagedConnection($0.connection) }, isSafeMode: { false })
      let runner = TunnelCoordinator(managerStore: store,
        authority: TunnelIntentAuthority(directory: directory), isSafeMode: { false },
        onTunnelStateChanged: { _ in }, onConnectionStateChanged: { _ in },
        onExternalStart: {}, onExternalStop: {})
      #endif
      if direction == "runner-shared" {
        await runner.submitTunnelRequest(target: .running)
        try await until { !manager.saveCallbacks.isEmpty }
        #if LEGACY_INTENTS
        _ = try await NEHelper.stop()
        #else
        _ = try await client.request(.stop)
        try await until { !runner.hasPendingWork }
        #endif
        manager.saveCallbacks.removeFirst()(nil)
      } else {
        let starting = Task {
          #if LEGACY_INTENTS
          _ = try await NEHelper.start()
          #else
          _ = try await client.request(.start)
          #endif
        }
        try await until { !manager.saveCallbacks.isEmpty }
        await runner.submitTunnelRequest(target: .stopped)
        try await Task.sleep(nanoseconds: 50_000_000)
        manager.saveCallbacks.removeFirst()(nil)
        _ = await starting.result
      }
      try await Task.sleep(nanoseconds: 100_000_000)
      if manager.connection.starts != 0 {
        print("FAIL: \(direction) superseded start dispatched")
        failures += 1
        continue
      }
      #if !LEGACY_INTENTS
      try await until { !runner.hasPendingWork }
      precondition(manager.connection.stops == 1)
      #endif
      print("PASS: \(direction) late start suppressed; coordinator drained")
    }
    if failures > 0 { exit(1) }
    #if !LEGACY_INTENTS
    try await moreRunnerTests(root)
    try await processEntryTests(root)
    #endif
  }
}


#if !LEGACY_INTENTS
extension CrossEntry {
  @MainActor static func childStop(_ directory: URL, mode: String) async throws {
    let manager = NETunnelProviderManager()
    let config = NETunnelProviderProtocol()
    config.providerBundleIdentifier = NEHelper.providerBundleIdentifier
    manager.protocolConfiguration = config
    NETunnelProviderManager.manager = manager
    let store = TestManagerStore(manager)
    let authority = TunnelIntentAuthority(directory: directory)
    if mode == "shared-stop" {
      let client = TunnelIntentClient(authority: authority, loadManager: { manager },
        isManaged: { store.isManagedConnection($0.connection) }, isSafeMode: { false })
      _ = try await client.request(.stop)
    } else {
      let runner = TunnelCoordinator(managerStore: store, authority: authority, isSafeMode: { false },
        onTunnelStateChanged: { _ in }, onConnectionStateChanged: { _ in },
        onExternalStart: {}, onExternalStop: {})
      check(await runner.submitTunnelRequest(target: .stopped))
      try await until { !runner.hasPendingWork }
    }
    precondition(manager.connection.stops == 1)
  }

  @MainActor static func processEntryTests(_ root: URL) async throws {
    for mode in ["shared-stop", "runner-stop"] {
      let directory = root.appendingPathComponent("process-" + mode)
      let manager = NETunnelProviderManager()
      let config = NETunnelProviderProtocol()
      config.providerBundleIdentifier = NEHelper.providerBundleIdentifier
      manager.protocolConfiguration = config
      NETunnelProviderManager.manager = manager
      let store = TestManagerStore(manager)
      let authority = TunnelIntentAuthority(directory: directory)
      let runner = TunnelCoordinator(managerStore: store, authority: authority, isSafeMode: { false },
        onTunnelStateChanged: { _ in }, onConnectionStateChanged: { _ in },
        onExternalStart: {}, onExternalStop: {})
      let client = TunnelIntentClient(authority: authority, loadManager: { manager },
        isManaged: { store.isManagedConnection($0.connection) }, isSafeMode: { false })
      var starting: Task<Bool, Error>?
      if mode == "shared-stop" {
        check(await runner.submitTunnelRequest(target: .running))
      } else {
        starting = Task { try await client.request(.start) }
      }
      try await until { !manager.saveCallbacks.isEmpty }
      let child = Process()
      child.executableURL = Bundle.main.executableURL!
      child.arguments = [directory.path, mode]
      try child.run()
      defer {
        if child.isRunning { child.terminate(); child.waitUntilExit() }
      }
      try await until { !child.isRunning }
      child.waitUntilExit()
      precondition(child.terminationStatus == 0)
      if mode == "shared-stop" { try await until { !runner.hasPendingWork } }
      manager.saveCallbacks.removeFirst()(nil)
      if let starting {
        if case .success = await starting.result { throw Failure.lateStart }
      }
      try await Task.sleep(nanoseconds: 20_000_000)
      precondition(manager.connection.starts == 0)
      print("PASS: independent \(mode) process pid=\(child.processIdentifier) exited=\(child.terminationStatus); parent late start blocked")
    }
  }

  @MainActor static func moreRunnerTests(_ root: URL) async throws {
    do {
      let manager = NETunnelProviderManager()
      let config = NETunnelProviderProtocol()
      config.providerBundleIdentifier = NEHelper.providerBundleIdentifier
      manager.protocolConfiguration = config
      manager.pauseSave = false
      manager.connection.startError = NSError(domain: "fixture", code: 1)
      NETunnelProviderManager.manager = manager
      let store = TestManagerStore(manager)
      var states: [String] = []
      let runner = TunnelCoordinator(managerStore: store,
        authority: TunnelIntentAuthority(directory: root.appendingPathComponent("startup-failure")),
        isSafeMode: { false }, onTunnelStateChanged: { _ in },
        onConnectionStateChanged: { states.append($0) }, onExternalStart: {}, onExternalStop: {})
      check(await runner.submitTunnelRequest(target: .running))
      try await until { !runner.hasPendingWork }
      precondition(states.last == "failed")
      manager.connection.status = .connected
      runner.handleTunnelStatusNotification(Notification(name: .init("fixture-status"), object: manager.connection))
      precondition(states.last == "connected")
      manager.connection.status = .disconnected
      runner.handleTunnelStatusNotification(Notification(name: .init("fixture-status"), object: manager.connection))
      precondition(states.last == "disconnected")
      check(await runner.submitTunnelRequest(target: .stopped))
      try await until { !runner.hasPendingWork }
      precondition(states.last == "disconnected")
      print("PASS: failed startup clears on recovery; a later drop is not a startup failure")
    }
    for scenario in ["terminal", "residual-stop", "delayed-connecting", "unnotified-connected", "superseded", "load-error"] {
      let manager = NETunnelProviderManager()
      let config = NETunnelProviderProtocol()
      config.providerBundleIdentifier = NEHelper.providerBundleIdentifier
      manager.protocolConfiguration = config
      manager.pauseSave = false
      manager.connection.startUpdatesStatus = false
      NETunnelProviderManager.manager = manager
      let store = TestManagerStore(manager)
      if scenario == "load-error" { store.loadError = NSError(domain: "fixture", code: 1) }
      var states: [String] = []
      let runner = TunnelCoordinator(managerStore: store,
        authority: TunnelIntentAuthority(directory: root.appendingPathComponent("bounded-" + scenario)),
        isSafeMode: { false }, onTunnelStateChanged: { _ in },
        onConnectionStateChanged: { states.append($0) }, onExternalStart: {}, onExternalStop: {},
        startConfirmationDelay: 100_000_000)
      check(await runner.submitTunnelRequest(target: .running))
      if scenario == "load-error" {
        try await until { !runner.hasPendingWork }
        precondition(states.last == "failed" && manager.connection.starts == 0)
      } else {
        try await until { manager.connection.starts == 1 }
        precondition(states.last == "pending")
        if scenario == "residual-stop" {
          for status in [NEVPNStatus.disconnecting, .disconnected] {
            manager.connection.status = status
            runner.handleTunnelStatusNotification(Notification(name: .init("fixture"), object: manager.connection))
          }
          await Task.yield()
          precondition(runner.hasPendingWork && !states.contains("failed"))
          manager.connection.status = .connected
          runner.handleTunnelStatusNotification(Notification(name: .init("fixture"), object: manager.connection))
          try await until { !runner.hasPendingWork }
          precondition(states.last == "connected" && !states.contains("failed") && manager.connection.starts == 1)
        } else if scenario == "delayed-connecting" {
          try await Task.sleep(nanoseconds: 40_000_000)
          manager.connection.status = .connecting
          runner.handleTunnelStatusNotification(Notification(name: .init("fixture"), object: manager.connection))
          try await Task.sleep(nanoseconds: 130_000_000)
          precondition(runner.hasPendingWork && states.last == "pending" && manager.connection.stops == 0)
          manager.connection.status = .connected
          runner.handleTunnelStatusNotification(Notification(name: .init("fixture"), object: manager.connection))
          try await until { !runner.hasPendingWork }
          precondition(states.last == "connected")
        } else if scenario == "unnotified-connected" {
          manager.connection.status = .connected
          try await until { !runner.hasPendingWork }
          precondition(states.last == "connected" && manager.connection.stops == 0)
        } else if scenario == "superseded" {
          check(await runner.submitTunnelRequest(target: .stopped))
          try await until { !runner.hasPendingWork }
          try await Task.sleep(nanoseconds: 130_000_000)
          precondition(states.last == "disconnected" && manager.connection.stops == 1)
        } else {
          try await until { !runner.hasPendingWork }
          precondition(states.last == "failed" && manager.connection.stops == 0)
          manager.connection.status = .connected
          runner.handleTunnelStatusNotification(Notification(name: .init("fixture"), object: manager.connection))
          precondition(states.last == "connected" && manager.connection.stops == 0)
        }
      }
      print("PASS: bounded start confirmation \(scenario)")
    }
    do {
      let directory = root.appendingPathComponent("temporary-contention")
      let authority = TunnelIntentAuthority(directory: directory)
      let manager = NETunnelProviderManager()
      NETunnelProviderManager.manager = manager
      NETunnelProviderManager.pauseLoad = false
      let config = NETunnelProviderProtocol()
      config.providerBundleIdentifier = NEHelper.providerBundleIdentifier
      manager.protocolConfiguration = config
      let store = TestManagerStore(manager)
      let runner = TunnelCoordinator(managerStore: store, authority: authority, isSafeMode: { false },
        onTunnelStateChanged: { _ in }, onConnectionStateChanged: { _ in },
        onExternalStart: {}, onExternalStop: {})
      check(await runner.submitTunnelRequest(target: .running))
      try await until { !manager.saveCallbacks.isEmpty }
      let lock = open(directory.appendingPathComponent("intent.lock").path, O_RDWR)
      precondition(lock >= 0 && flock(lock, LOCK_EX | LOCK_NB) == 0)
      let stopping = Task { await runner.submitTunnelRequest(target: .stopped) }
      try await Task.sleep(nanoseconds: 200_000_000)
      precondition(runner.hasPendingWork)
      flock(lock, LOCK_UN)
      close(lock)
      check(await stopping.value)
      manager.saveCallbacks.removeFirst()(nil)
      try await until { !runner.hasPendingWork }
      precondition(manager.connection.starts == 0 && manager.connection.stops == 1)
      print("PASS: Runner retries temporary registration contention; accepted stop supersedes old start")
    }
    for phase in ["reload", "retry", "wait", "settle", "authority-failure", "repeat", "cancelled"] {
      let directory = root.appendingPathComponent(phase)
      let authority = TunnelIntentAuthority(directory: directory)
      let manager = NETunnelProviderManager()
      let config = NETunnelProviderProtocol()
      config.providerBundleIdentifier = NEHelper.providerBundleIdentifier
      manager.protocolConfiguration = config
      NETunnelProviderManager.manager = manager
      NETunnelProviderManager.pauseLoad = false
      let store = TestManagerStore(manager)
      var observations = 0
      let runner = TunnelCoordinator(managerStore: store, authority: authority, isSafeMode: { false },
        onTunnelStateChanged: { _ in observations += 1 }, onConnectionStateChanged: { _ in },
        onExternalStart: {}, onExternalStop: {})
      let client = TunnelIntentClient(authority: TunnelIntentAuthority(directory: directory),
        loadManager: { manager }, isManaged: { store.isManagedConnection($0.connection) }, isSafeMode: { false })
      if phase == "settle" { manager.connection.status = .disconnecting }
      check(await runner.submitTunnelRequest(target: .running))
      if phase != "settle" {
        try await until { !manager.saveCallbacks.isEmpty }
      } else {
        try await Task.sleep(nanoseconds: 50_000_000)
      }
      switch phase {
      case "reload":
        manager.pauseReload = true
        manager.saveCallbacks.removeFirst()(nil)
        try await until { !manager.reloadCallbacks.isEmpty }
        _ = try await client.request(.toggle)
        manager.reloadCallbacks.removeFirst()(nil)
      case "retry":
        NETunnelProviderManager.pauseLoad = true
        manager.saveCallbacks.removeFirst()(NSError(domain: NEVPNErrorDomain, code: 2))
        try await until { !NETunnelProviderManager.loadCallbacks.isEmpty }
        _ = try await client.request(.stop)
        NETunnelProviderManager.pauseLoad = false
        NETunnelProviderManager.loadCallbacks.removeFirst()(nil)
      case "wait":
        manager.saveCallbacks.removeFirst()(nil)
        try await until { manager.connection.starts == 1 }
        _ = try await client.request(.stop)
      case "settle":
        _ = try await client.request(.stop)
      case "authority-failure":
        try Data("invalid-json".utf8).write(to: directory.appendingPathComponent("intent.json"))
        manager.saveCallbacks.removeFirst()(nil)
      case "repeat":
        check(await runner.submitTunnelRequest(target: .running))
        manager.saveCallbacks.removeFirst()(nil)
        try await until { !manager.saveCallbacks.isEmpty }
        check(await runner.submitTunnelRequest(target: .stopped))
        manager.saveCallbacks.removeFirst()(nil)
      case "cancelled":
        struct Snapshot: Decodable { let token: TunnelIntentAuthority.Token }
        let data = try Data(contentsOf: directory.appendingPathComponent("intent.json"))
        let token = try JSONDecoder().decode(Snapshot.self, from: data).token
        try authority.finish(token)
        manager.saveCallbacks.removeFirst()(nil)
      default: fatalError()
      }
      try await until { !runner.hasPendingWork }
      precondition(manager.connection.starts == (phase == "wait" ? 1 : 0))
      if phase != "authority-failure" && phase != "cancelled" { precondition(manager.connection.stops == 1) }
      let before = try? Data(contentsOf: directory.appendingPathComponent("intent.json"))
      runner.requestStatusRefresh(notifyExternal: true)
      runner.handleTunnelStatusNotification(Notification(name: .init("fixture-status"), object: manager.connection))
      try await until { !runner.hasPendingWork }
      precondition((try? Data(contentsOf: directory.appendingPathComponent("intent.json"))) == before)
      print("PASS: Runner \(phase), waiter drains and observations do not register intent")
    }

    let directory = root.appendingPathComponent("stale-status")
    let authority = TunnelIntentAuthority(directory: directory)
    let manager = NETunnelProviderManager()
    let config = NETunnelProviderProtocol()
    config.providerBundleIdentifier = NEHelper.providerBundleIdentifier
    manager.protocolConfiguration = config
    manager.pauseSave = false
    manager.connection.startUpdatesStatus = false
    NETunnelProviderManager.manager = manager
    let store = TestManagerStore(manager)
    let client = TunnelIntentClient(authority: authority, loadManager: { manager },
      isManaged: { store.isManagedConnection($0.connection) }, isSafeMode: { false })
    let runner = TunnelCoordinator(managerStore: store,
      authority: TunnelIntentAuthority(directory: directory), isSafeMode: { false },
      onTunnelStateChanged: { _ in }, onConnectionStateChanged: { _ in },
      onExternalStart: {}, onExternalStop: {})
    _ = try await client.request(.start)
    precondition(manager.connection.status == .disconnected && manager.connection.starts == 1)
    check(await runner.submitTunnelRequest(target: .stopped))
    try await until { !runner.hasPendingWork }
    precondition(manager.connection.stops == 1)
    check(await runner.submitTunnelRequest(target: .running))
    try await until { manager.connection.starts == 2 }
    _ = try await client.request(.stop)
    try await until { !runner.hasPendingWork }
    precondition(manager.connection.stops == 2)
    print("PASS: both stop paths dispatch despite disconnected cached status")

    try Data("broken".utf8).write(to: directory.appendingPathComponent("intent.json"))
    check(await !runner.submitTunnelRequest(target: .running))
    precondition(!runner.hasPendingWork)
    print("PASS: Runner rejects unavailable authority synchronously")

    let freshDirectory = root.appendingPathComponent("fresh-toggle")
    let fresh = TunnelCoordinator(managerStore: store,
      authority: TunnelIntentAuthority(directory: freshDirectory), isSafeMode: { false },
      onTunnelStateChanged: { _ in }, onConnectionStateChanged: { _ in },
      onExternalStart: {}, onExternalStop: {})
    manager.connection.status = .connected
    let stopsBefore = manager.connection.stops
    check(await fresh.toggleTunnelRequest())
    try await until { !fresh.hasPendingWork }
    precondition(manager.connection.stops == stopsBefore + 1)
    print("PASS: first Runner toggle resolves loaded manager status")

    manager.connection.status = .connected
    let doubleToggle = TunnelCoordinator(managerStore: store,
      authority: TunnelIntentAuthority(directory: root.appendingPathComponent("two-toggles")), isSafeMode: { false },
      onTunnelStateChanged: { _ in }, onConnectionStateChanged: { _ in },
      onExternalStart: {}, onExternalStop: {})
    NETunnelProviderManager.pauseLoad = true
    check(await doubleToggle.toggleTunnelRequest())
    try await until { NETunnelProviderManager.loadCallbacks.count == 1 }
    check(await doubleToggle.toggleTunnelRequest())
    try await until { NETunnelProviderManager.loadCallbacks.count == 2 }
    NETunnelProviderManager.pauseLoad = false
    NETunnelProviderManager.loadCallbacks.removeFirst()(nil)
    NETunnelProviderManager.loadCallbacks.removeFirst()(nil)
    try await until { !doubleToggle.hasPendingWork }
    precondition(manager.connection.stops == stopsBefore + 1)
    print("PASS: Runner preserves unresolved toggle parity and drains obsolete loads")

    let queuedAuthority = TunnelIntentAuthority(directory: root.appendingPathComponent("queued"))
    let queuedToken = try queuedAuthority.register(.start)
    let laterStop = try queuedAuthority.register(.stop)
    let queuedRunner = TunnelCoordinator(managerStore: store, authority: queuedAuthority, isSafeMode: { false },
      onTunnelStateChanged: { _ in }, onConnectionStateChanged: { _ in },
      onExternalStart: {}, onExternalStop: {})
    precondition(!queuedRunner.submitRegisteredIntent(queuedToken))
    let stillCurrent = try queuedAuthority.isCurrent(laterStop)
    precondition(stillCurrent && !queuedRunner.hasPendingWork)
    precondition(queuedRunner.submitRegisteredIntent(laterStop))
    try await until { !queuedRunner.hasPendingWork }
    print("PASS: startup queue cannot remint a superseded intent")

    let reverseDirectory = root.appendingPathComponent("old-stop")
    let reverseAuthority = TunnelIntentAuthority(directory: reverseDirectory)
    let reverseRunner = TunnelCoordinator(managerStore: store, authority: reverseAuthority, isSafeMode: { false },
      onTunnelStateChanged: { _ in }, onConnectionStateChanged: { _ in },
      onExternalStart: {}, onExternalStop: {})
    let oldClient = TunnelIntentClient(authority: TunnelIntentAuthority(directory: reverseDirectory),
      loadManager: { try await NETunnelProviderManager.loadAllFromPreferences().first },
      isManaged: { _ in true }, isSafeMode: { false })
    NETunnelProviderManager.pauseLoad = true
    let oldStop = Task { try await oldClient.request(.stop) }
    try await until { NETunnelProviderManager.loadCallbacks.count == 1 }
    NETunnelProviderManager.pauseLoad = false
    manager.connection.status = .disconnected
    manager.connection.startUpdatesStatus = true
    let reverseStarts = manager.connection.starts
    let reverseStops = manager.connection.stops
    check(await reverseRunner.submitTunnelRequest(target: .running))
    try await until { manager.connection.starts == reverseStarts + 1 }
    NETunnelProviderManager.loadCallbacks.removeFirst()(nil)
    if case .success = await oldStop.result { throw Failure.lateStart }
    precondition(manager.connection.stops == reverseStops)
    manager.connection.status = .connected
    reverseRunner.handleTunnelStatusNotification(Notification(name: .init("fixture-status"), object: manager.connection))
    try await until { !reverseRunner.hasPendingWork }
    print("PASS: obsolete Shared stop cannot stop a newer Runner start")
  }
}
#endif
