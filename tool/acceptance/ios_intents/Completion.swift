import Darwin
import Foundation
import NetworkExtension
import Shared

final class CountingCenter: NotificationCenter, @unchecked Sendable {
  private let lock = NSLock()
  private var active: Set<ObjectIdentifier> = []
  var callbacks: [@Sendable (Notification) -> Void] = []
  var count: Int { lock.lock(); defer { lock.unlock() }; return active.count }

  override func addObserver(forName name: NSNotification.Name?, object obj: Any?, queue: OperationQueue?,
    using block: @escaping @Sendable (Notification) -> Void) -> NSObjectProtocol {
    let observer = super.addObserver(forName: name, object: obj, queue: queue, using: block)
    lock.lock()
    active.insert(ObjectIdentifier(observer))
    callbacks.append(block)
    lock.unlock()
    return observer
  }

  override func removeObserver(_ observer: Any) {
    lock.lock()
    active.remove(ObjectIdentifier(observer as AnyObject))
    lock.unlock()
    super.removeObserver(observer)
  }
}

final class WeakReference<Value: AnyObject> {
  weak var value: Value?
  init(_ value: Value) { self.value = value }
}

@main struct CompletionTests {
  struct Snapshot: Decodable { let token: TunnelIntentAuthority.Token }
  enum Failure: Error { case timeout }
  static func check(_ value: Bool) { precondition(value) }
  static func fdCount() -> Int { (0..<2048).filter { fcntl(Int32($0), F_GETFD) >= 0 }.count }
  static func token(_ directory: URL) throws -> TunnelIntentAuthority.Token {
    try JSONDecoder().decode(Snapshot.self,
      from: Data(contentsOf: directory.appendingPathComponent("intent.json"))).token
  }
  static func post(_ status: NEVPNStatus, _ connection: NEVPNConnection, _ center: NotificationCenter) {
    connection.status = status
    center.post(name: .NEVPNStatusDidChange, object: connection)
  }
  @MainActor static func until(_ condition: () throws -> Bool) async throws {
    for _ in 0..<500 {
      if try condition() { return }
      try await Task.sleep(nanoseconds: 2_000_000)
    }
    throw Failure.timeout
  }
  @MainActor static func client(_ authority: TunnelIntentAuthority, _ manager: NETunnelProviderManager,
    _ center: NotificationCenter) -> TunnelIntentClient {
    TunnelIntentClient(authority: authority, loadManager: { manager }, isManaged: { _ in true },
      isSafeMode: { false }, notificationCenter: center)
  }

