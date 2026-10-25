import Foundation

@main enum LeaseObserverPresentationCheck {
  static func main() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory.appendingPathComponent("diagnostics"), withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("diagnostics/lease-observation-ios_extension.json")
    let now = Date(timeIntervalSince1970: 1000)
    var state: [String: Any] = [
      "instance_tag": String(repeating: "a", count: 64), "configuration_generation": 1,
      "lease_present": true, "revoked": false, "deadline_elapsed": true, "remaining_ms": 0,
      "groups": [["index": 0, "mode": "auto", "automatic": "proxy"]],
    ]
    var snapshot: [String: Any] = [
      "schema_version": 1, "kind": "zolnit_routing_lease_observation", "core_version": "v1.19.32",
      "producer_pid": 42, "platform": "ios", "role": "ios_extension", "sampled_at_unix_ms": 1_000_000,
      "uptime_ms": 10, "producer_state": "running", "state": state, "events": [],
    ]
    func read() throws -> LeaseObservationPresentation {
      let data = try JSONSerialization.data(withJSONObject: snapshot)
      try data.write(to: file)
      let result = LeaseObservationPresentation.read(containerURL: directory, role: "ios_extension", now: now)
      let after = try Data(contentsOf: file)
      precondition(after == data, "observer changed Core state")
      return result
    }
    let expired = try read()
    precondition(expired.status == "snapshot_fresh" && expired.deadlineResult == "not_rejected")
    state["groups"] = [["index": 0, "mode": "auto", "automatic": "missing"]]
    snapshot["state"] = state
    let missing = try read()
    precondition(missing.deadlineResult == "unverified")
    state["groups"] = [["index": 0, "mode": "manual", "automatic": "reject", "manual_tag": String(repeating: "b", count: 64)]]
    state["revoked"] = true
    snapshot["state"] = state
    let rejected = try read()
    precondition(rejected.deadlineResult == "rejected")
    snapshot["sampled_at_unix_ms"] = 994_999
    let stale = try read()
    precondition(stale.status == "snapshot_stale")
    snapshot["sampled_at_unix_ms"] = 1_002_001
    let skew = try read()
    precondition(skew.status == "snapshot_clock_skew")
    snapshot["sampled_at_unix_ms"] = 1_000_000
    snapshot["producer_state"] = "stopped"
    let stopped = try read()
    precondition(stopped.status == "producer_stopped")
    snapshot["private"] = "DO_NOT_ECHO"
    let invalid = try read()
    precondition(invalid.status == "invalid_or_unavailable_snapshot" && invalid.payload.isEmpty)
    let wrongRole = LeaseObservationPresentation.read(containerURL: directory, role: "ios_app", now: now)
    precondition(wrongRole.deadlineResult == "unverified" && wrongRole.payload.isEmpty)
    print("iOS observer presentation: passive negative control, actual selections, freshness, stopped producer and private-field rejection passed; no iOS device execution")
  }
}
