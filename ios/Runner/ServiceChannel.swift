import Flutter
import Foundation
import os
import Shared

@MainActor
private final class CoreMessageRouterReference {
  weak var value: CoreMessageRouter?
}

enum QuickAction: String {
  case start
  case stop
  case toggle

  var command: TunnelIntentAuthority.Command {
    switch self {
    case .start: return .start
    case .stop: return .stop
    case .toggle: return .toggle
    }
  }
}

@MainActor
final class ServiceChannel {
  private static var instance: ServiceChannel?
  private static let pendingQuickAction = PendingTunnelIntent()
  private static let quickActionAuthority = TunnelIntentAuthority(appGroup: NEHelper.appGroupIdentifier)

  private static let packageName = "com.zolmid.zolnit"
  private let channel: FlutterMethodChannel
  private let tileChannel: FlutterMethodChannel
  private let sharedStateStore: SharedStateStore
  private let tunnelController: TunnelController
  private let coreMessageRouter: CoreMessageRouter
  private let coreEventRelay: CoreEventRelay
  private lazy var bundleRenewal = ClientBundleSessionBridge(tunnel: tunnelController)
  private var isInitialized = false
  private var quickActionDrain: Task<Void, Never>?
  private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.zolmid.zolnit",
    category: "ServiceChannel"
  )

  static func register(with messenger: FlutterBinaryMessenger) {
    let serviceChannel = ServiceChannel(messenger: messenger)
    instance = serviceChannel
  }

  @discardableResult
  static func request(_ action: QuickAction) async -> Bool {
    if let instance, instance.sharedStateStore.isSafeMode { return false }
    do {
      let token = try await quickActionAuthority.registerWithRetry(action.command)
      if let instance, instance.sharedStateStore.isSafeMode {
        quickActionAuthority.cancel(token)
        return false
      }
      pendingQuickAction.register { token }
      if let instance, instance.isInitialized { instance.drainQuickActions() }
      return true
    } catch {
      return false
    }
  }

  private func drainQuickActions() {
    guard quickActionDrain == nil else { return }
    quickActionDrain = Task { @MainActor [weak self] in
      guard let self else { return }
      defer { self.quickActionDrain = nil }
      while let token = Self.pendingQuickAction.token {
        if self.sharedStateStore.isSafeMode {
          Self.pendingQuickAction.remove(token)
          do { try Self.quickActionAuthority.finish(token) }
          catch { Self.quickActionAuthority.cancel(token) }
          continue
        }
        do {
          guard try Self.quickActionAuthority.isCurrent(token) else {
            Self.pendingQuickAction.remove(token)
            continue
          }
          if self.tunnelController.submitRegisteredIntent(token) {
            Self.pendingQuickAction.remove(token)
            continue
          }
        } catch {
          self.log("quick action authority unavailable; retaining accepted request")
        }
        do { try await Task.sleep(nanoseconds: 250_000_000) } catch { return }
      }
    }
  }

  private init(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "\(Self.packageName)/service",
      binaryMessenger: messenger
    )
    let tileChannel = FlutterMethodChannel(
      name: "\(Self.packageName)/tile",
      binaryMessenger: messenger
    )
    let sharedStateStore = SharedStateStore()
    let routerReference = CoreMessageRouterReference()
    let tunnelController = TunnelController(
      sharedStateStore: sharedStateStore,
      onTunnelStateChanged: { state in
        routerReference.value?.updateTunnelState(state)
      },
      onConnectionStateChanged: { state in
        channel.invokeMethod("tunnelState", arguments: state)
      },
      onExternalStart: {
        tileChannel.invokeMethod("syncRunningState", arguments: [
          "running": true,
          "startTime": sharedStateStore.runTime(),
        ])
      },
      onExternalStop: {
        tileChannel.invokeMethod("syncRunningState", arguments: [
          "running": false,
          "startTime": 0,
        ])
      }
    )
    let coreMessageRouter = CoreMessageRouter(
      tunnelController: tunnelController
    )
    routerReference.value = coreMessageRouter
    let coreEventRelay = CoreEventRelay(
      sharedStateStore: sharedStateStore,
      sendEvent: { event, completion in
        channel.invokeMethod("event", arguments: event) { callbackResult in
          completion(callbackResult == nil)
        }
      }
    )

    self.channel = channel
    self.tileChannel = tileChannel
    self.sharedStateStore = sharedStateStore
    self.tunnelController = tunnelController
    self.coreMessageRouter = coreMessageRouter
    self.coreEventRelay = coreEventRelay

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterMethodNotImplemented)
        return
      }
      self.handle(call, result: result)
    }
    coreEventRelay.start()
    tunnelController.startObserving()
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    log("handle method=\(call.method)")
    switch call.method {
    case "configureClientBundleRenewal", "logoutClientBundleRenewal", "clientBundleRenewalStatus":
      Task {
        do {
          if call.method == "logoutClientBundleRenewal" {
            result(try await bundleRenewal.logout(call.arguments))
          } else {
            let status = call.method == "configureClientBundleRenewal"
              ? try await bundleRenewal.configure(call.arguments) : try await bundleRenewal.status()
            let data = try JSONEncoder().encode(status)
            result(try JSONSerialization.jsonObject(with: data))
          }
        } catch {
          result(FlutterError(code: "BUNDLE_RENEWAL_ERROR",
            message: "Native bundle renewal operation did not complete", details: nil))
        }
      }
    case "invokeMethod":
      guard let data = methodCallData(call) else {
        result(invalidMethodCallResponse)
        return
      }
      Task {
        result(await coreMessageRouter.invoke(data))
      }
    case "start":
      guard !sharedStateStore.isSafeMode else {
        result(false)
        return
      }
      guard saveSharedState(call) else {
        result(false)
        return
      }
      Task { result(await tunnelController.start()) }
    case "stop":
      guard !sharedStateStore.isSafeMode else {
        result(false)
        return
      }
      Task { result(await tunnelController.stop()) }
    case "abandonStart":
      Task { result(await tunnelController.abandonStart(call.arguments as? String).rawValue) }
    case "init":
      sharedStateStore.setSafeMode(call.arguments as? Bool ?? false)
      isInitialized = true
      drainQuickActions()
      tunnelController.publishConnectionState()
      coreEventRelay.drainEventQueue()
      result("")
    case "syncState":
      syncState(call, result: result)
    case "shutdown":
      Task {
        result(await coreMessageRouter.shutdownAppCore())
      }
    case "getRunTime":
      Task {
        result(await tunnelController.getRunTime())
      }
    case "getActiveVpnOptions":
      Task {
        let running = await tunnelController.getRunTime() > 0
        result(running ? sharedStateStore.activeVpnOptions() : nil)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func methodCallData(_ call: FlutterMethodCall) -> Data? {
    guard let message = call.arguments as? String else {
      return nil
    }
    return message.data(using: .utf8)
  }

  private func syncState(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard saveSharedState(call) else {
      result("failed to sync shared state")
      return
    }
    result("")
    guard !sharedStateStore.isSafeMode else {
      return
    }
    Task {
      do {
        try await tunnelController.reloadOnDemandRules()
      } catch {
        log("syncState preferences failed: \(error.localizedDescription)")
      }
    }
  }

  private func saveSharedState(_ call: FlutterMethodCall) -> Bool {
    guard let data = methodCallData(call),
      sharedStateStore.saveSharedState(data)
    else {
      log("saveSharedState failed")
      return false
    }
    log("saveSharedState bytes=\(data.count)")
    return true
  }

  private var invalidMethodCallResponse: String {
    #"{"result":null,"error":{"code":"invalid_method_call","message":"invalid method call","details":null}}"#
  }

  private func log(_ message: String) {
    logger.debug("\(message, privacy: .public)")
  }
}
