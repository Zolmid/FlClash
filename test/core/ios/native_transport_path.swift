import Foundation

private final class FixturePathSource: NETransportPathSource {
  var update: ((NETransportPath) -> Void)?
  var cancelled = false
  func start(queue: DispatchQueue, update: @escaping (NETransportPath) -> Void) {
    self.update = update
  }
  func cancel() { cancelled = true }
}

@main struct NativeTransportPathChecks {
  static func main() {
    var sources: [FixturePathSource] = []
    var resets = 0
    var starts = 0
    let monitor = NETransportPathMonitor(makeSource: {
      let source = FixturePathSource()
      sources.append(source)
      return source
    }, reset: { resets += 1 })
    let wifi = NETransportPath(available: true, interfaces: ["en0", "en1"],
      ipv4: true, ipv6: true, dns: true)
    let equivalent = NETransportPath(available: true, interfaces: ["en1", "en0"],
      ipv4: true, ipv6: true, dns: true)
    let cellular = NETransportPath(available: true, interfaces: ["pdp_ip0"],
      ipv4: true, ipv6: true, dns: true)
    let offline = NETransportPath(available: false, interfaces: [],
      ipv4: false, ipv6: false, dns: false)
    let noIPv6 = NETransportPath(available: true, interfaces: ["pdp_ip0"],
      ipv4: true, ipv6: false, dns: true)
    let noDNS = NETransportPath(available: true, interfaces: ["pdp_ip0"],
      ipv4: true, ipv6: false, dns: false)
    let token = monitor.begin()
    precondition(monitor.start(token) { starts += 1; return true })
    precondition(!monitor.start(token) { fatalError("duplicate start") })
    func send(_ path: NETransportPath, source: Int = 0) {
      sources[source].update?(path)
      _ = monitor.isCurrent(token)
    }
    send(wifi)
    send(equivalent)
    precondition(resets == 0)
    send(cellular)
    send(cellular)
    precondition(resets == 1)
    send(offline)
    send(offline)
    precondition(resets == 1)
    send(cellular)
    precondition(resets == 2)
    send(noIPv6)
    send(noDNS)
    precondition(resets == 4)
    monitor.stop()
    precondition(sources[0].cancelled)
    send(wifi)
    precondition(resets == 4)
    precondition(!monitor.start(token) { fatalError("stopped start") })
    let second = monitor.begin()
    precondition(monitor.start(second) { starts += 1; return true })
    send(wifi)
    send(cellular, source: 1)
    precondition(resets == 4)
    send(wifi, source: 1)
    precondition(resets == 5)
    let third = monitor.begin()
    precondition(sources[1].cancelled)
    precondition(!monitor.start(second) { fatalError("superseded start") })
    precondition(!monitor.start(third) { false })
    precondition(sources.count == 2)
    precondition(monitor.start(third) { true })
    send(offline, source: 2)
    send(wifi, source: 2)
    precondition(resets == 6)
    monitor.stop()
    precondition(starts == 2 && sources.allSatisfy(\.cancelled))
    print("PASS: native path initial/equivalent snapshots, change/recovery, dedupe, stop, stale callbacks and failed/superseded starts")
  }
}
