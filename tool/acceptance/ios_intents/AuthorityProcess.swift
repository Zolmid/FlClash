import Darwin
import Foundation

@main struct AuthorityProcess {
  enum Failure: Error { case timeout, unexpected }
  static func wait(_ file: URL, timeout: TimeInterval = 5) throws {
    let until = Date().addingTimeInterval(timeout)
    while !FileManager.default.fileExists(atPath: file.path) {
      if Date() > until { throw Failure.timeout }
      Thread.sleep(forTimeInterval: 0.01)
    }
  }
  static func marker(_ file: URL) throws { try Data().write(to: file) }
  static func check(_ condition: Bool) { precondition(condition) }
  static func main() throws {
    let mode = CommandLine.arguments[1]
    let root = URL(fileURLWithPath: CommandLine.arguments[2])
    let authority = TunnelIntentAuthority(directory: root.appendingPathComponent("authority"))
    switch mode {
    case "pending-start":
      let token = try authority.register(.start)
      _ = try authority.resolve(token, observedRunning: false)
      try marker(root.appendingPathComponent("ready"))
      try wait(root.appendingPathComponent("release"))
      do {
        try authority.perform(token, running: true) { try marker(root.appendingPathComponent("late-start")) }
        throw Failure.unexpected
      } catch TunnelIntentError.superseded {
        print("PASS: independent process rejects obsolete start token")
      }
    case "stop":
      let token = try authority.register(.stop)
      _ = try authority.resolve(token, observedRunning: false)
      try authority.perform(token, running: false) { try marker(root.appendingPathComponent("stopped")) }
    case "hold-effect":
      let token = try authority.register(.start)
      _ = try authority.resolve(token, observedRunning: false)
      try authority.perform(token, running: true) {
        try marker(root.appendingPathComponent("locked"))
        try wait(root.appendingPathComponent("unlock"))
        try marker(root.appendingPathComponent("started"))
      }
    case "expect-busy":
      do { _ = try authority.register(.stop); throw Failure.unexpected }
      catch TunnelIntentError.busy { print("PASS: competing process cannot enter check/effect critical section") }
    case "hold-owner":
      let token = try authority.register(.start)
      try JSONEncoder().encode(token).write(to: root.appendingPathComponent("token"))
      try marker(root.appendingPathComponent("ready"))
      try wait(root.appendingPathComponent("release"), timeout: 45)
    case "observe-owner", "observe-dead":
      let token = try JSONDecoder().decode(TunnelIntentAuthority.Token.self,
        from: Data(contentsOf: root.appendingPathComponent("token")))
      if mode == "observe-owner" {
        check(try authority.isCurrent(token))
        print("PASS: other process observes live pending owner")
      } else {
        check(try !authority.isCurrent(token))
        var issued = false
        do { try authority.perform(token, running: true) { issued = true }; throw Failure.unexpected }
        catch TunnelIntentError.expired {}
        precondition(!issued)
        let toggle = try authority.register(.toggle)
        check(try !authority.resolve(toggle, observedRunning: true))
        print("PASS: dead owner cannot replay; toggle uses current observed state")
      }
    case "unit":
      try unit(root)
    default: throw Failure.unexpected
    }
  }

  static func unit(_ root: URL) throws {
    let directory = root.appendingPathComponent("unit")
    let first = TunnelIntentAuthority(directory: directory)
    let second = TunnelIntentAuthority(directory: directory)
    let start = try first.register(.start)
    let stop = try second.register(.toggle)
    let target = try second.resolve(stop, observedRunning: false)
    precondition(!target)
    check(try !first.isCurrent(start))
    try first.finish(start)
    check(try second.isCurrent(stop))
    try second.finish(stop)
    check(try !second.isCurrent(stop))
    let odd = try first.register(.toggle)
    let even = try second.register(.toggle)
    check(try !first.isCurrent(odd))
    check(try !second.resolve(even, observedRunning: false))
    print("PASS: independent instances, toggle parity and stale completion fencing")

    let cancelled = try first.register(.start)
    try first.finish(cancelled)
    check(try !first.isCurrent(cancelled))
    var cancelledEffect = false
    do { try first.perform(cancelled, running: true) { cancelledEffect = true }; throw Failure.unexpected }
    catch TunnelIntentError.superseded {}
    precondition(!cancelledEffect)
    print("PASS: explicitly finished token cannot dispatch")

    let old = try first.register(.start)
    let lock = open(directory.appendingPathComponent("intent.lock").path, O_RDWR)
    precondition(lock >= 0 && flock(lock, LOCK_EX | LOCK_NB) == 0)
    do { _ = try second.register(.stop); throw Failure.unexpected }
    catch TunnelIntentError.busy {}
    flock(lock, LOCK_UN)
    close(lock)
    check(try first.isCurrent(old))
    print("PASS: lock contention is explicit rejection, not false success")

    let cancelledWhileBusy = try first.register(.start)
    let busyLock = open(directory.appendingPathComponent("intent.lock").path, O_RDWR)
    precondition(busyLock >= 0 && flock(busyLock, LOCK_EX | LOCK_NB) == 0)
    first.cancel(cancelledWhileBusy)
    flock(busyLock, LOCK_UN)
    close(busyLock)
    check(try !first.isCurrent(cancelledWhileBusy))
    do { try first.perform(cancelledWhileBusy, running: true) { throw Failure.unexpected }; throw Failure.unexpected }
    catch TunnelIntentError.expired {}
    let replacement = try first.register(.start)

    precondition(chmod(directory.path, 0o500) == 0)
    var writeFailed = false
    do { _ = try second.register(.stop) } catch { writeFailed = true }
    var effectFailed = false
    do { try first.perform(replacement, running: true) { fatalError("unwritable authority effect") } }
    catch { effectFailed = true }
    precondition(chmod(directory.path, 0o700) == 0)
    precondition(writeFailed && effectFailed)
    print("PASS: authority write failure prevents commands")

    try Data("corrupt".utf8).write(to: directory.appendingPathComponent("intent.json"))
    do { _ = try first.isCurrent(old); throw Failure.unexpected }
    catch TunnelIntentError.unavailable {}
    do { _ = try second.register(.stop); throw Failure.unexpected }
    catch TunnelIntentError.unavailable {}
    print("PASS: corrupt records fail closed without resetting authority")

    let restartDirectory = root.appendingPathComponent("restart")
    let previous = TunnelIntentAuthority(directory: restartDirectory)
    let previousToken = try previous.register(.start)
    let restarted = TunnelIntentAuthority(directory: restartDirectory)
    let fresh = try restarted.register(.stop)
    check(try !previous.isCurrent(previousToken))
    check(try restarted.isCurrent(fresh))
    let bytes = try Data(contentsOf: restartDirectory.appendingPathComponent("intent.json"))
    let body = String(decoding: bytes, as: UTF8.self)
    precondition(!body.contains("account") && !body.contains("credential") && !body.contains("session"))
    print("PASS: fresh instance supersedes residual request without startup effects or account data")
  }
}
