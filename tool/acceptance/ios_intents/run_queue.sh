#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../../.." && pwd)"
out="$(mktemp -d "${TMPDIR:-/tmp}/c-ios-queue.XXXXXX")"
trap 'chmod -R u+rwX "$out" 2>/dev/null || true; rm -rf "$out"' EXIT
python3 - "$root" "$out" <<'PY'
from pathlib import Path
import sys
root, out = map(Path, sys.argv[1:])
source = (root / 'ios/Runner/ServiceChannel.swift').read_text()
request = source[source.index('  @discardableResult\n  static func request('):source.index('\n  private init(messenger:')]
prefix = '''import Darwin
import Foundation

enum QuickAction { case start, stop
  var command: TunnelIntentAuthority.Command { self == .start ? .start : .stop }
}
final class Store { var isSafeMode = false }
@MainActor final class Controller {
  var consumed: [TunnelIntentAuthority.Token] = []
  func submitRegisteredIntent(_ token: TunnelIntentAuthority.Token) -> Bool {
    consumed.append(token)
    return true
  }
}
@MainActor final class ServiceChannel {
  static var instance: ServiceChannel?
  static let pendingQuickAction = PendingTunnelIntent()
  static let quickActionAuthority = TunnelIntentAuthority(directory: URL(fileURLWithPath: CommandLine.arguments[2]))
  let sharedStateStore = Store()
  let tunnelController = Controller()
  var isInitialized = false
  var quickActionDrain: Task<Void, Never>?
  func log(_ message: String) {}
'''
suffix = '''  func initialize() { isInitialized = true; drainQuickActions() }
}
@main struct QueueFixture {
  static func check(_ value: Bool) { precondition(value) }
  @MainActor static func main() async throws {
    let mode = CommandLine.arguments[1]
    let directory = URL(fileURLWithPath: CommandLine.arguments[2])
    check(await ServiceChannel.request(.start))
    let accepted = ServiceChannel.pendingQuickAction.token!
    var descriptor: Int32 = -1
    var savedRecord: Data?
    if mode == "initio" {
      let file = directory.appendingPathComponent("intent.json")
      savedRecord = try Data(contentsOf: file)
      try Data("corrupt".utf8).write(to: file)
    } else if mode == "long" {
      try await Task.sleep(nanoseconds: 31_000_000_000)
    } else if mode == "supersede" {
      _ = try TunnelIntentAuthority(directory: directory).register(.stop)
    } else if mode == "busy" || mode == "initbusy" {
      descriptor = open(directory.appendingPathComponent("intent.lock").path, O_RDWR)
      precondition(descriptor >= 0 && flock(descriptor, LOCK_EX | LOCK_NB) == 0)
    } else {
      precondition(chmod(directory.path, 0o500) == 0)
    }
    if mode != "long" && mode != "initbusy" && mode != "initio" && mode != "supersede" {
      check(await !ServiceChannel.request(.stop))
      precondition(ServiceChannel.pendingQuickAction.token == accepted)
      if mode == "busy" { flock(descriptor, LOCK_UN); close(descriptor) }
      else { precondition(chmod(directory.path, 0o700) == 0) }
    }
    let service = ServiceChannel()
    ServiceChannel.instance = service
    if mode == "supersede" {
      service.initialize()
      try await Task.sleep(nanoseconds: 100_000_000)
      precondition(service.tunnelController.consumed.isEmpty)
      precondition(ServiceChannel.pendingQuickAction.token == nil)
      print("PASS: superseded queue is discarded without re-registering")
      return
    }
    if mode == "initbusy" || mode == "initio" {
      service.initialize()
      try await Task.sleep(nanoseconds: 500_000_000)
      precondition(service.tunnelController.consumed.isEmpty)
      precondition(ServiceChannel.pendingQuickAction.token == accepted)
      if mode == "initbusy" { flock(descriptor, LOCK_UN); close(descriptor) }
      else { try savedRecord!.write(to: directory.appendingPathComponent("intent.json")) }
    }
    let current = try ServiceChannel.quickActionAuthority.isCurrent(accepted)
    precondition(current)
    service.initialize()
    for _ in 0..<100 {
      if !service.tunnelController.consumed.isEmpty { break }
      try await Task.sleep(nanoseconds: 10_000_000)
    }
    precondition(service.tunnelController.consumed == [accepted])
    precondition(ServiceChannel.pendingQuickAction.token == nil)
    print("PASS: accepted start survives \\(mode) and init consumes it")
  }
}
'''
(out / 'QueueFixture.swift').write_text(prefix + request + '\n' + suffix)
PY
swiftc -swift-version 5 -parse-as-library -module-cache-path "$out/cache" "$root/ios/Shared/TunnelIntentAuthority.swift" "$out/QueueFixture.swift" -o "$out/queue-test"
"$out/queue-test" busy "$out/busy"
"$out/queue-test" io "$out/io"
"$out/queue-test" initbusy "$out/initbusy"
"$out/queue-test" initio "$out/initio"
"$out/queue-test" supersede "$out/supersede"
"$out/queue-test" long "$out/long"
