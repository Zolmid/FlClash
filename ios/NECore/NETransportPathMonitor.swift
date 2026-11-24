import Foundation
import Network

struct NETransportPath: Equatable {
  let available: Bool
  let interfaces: [String]
  let ipv4: Bool
  let ipv6: Bool
  let dns: Bool

  init(available: Bool, interfaces: [String], ipv4: Bool, ipv6: Bool, dns: Bool) {
    self.available = available
    self.interfaces = interfaces.sorted()
    self.ipv4 = ipv4
    self.ipv6 = ipv6
    self.dns = dns
  }

  init(_ path: NWPath) {
    self.init(available: path.status == .satisfied,
      interfaces: path.availableInterfaces.filter { path.usesInterfaceType($0.type) }.map { "\($0.type):\($0.index):\($0.name)" },
      ipv4: path.supportsIPv4, ipv6: path.supportsIPv6, dns: path.supportsDNS)
  }
}

protocol NETransportPathSource: AnyObject {
  func start(queue: DispatchQueue, update: @escaping (NETransportPath) -> Void)
  func cancel()
}

private final class NESystemTransportPathSource: NETransportPathSource {
  private let monitor = NWPathMonitor()

  func start(queue: DispatchQueue, update: @escaping (NETransportPath) -> Void) {
    monitor.pathUpdateHandler = { update(NETransportPath($0)) }
    monitor.start(queue: queue)
  }

  func cancel() {
    monitor.pathUpdateHandler = nil
    monitor.cancel()
  }
}

final class NETransportPathMonitor {
  private let queue = DispatchQueue(label: "com.zolmid.zolnit.ne-transport-path")
  private let makeSource: () -> NETransportPathSource
  private let reset: () -> Void
  private var lifetime: UUID?
  private var source: NETransportPathSource?
  private var previous: NETransportPath?

  init(makeSource: @escaping () -> NETransportPathSource = { NESystemTransportPathSource() },
    reset: @escaping () -> Void) {
    self.makeSource = makeSource
    self.reset = reset
  }

  deinit { source?.cancel() }

  func begin() -> UUID {
    queue.sync {
      cancelSource()
      let token = UUID()
      lifetime = token
      return token
    }
  }

  @discardableResult
  func start(_ token: UUID, startCore: () -> Bool) -> Bool {
    queue.sync {
      guard lifetime == token, source == nil, startCore() else { return false }
      let next = makeSource()
      source = next
      next.start(queue: queue) { [weak self] path in
        guard let self else { return }
        self.queue.async { [weak self] in self?.receive(path, token: token) }
      }
      return true
    }
  }

  func isCurrent(_ token: UUID) -> Bool {
    queue.sync { lifetime == token }
  }

  func stop() {
    queue.sync {
      lifetime = nil
      cancelSource()
    }
  }

  private func cancelSource() {
    source?.cancel()
    source = nil
    previous = nil
  }

  private func receive(_ path: NETransportPath, token: UUID) {
    guard lifetime == token, source != nil else { return }
    let old = previous
    previous = path
    if let old, old != path, path.available { reset() }
  }
}
