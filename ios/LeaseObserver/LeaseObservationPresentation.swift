import Foundation

struct LeaseObservationPresentation: Sendable {
  let status: String
  let deadlineResult: String
  let payload: String

  static let unavailable = Self(status: "observation_unavailable", deadlineResult: "unverified", payload: "")

  static func read(containerURL: URL, role: String, now: Date = Date()) -> Self {
    do {
      let data = try RoutingLeaseObservationReader.read(containerURL: containerURL, role: role)
      guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
        let state = root["state"] as? [String: Any],
        let sampled = root["sampled_at_unix_ms"] as? NSNumber,
        let groups = state["groups"] as? [[String: Any]]
      else { return unavailable }
      let age = now.timeIntervalSince1970 * 1000 - sampled.doubleValue
      let status: String
      if root["producer_state"] as? String == "stopped" {
        status = "producer_stopped"
      } else if age < -2000 {
        status = "snapshot_clock_skew"
      } else if age > 5000 {
        status = "snapshot_stale"
      } else {
        status = "snapshot_fresh"
      }
      let result: String
      if state["lease_present"] as? Bool != true || groups.isEmpty {
        result = "not_applicable"
      } else if state["deadline_elapsed"] as? Bool != true && state["revoked"] as? Bool != true {
        result = "pending"
      } else if groups.contains(where: { $0["automatic"] as? String == "proxy" }) {
        result = "not_rejected"
      } else if groups.contains(where: { $0["automatic"] as? String == "missing" }) {
        result = "unverified"
      } else {
        result = "rejected"
      }
      let pretty = try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys, .prettyPrinted])
      return Self(status: status, deadlineResult: result, payload: String(decoding: pretty, as: UTF8.self))
    } catch {
      return Self(status: "invalid_or_unavailable_snapshot", deadlineResult: "unverified", payload: "")
    }
  }
}
