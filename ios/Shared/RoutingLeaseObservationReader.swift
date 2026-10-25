import CoreFoundation
import Foundation

public enum RoutingLeaseObservationReadError: Error {
  case unavailable
  case oversized
  case invalidSnapshot
  case roleMismatch
}

public enum RoutingLeaseObservationReader {
  private static let maxBytes = 32768
  private static let snapshotKeys: Set<String> = [
    "schema_version", "kind", "core_version", "producer_pid", "platform", "role",
    "sampled_at_unix_ms", "uptime_ms", "producer_state", "state", "events",
  ]
  private static let stateKeys: Set<String> = [
    "instance_tag", "configuration_generation", "lease_present", "revoked",
    "deadline_elapsed", "remaining_ms", "groups",
  ]

  public static func read(containerURL: URL, role: String = "ios_extension") throws -> Data {
    guard ["ios_app", "ios_extension"].contains(role) else {
      throw RoutingLeaseObservationReadError.roleMismatch
    }
    let file = containerURL.appendingPathComponent("diagnostics", isDirectory: true)
      .appendingPathComponent("lease-observation-\(role).json")
    guard let attributes = try? FileManager.default.attributesOfItem(atPath: file.path),
      attributes[.type] as? FileAttributeType == .typeRegular,
      (attributes[.size] as? NSNumber)?.intValue ?? maxBytes + 1 <= maxBytes,
      let handle = try? FileHandle(forReadingFrom: file)
    else { throw RoutingLeaseObservationReadError.unavailable }
    defer { try? handle.close() }
    var data = Data()
    while data.count <= maxBytes {
      let chunk = try handle.read(upToCount: min(4096, maxBytes + 1 - data.count)) ?? Data()
      if chunk.isEmpty { break }
      data.append(chunk)
    }
    guard data.count <= maxBytes else { throw RoutingLeaseObservationReadError.oversized }
    guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      Set(root.keys) == snapshotKeys,
      integer(root["schema_version"]) == 1,
      root["kind"] as? String == "zolnit_routing_lease_observation",
      root["platform"] as? String == "ios",
      root["role"] as? String == role,
      let pid = integer(root["producer_pid"]), pid > 0,
      let sampled = integer(root["sampled_at_unix_ms"]), sampled >= 0,
      let uptime = integer(root["uptime_ms"]), uptime >= 0,
      let version = root["core_version"] as? String, !version.isEmpty, version.utf8.count <= 128,
      version.unicodeScalars.allSatisfy({ $0.value >= 33 && $0.value <= 126 }),
      ["running", "stopped"].contains(root["producer_state"] as? String ?? ""),
      validState(root["state"]),
      let events = root["events"] as? [[String: Any]], events.count <= 8
    else { throw RoutingLeaseObservationReadError.invalidSnapshot }
    var sequence = 0
    for event in events {
      let keys = Set(event.keys)
      guard keys.isSubset(of: ["sequence", "at_unix_ms", "uptime_ms", "kind", "reason", "state"]),
        let next = integer(event["sequence"]), next > sequence,
        let time = integer(event["at_unix_ms"]), time >= 0,
        let elapsed = integer(event["uptime_ms"]), elapsed >= 0, elapsed <= uptime,
        token(event["kind"]), event["reason"] == nil || token(event["reason"]),
        validState(event["state"])
      else { throw RoutingLeaseObservationReadError.invalidSnapshot }
      sequence = next
    }
    return try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])
  }

  #if os(iOS)
  public static func read(appGroupIdentifier: String, role: String = "ios_extension") throws -> Data {
    guard let directory = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: appGroupIdentifier
    ) else { throw RoutingLeaseObservationReadError.unavailable }
    return try read(containerURL: directory, role: role)
  }
  #endif

  private static func integer(_ value: Any?) -> Int? {
    guard let number = value as? NSNumber,
      CFGetTypeID(number) != CFBooleanGetTypeID(),
      number.doubleValue.isFinite,
      number.doubleValue.rounded(.towardZero) == number.doubleValue,
      abs(number.doubleValue) < 9_007_199_254_740_992
    else { return nil }
    return number.intValue
  }

  private static func boolean(_ value: Any?) -> Bool {
    guard let number = value as? NSNumber else { return false }
    return CFGetTypeID(number) == CFBooleanGetTypeID()
  }

  private static func tag(_ value: Any?) -> Bool {
    guard let text = value as? String, text.utf8.count == 64 else { return false }
    return text.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
  }

  private static func token(_ value: Any?) -> Bool {
    guard let text = value as? String, !text.isEmpty, text.utf8.count <= 40 else { return false }
    return text.utf8.allSatisfy { (97...122).contains($0) || $0 == 95 }
  }

  private static func validState(_ value: Any?) -> Bool {
    guard let state = value as? [String: Any], Set(state.keys) == stateKeys,
      tag(state["instance_tag"]),
      let generation = integer(state["configuration_generation"]), generation >= 0,
      boolean(state["lease_present"]), boolean(state["revoked"]), boolean(state["deadline_elapsed"]),
      integer(state["remaining_ms"]) != nil,
      let groups = state["groups"] as? [[String: Any]], groups.count <= 16
    else { return false }
    var indices = Set<Int>()
    for group in groups {
      guard Set(group.keys).isSubset(of: ["index", "mode", "automatic", "manual_tag"]),
        let index = integer(group["index"]), (0..<16).contains(index), indices.insert(index).inserted,
        ["auto", "manual", "direct", "other"].contains(group["mode"] as? String ?? ""),
        ["reject", "proxy", "missing"].contains(group["automatic"] as? String ?? ""),
        group["manual_tag"] == nil || tag(group["manual_tag"])
      else { return false }
    }
    return true
  }
}