  @MainActor static func main() async throws {
    let root = URL(fileURLWithPath: CommandLine.arguments[1])
    let center = CountingCenter()
    do {
      let directory = root.appendingPathComponent("known-progress")
      let authority = TunnelIntentAuthority(directory: directory)
      let manager = NETunnelProviderManager()
      manager.connection.status = .connecting
      var owner: TunnelIntentClient? = client(authority, manager, center)
      let reference = WeakReference(owner!)
      check(try await owner!.request(.start))
      let accepted = try token(directory)
      manager.connection.status = .disconnected
      owner = nil
      try await until { try !authority.isCurrent(accepted) && center.count == 0 }
      precondition(reference.value == nil)
      print("PASS: pre-handoff connecting survives first monitor turn; token, observer and client release")
    }
    do {
      let directory = root.appendingPathComponent("transient-stop")
      let authority = TunnelIntentAuthority(directory: directory)
      let manager = NETunnelProviderManager()
      manager.connection.status = .disconnecting
      manager.connection.stopUpdatesStatus = false
      let owner = client(authority, manager, center)
      check(try await owner.request(.stop))
      let accepted = try token(directory)
      DispatchQueue.global().sync {
        post(.disconnected, manager.connection, center)
        post(.connected, manager.connection, center)
      }
      check(try !authority.isCurrent(accepted))
      precondition(center.count == 0)
      check(try await owner.request(.toggle))
      precondition(manager.connection.stops == 2 && manager.connection.starts == 0)
      post(.disconnected, manager.connection, center)
      precondition(center.count == 0)
      print("PASS: transient terminal captured on posting thread while MainActor blocked; next toggle stops")
    }
    for starting in [true, false] {
      let directory = root.appendingPathComponent(starting ? "start-effect" : "stop-effect")
      let authority = TunnelIntentAuthority(directory: directory)
      let manager = NETunnelProviderManager()
      manager.pauseSave = false
      manager.connection.status = starting ? .disconnected : .connected
      let effect = { [weak manager] in
        guard let manager else { return }
        post(starting ? .connecting : .disconnecting, manager.connection, center)
        post(.disconnected, manager.connection, center)
        if !starting { post(.connected, manager.connection, center) }
      }
      if starting { manager.connection.onStart = effect } else { manager.connection.onStop = effect }
      check(try await client(authority, manager, center).request(starting ? .start : .stop))
      check(try !authority.isCurrent(token(directory)))
      precondition(center.count == 0)
      print("PASS: observer installed before synchronous \(starting ? "start" : "stop") effect and retains terminal through lock contention")
    }
    do {
      let directory = root.appendingPathComponent("immediate-start-failure")
      let authority = TunnelIntentAuthority(directory: directory)
      let manager = NETunnelProviderManager()
      manager.pauseSave = false
      manager.connection.startUpdatesStatus = false
      manager.connection.onStart = { [weak manager] in
        guard let manager else { return }
        post(.disconnected, manager.connection, center)
      }
      check(try await client(authority, manager, center).request(.start))
      check(try !authority.isCurrent(token(directory)))
      precondition(center.count == 0)
      print("PASS: terminal notification after start dispatch completes even without a connecting sample")
    }
    for scenario in ["silent-terminal", "residual-stop", "delayed-connecting", "superseded"] {
      let directory = root.appendingPathComponent("bounded-" + scenario)
      let authority = TunnelIntentAuthority(directory: directory)
      let manager = NETunnelProviderManager()
      manager.pauseSave = false
      manager.connection.startUpdatesStatus = false
      let owner = TunnelIntentClient(authority: authority, loadManager: { manager }, isManaged: { _ in true },
        isSafeMode: { false }, notificationCenter: center, startConfirmationDelay: 100_000_000)
      check(try await owner.request(.start))
      let accepted = try token(directory)
      check(try authority.isCurrent(accepted))
      if scenario == "residual-stop" {
        post(.disconnecting, manager.connection, center)
        post(.disconnected, manager.connection, center)
        check(try authority.isCurrent(accepted))
        post(.connected, manager.connection, center)
        precondition(manager.connection.starts == 1)
      } else if scenario == "delayed-connecting" {
        post(.connecting, manager.connection, center)
        try await Task.sleep(nanoseconds: 350_000_000)
        check(try authority.isCurrent(accepted))
        post(.connected, manager.connection, center)
      } else if scenario == "superseded" {
        let newer = try authority.register(.stop)
        try await until { center.count == 0 }
        check(try authority.isCurrent(newer))
        try authority.finish(newer)
      } else {
        try await until { try !authority.isCurrent(accepted) && center.count == 0 }
        precondition(manager.connection.stops == 0)
      }
      try await until { center.count == 0 }
      precondition(manager.connection.stops == 0)
      print("PASS: Shared bounded confirmation \(scenario)")
    }
    do {
      let directory = root.appendingPathComponent("terminal-while-busy")
      let authority = TunnelIntentAuthority(directory: directory)
      let manager = NETunnelProviderManager()
      manager.connection.status = .disconnecting
      manager.connection.stopUpdatesStatus = false
      check(try await client(authority, manager, center).request(.stop))
      let accepted = try token(directory)
      let descriptor = open(directory.appendingPathComponent("intent.lock").path, O_RDWR)
      precondition(descriptor >= 0 && flock(descriptor, LOCK_EX | LOCK_NB) == 0)
      post(.disconnected, manager.connection, center)
      post(.connected, manager.connection, center)
      precondition(center.count == 0)
      flock(descriptor, LOCK_UN)
      close(descriptor)
      check(try await client(authority, manager, center).request(.toggle))
      precondition(manager.connection.stops == 2, "completed stop must not influence a toggle before the next poll")
      post(.disconnected, manager.connection, center)
      try await until { try !authority.isCurrent(accepted) && center.count == 0 }
      print("PASS: terminal releases ownership even when finish is busy; immediate toggle uses current status")
    }
    do {
      let directory = root.appendingPathComponent("await-events")
      let authority = TunnelIntentAuthority(directory: directory)
      let manager = NETunnelProviderManager()
      let owner = client(authority, manager, center)
      let pending = Task { try await owner.request(.start) }
      try await until { !manager.saveCallbacks.isEmpty }
      post(.connecting, manager.connection, center)
      post(.disconnected, manager.connection, center)
      manager.saveCallbacks.removeFirst()(nil)
      check(try await pending.value)
      precondition(manager.connection.starts == 0 && center.count == 0)
      check(try !authority.isCurrent(token(directory)))
      print("PASS: progress and terminal during preference await prevent a later duplicate start")
    }
    do {
      let directory = root.appendingPathComponent("load-handoff")
      let authority = TunnelIntentAuthority(directory: directory)
      let manager = NETunnelProviderManager()
      manager.connection.status = .connecting
      var descriptor: Int32 = -1
      let owner = TunnelIntentClient(authority: authority, loadManager: {
        descriptor = open(directory.appendingPathComponent("intent.lock").path, O_RDWR)
        precondition(descriptor >= 0 && flock(descriptor, LOCK_EX | LOCK_NB) == 0)
        return manager
      }, isManaged: { _ in true }, isSafeMode: { false }, notificationCenter: center)
      let pending = Task { try await owner.request(.start) }
      try await until { center.count == 1 }
      post(.disconnected, manager.connection, center)
      post(.connected, manager.connection, center)
      flock(descriptor, LOCK_UN)
      close(descriptor)
      check(try await pending.value)
      precondition(center.count == 0 && manager.connection.starts == 0)
      print("PASS: binding is installed at manager-load handoff before a suspended authority recheck")
    }
    do {
      let directory = root.appendingPathComponent("retry-connection")
      let authority = TunnelIntentAuthority(directory: directory)
      let first = NETunnelProviderManager()
      let second = NETunnelProviderManager()
      var loads = 0
      let owner = TunnelIntentClient(authority: authority, loadManager: {
        loads += 1
        return loads == 1 ? first : second
      }, isManaged: { _ in true }, isSafeMode: { false }, notificationCenter: center)
      let pending = Task { try await owner.request(.start) }
      try await until { !first.saveCallbacks.isEmpty }
      let obsoleteCallback = center.callbacks.last!
      first.saveCallbacks.removeFirst()(NSError(domain: NEVPNErrorDomain, code: 2))
      try await until { !second.saveCallbacks.isEmpty }
      precondition(center.count == 1)
      post(.connecting, first.connection, center)
      post(.disconnected, first.connection, center)
      obsoleteCallback(Notification(name: .NEVPNStatusDidChange, object: first.connection))
      second.saveCallbacks.removeFirst()(nil)
      check(try await pending.value)
      check(try authority.isCurrent(token(directory)))
      precondition(first.connection.starts == 0 && second.connection.starts == 1)
      post(.disconnected, first.connection, center)
      check(try authority.isCurrent(token(directory)))
      post(.connected, second.connection, center)
      precondition(center.count == 0)
      print("PASS: retry replaces connection binding; stale connection and removed callback cannot finish request")
    }
    do {
      let directory = root.appendingPathComponent("wrong-token")
      let authority = TunnelIntentAuthority(directory: directory)
      let first = NETunnelProviderManager()
      let second = NETunnelProviderManager()
      first.connection.status = .connecting
      second.connection.status = .connecting
      check(try await client(authority, first, center).request(.start))
      let obsoleteCallback = center.callbacks.last!
      check(try await client(authority, second, center).request(.start))
      let latest = try token(directory)
      first.connection.status = .disconnected
      obsoleteCallback(Notification(name: .NEVPNStatusDidChange, object: first.connection))
      check(try authority.isCurrent(latest))
      try await until { center.count == 1 }
      post(.disconnected, first.connection, center)
      check(try authority.isCurrent(latest))
      post(.connected, second.connection, center)
      precondition(center.count == 0)
      print("PASS: superseded token cannot finish new token, including late callback to old observer")
    }
    for cancel in [true, false] {
      let directory = root.appendingPathComponent(cancel ? "cancel-no-event" : "supersede-no-event")
      let authority = TunnelIntentAuthority(directory: directory)
      let manager = NETunnelProviderManager()
      manager.connection.status = .connecting
      check(try await client(authority, manager, center).request(.start))
      let accepted = try token(directory)
      var replacement: TunnelIntentAuthority.Token?
      if cancel { authority.cancel(accepted) } else { replacement = try authority.register(.stop) }
      try await until { center.count == 0 }
      if let replacement {
        check(try authority.isCurrent(replacement))
        try authority.finish(replacement)
      }
      print("PASS: \(cancel ? "cancel" : "supersede") without a status notification releases observer and monitor")
    }
    try await resources(root.appendingPathComponent("resources"), center)
  }

