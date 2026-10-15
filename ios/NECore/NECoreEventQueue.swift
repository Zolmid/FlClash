import Foundation
import Shared
import os

final class NECoreEventQueue {
  private let sharedStateStore: PacketTunnelSharedStateStore
  private let eventQueueDirectoryName = "core-events"
  private let lock = NSLock()
  private let logger = Logger(
    subsystem: PacketTunnelEnvironment.extensionBundleIdentifier,
    category: "NECoreEventQueue"
  )

  private var backlog: CoreEventBacklog?

  init(sharedStateStore: PacketTunnelSharedStateStore) {
    self.sharedStateStore = sharedStateStore
  }

  func start() {
    markCoreResponsive()
    NECoreBridge.setEventListener { [weak self] event in
      guard let self,
        let event,
        !event.isEmpty
      else {
        return
      }
      self.enqueue(event)
    }
  }

  func stop() {
    NECoreBridge.setEventListener(nil)
  }

  func markCoreResponsive() {
    lock.lock()
    defer { lock.unlock() }
    backlog?.resumeTransientEvents()
  }

  private func enqueue(_ event: Data) {
    lock.lock()
    defer { lock.unlock() }
    guard let directory = eventQueueDirectory() else {
      logger.error("enqueue failed: missing app group dir")
      return
    }
    do {
      let backlog = self.backlog ?? CoreEventBacklog(directory: directory)
      self.backlog = backlog
      let result = try backlog.enqueue(event)
      if result.rejectedStateEvents > 0 {
        logger.error(
          "state backlog capacity exceeded: \(result.rejectedStateEvents, privacy: .public)"
        )
      }
      if result.wroteEvents {
        notifyEventAvailable()
      }
    } catch {
      logger.error(
        "enqueue failed: \(error.localizedDescription, privacy: .public)"
      )
      notifyEventAvailable()
    }
  }

  private func eventQueueDirectory() -> URL? {
    sharedStateStore.appGroupDirectory()?.appendingPathComponent(
      eventQueueDirectoryName,
      isDirectory: true
    )
  }

  private func notifyEventAvailable() {
    CFNotificationCenterPostNotification(
      CFNotificationCenterGetDarwinNotifyCenter(),
      CFNotificationName(
        PacketTunnelEnvironment.eventNotificationName as CFString
      ),
      nil,
      nil,
      true
    )
  }
}
