import Foundation

public struct CoreEventEnqueueResult {
  public let wroteEvents: Bool
  public let rejectedStateEvents: Int
}

public final class CoreEventBacklog {
  private enum StateKind: String, CaseIterable {
    case loaded
    case geoUpdate
    case routeChanged

    func key(for message: [String: Any]) -> String? {
      switch self {
      case .loaded:
        return message["data"] as? String
      case .geoUpdate:
        return (message["data"] as? [String: Any])?["type"] as? String
      case .routeChanged:
        return rawValue
      }
    }
  }

  private enum BacklogError: Error {
    case invalidBatch
  }

  private let directory: URL
  private let maxTransientFiles: Int
  private let maxStateKeys: Int
  private let maxStateBytes = 4 * 1024 * 1024
  private let maxTransientBytes = 512 * 1024
  private var lastTimestamp: UInt64 = 0

  public private(set) var transientEventsPaused = false

  public init(
    directory: URL,
    maxTransientFiles: Int = 10,
    maxStateKeys: Int = 256
  ) {
    precondition(maxTransientFiles > 0 && maxStateKeys > 0)
    self.directory = directory
    self.maxTransientFiles = maxTransientFiles
    self.maxStateKeys = maxStateKeys
  }

  public func resumeTransientEvents() {
    transientEventsPaused = false
  }

  @discardableResult
  public func enqueue(_ data: Data) throws -> CoreEventEnqueueResult {
    let messages = try decodeBatch(data)
    try FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true
    )
    var stateMessages: [StateKind: [[String: Any]]] = [:]
    var transientMessages: [[String: Any]] = []
    for message in messages {
      if let type = message["type"] as? String,
        let kind = StateKind(rawValue: type),
        kind.key(for: message) != nil
      {
        stateMessages[kind, default: []].append(message)
      } else {
        transientMessages.append(message)
      }
    }

    var wroteEvents = false
    var rejectedStateEvents = 0
    for kind in StateKind.allCases {
      guard let incoming = stateMessages[kind] else {
        continue
      }
      let result = try mergeState(incoming, kind: kind)
      wroteEvents = wroteEvents || result.wroteEvents
      rejectedStateEvents += result.rejectedStateEvents
    }

    if !transientEventsPaused && !transientMessages.isEmpty {
      let transientData = try encodeBatch(transientMessages)
      if transientData.count <= maxTransientBytes {
        try write(transientData, category: "transient")
        wroteEvents = true
        try pruneTransientEvents()
      }
    }
    return CoreEventEnqueueResult(
      wroteEvents: wroteEvents,
      rejectedStateEvents: rejectedStateEvents
    )
  }

  private func mergeState(
    _ incoming: [[String: Any]],
    kind: StateKind
  ) throws -> CoreEventEnqueueResult {
    let previousFiles = try eventFiles().filter {
      $0.lastPathComponent.contains("-state-\(kind.rawValue)-")
    }
    var retained: [String: [String: Any]] = [:]
    if let previous = previousFiles.last,
      let data = try? Data(contentsOf: previous),
      let messages = try? decodeBatch(data)
    {
      for message in messages {
        if let key = kind.key(for: message) {
          retained[key] = message
        }
      }
    }

    var encoded: Data?
    var rejectedStateEvents = 0
    for message in incoming {
      guard let key = kind.key(for: message) else {
        continue
      }
      let previous = retained[key]
      if previous == nil && retained.count >= maxStateKeys {
        rejectedStateEvents += 1
        continue
      }
      retained[key] = message
      let candidate = try encodeBatch(retained.keys.sorted().compactMap { retained[$0] })
      guard candidate.count <= maxStateBytes else {
        retained[key] = previous
        rejectedStateEvents += 1
        continue
      }
      encoded = candidate
    }
    guard let encoded else {
      return CoreEventEnqueueResult(
        wroteEvents: false,
        rejectedStateEvents: rejectedStateEvents
      )
    }

    // A consumer may still be acknowledging the previous path. Publish a new
    // generation so that acknowledgment cannot delete its replacement.
    try write(encoded, category: "state-\(kind.rawValue)")
    for file in previousFiles {
      try removeIfPresent(file)
    }
    return CoreEventEnqueueResult(
      wroteEvents: true,
      rejectedStateEvents: rejectedStateEvents
    )
  }

  private func pruneTransientEvents() throws {
    let files = try eventFiles().filter {
      !$0.lastPathComponent.contains("-state-")
    }
    guard files.count > maxTransientFiles else {
      return
    }
    transientEventsPaused = true
    for file in files.prefix(files.count - maxTransientFiles) {
      try removeIfPresent(file)
    }
  }

  private func eventFiles() throws -> [URL] {
    try FileManager.default.contentsOfDirectory(
      at: directory,
      includingPropertiesForKeys: [.isRegularFileKey]
    ).filter {
      $0.pathExtension == "json" &&
        (try? $0.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true
    }.sorted { $0.lastPathComponent < $1.lastPathComponent }
  }

  private func write(_ data: Data, category: String) throws {
    if lastTimestamp == 0 {
      lastTimestamp = try eventFiles().compactMap {
        UInt64($0.lastPathComponent.split(separator: "-").first ?? "")
      }.max() ?? 0
    }
    let timestamp = UInt64(Date().timeIntervalSince1970 * 1_000_000)
    lastTimestamp = max(timestamp, lastTimestamp + 1)
    let file = directory.appendingPathComponent(
      "\(lastTimestamp)-\(category)-\(UUID().uuidString).json"
    )
    try data.write(to: file, options: .atomic)
  }

  private func removeIfPresent(_ file: URL) throws {
    do {
      try FileManager.default.removeItem(at: file)
    } catch let error as NSError where error.domain == NSCocoaErrorDomain &&
      error.code == NSFileNoSuchFileError {
    }
  }

  private func decodeBatch(_ data: Data) throws -> [[String: Any]] {
    guard let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      payload["method"] as? String == "message",
      let messages = payload["arguments"] as? [[String: Any]]
    else {
      throw BacklogError.invalidBatch
    }
    return messages
  }

  private func encodeBatch(_ messages: [[String: Any]]) throws -> Data {
    try JSONSerialization.data(withJSONObject: [
      "method": "message",
      "arguments": messages,
    ])
  }
}