  @MainActor static func resources(_ directory: URL, _ center: CountingCenter) async throws {
    let authority = TunnelIntentAuthority(directory: directory)
    let warmup = try authority.register(.stop)
    try authority.finish(warmup)
    let before = fdCount()
    for cycle in 0..<600 {
      let manager = NETunnelProviderManager()
      manager.connection.status = cycle % 3 == 1 ? .disconnected : .connecting
      var owner: TunnelIntentClient? = client(authority, manager, center)
      let reference = WeakReference(owner!)
      if cycle % 3 == 1 {
        let pending = Task { [owner] in try await owner!.request(.start) }
        try await until { !manager.saveCallbacks.isEmpty }
        let callback = manager.saveCallbacks.removeFirst()
        pending.cancel()
        if case .success = await pending.result { fatalError("cancelled request succeeded") }
        owner = nil
        precondition(center.count == 0)
        precondition(reference.value == nil, "cancel must release the client before an unbounded late callback")
        callback(nil)
        try await until { reference.value == nil }
      } else {
        check(try await owner!.request(.start))
        if cycle % 3 == 2 {
          let replacement = try authority.register(.stop)
          post(.disconnected, manager.connection, center)
          check(try authority.isCurrent(replacement))
          try authority.finish(replacement)
        } else {
          post(.connected, manager.connection, center)
        }
        owner = nil
        try await until { reference.value == nil && center.count == 0 }
      }
      center.callbacks.removeAll()
    }
    try await Task.sleep(nanoseconds: 300_000_000)
    let after = fdCount()
    precondition(before == after && center.count == 0)
    print("PASS: 600 finish/cancel/supersede cycles release clients, observers and owner FDs (\(before) -> \(after))")
  }
}
