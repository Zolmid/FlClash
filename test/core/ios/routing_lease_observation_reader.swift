import Foundation

@main enum ObservationReaderCheck {
  static func main() throws {
    let fm = FileManager.default
    let directory = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try fm.createDirectory(at: directory.appendingPathComponent("diagnostics"), withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: directory) }
    let file = directory.appendingPathComponent("diagnostics/lease-observation-ios_extension.json")
    let state: [String: Any] = [
      "instance_tag": String(repeating: "a", count: 64), "configuration_generation": 1,
      "lease_present": true, "revoked": false, "deadline_elapsed": true,
      "remaining_ms": 0, "groups": [["index": 0, "mode": "auto", "automatic": "proxy"]],
    ]
    var object: [String: Any] = [
      "schema_version": 1, "kind": "zolnit_routing_lease_observation", "core_version": "v1.19.32",
      "producer_pid": 42, "platform": "ios", "role": "ios_extension", "sampled_at_unix_ms": 1000,
      "uptime_ms": 10, "producer_state": "running", "state": state, "events": [],
    ]
    let before = try JSONSerialization.data(withJSONObject: object)
    try before.write(to: file)
    let data = try RoutingLeaseObservationReader.read(containerURL: directory)
    let result = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    precondition((result["state"] as! [String: Any])["revoked"] as? Bool == false)
    let after = try Data(contentsOf: file)
    precondition(after == before)
    object["guard"] = "PRIVATE"
    try JSONSerialization.data(withJSONObject: object).write(to: file)
    do { _ = try RoutingLeaseObservationReader.read(containerURL: directory); fatalError("private field accepted") }
    catch RoutingLeaseObservationReadError.invalidSnapshot { }
    object.removeValue(forKey: "guard")
    object["role"] = "ios_app"
    try JSONSerialization.data(withJSONObject: object).write(to: file)
    do { _ = try RoutingLeaseObservationReader.read(containerURL: directory); fatalError("wrong role accepted") }
    catch RoutingLeaseObservationReadError.invalidSnapshot { }
    print("Foundation reader: passive expired negative control, unchanged file, private fields and role checks passed; no device/Extension execution")
  }
}
