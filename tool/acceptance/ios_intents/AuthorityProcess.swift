import Darwin
import Foundation

private final class DispatchClock: @unchecked Sendable {
  let origin = Date()
  var reads = 0
  func now() -> Date {
    reads += 1
    return origin.addingTimeInterval(reads >= 4 ? 31 : 0)
  }
}

@main struct AuthorityProcess {
  enum Failure: Error { case timeout, unexpected }
  static func wait(_ file: URL) throws {
    let until = Date().addingTimeInterval(5)
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

    let expired = TunnelIntentAuthority(directory: root.appendingPathComponent("expired"), lifetime: 0.03)
    let token = try expired.register(.start)
    Thread.sleep(forTimeInterval: 0.05)
    check(try !expired.isCurrent(token))
    var expiredEffect = false
    do { try expired.perform(token, running: true) { expiredEffect = true }; throw Failure.unexpected }
    catch TunnelIntentError.expired {}
    precondition(!expiredEffect)
    print("PASS: expired token cannot dispatch")

    let clock = DispatchClock()
    let aging = TunnelIntentAuthority(directory: root.appendingPathComponent("dispatch-expiry"), clock: { clock.now() })
    let agingToken = try aging.register(.start)
    _ = try aging.resolve(agingToken, observedRunning: false)
    var lateEffect = false
    do { try aging.perform(agingToken, running: true) { lateEffect = true }; throw Failure.unexpected }
    catch TunnelIntentError.expired {}
    precondition(!lateEffect)
    print("PASS: expiry during write preflight still blocks synchronous effect")

    let old = try first.register(.start)
    let lock = open(directory.appendingPathComponent("intent.lock").path, O_RDWR)
    precondition(lock >= 0 && flock(lock, LOCK_EX | LOCK_NB) == 0)
    do { _ = try second.register(.stop); throw Failure.unexpected }
    catch TunnelIntentError.busy {}
    flock(lock, LOCK_UN)
    close(lock)
    check(try first.isCurrent(old))
    print("PASS: lock contention is explicit rejection, not false success")

    precondition(chmod(directory.path, 0o500) == 0)
    var writeFailed = false
    do { _ = try second.register(.stop) } catch { writeFailed = true }
    var effectFailed = false
    do { try first.perform(old, running: true) { fatalError("unwritable authority effect") } }
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
