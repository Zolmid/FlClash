import Foundation
import NetworkExtension
import Shared
import os

@MainActor
private final class TunnelOperation<Value> {
  var continuation: CheckedContinuation<Value, Error>?
  var task: Task<Void, Never>?

  init(_ continuation: CheckedContinuation<Value, Error>) { self.continuation = continuation }

  func finish(_ result: Result<Value, Error>) {
    guard let continuation else { return }
    self.continuation = nil
    task = nil
    continuation.resume(with: result)
  }

  func cancel() {
    task?.cancel()
    finish(.failure(TunnelIntentError.superseded))
  }
}

@MainActor
final class TunnelCoordinator {
  private let managerStore: any TunnelManagerAccess
  private let authority: TunnelIntentAuthority
  private let isSafeMode: () -> Bool
  private var intentMonitor: Task<Void, Never>?
  private let onTunnelStateChanged: (TunnelTarget) -> Void
  private let onConnectionStateChanged: (String) -> Void
  private let onExternalStart: () -> Void
  private let onExternalStop: () -> Void
  private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.zolmid.zolnit",
    category: "TunnelCoordinator"
  )

  private var observedTunnelStatus: NEVPNStatus?
  private var reportedTunnelState: TunnelTarget?
  private var publishedTunnelState: TunnelTarget?

  private var requestGeneration: UInt64 = 0
  private var tunnelRequest: TunnelRequest?
  private var tunnelWait: TunnelWait?
  private var isCoordinatorRunning = false

  private var configurationContinuations: [CheckedContinuation<Void, Error>] = []
  private var needsStatusRefresh = false
  private var statusRefreshShouldNotify = false

  init(
    managerStore: any TunnelManagerAccess,
    authority: TunnelIntentAuthority,
    isSafeMode: @escaping () -> Bool,
    onTunnelStateChanged: @escaping (TunnelTarget) -> Void,
    onConnectionStateChanged: @escaping (String) -> Void,
    onExternalStart: @escaping () -> Void,
    onExternalStop: @escaping () -> Void
  ) {
    self.managerStore = managerStore
    self.authority = authority
    self.isSafeMode = isSafeMode
    self.onTunnelStateChanged = onTunnelStateChanged
    self.onConnectionStateChanged = onConnectionStateChanged
    self.onExternalStart = onExternalStart
    self.onExternalStop = onExternalStop
  }

  @discardableResult
  func submitTunnelRequest(target: TunnelTarget) async -> Bool {
    await submit(target == .running ? .start : .stop) != nil
  }

  @discardableResult
  func toggleTunnelRequest() async -> Bool { await submit(.toggle) != nil }

  func startForFlutter() async -> String? { await submit(.start)?.id.uuidString }

  /// A failed start's cleanup must not replace a Widget or Shortcut intent registered after it.
  func abandonStart(_ startHandle: String?) async -> StartAbandonment {
    guard !isSafeMode(), let startHandle, let id = UUID(uuidString: startHandle)
    else { return .notOwned }
    let owned = TunnelIntentAuthority.Token(id: id)
    for retry in 0...20 {
      do {
        try Task.checkCancellation()
        let token = try authority.register(.stop, replacing: owned)
        return accept(token, target: .stopped, checkCurrent: false) ? .stopped : .failed
      } catch TunnelIntentError.superseded {
        return .notOwned
      } catch TunnelIntentError.busy where retry < 20 {
        do { try await Task.sleep(nanoseconds: 50_000_000) }
        catch { return .failed }
      } catch {
        return .failed
      }
    }
    return .failed
  }

  private func submit(_ command: TunnelIntentAuthority.Command) async -> TunnelIntentAuthority.Token? {
    guard !isSafeMode() else { return nil }
    let token: TunnelIntentAuthority.Token
    let target: TunnelTarget?
    do {
      token = try await authority.registerWithRetry(command)
      switch command {
      case .start: target = .running
      case .stop: target = .stopped
      case .toggle: target = nil
      }
    } catch {
      log("intent registration failed")
      return nil
    }
    return accept(token, target: target, checkCurrent: false) ? token : nil
  }

  @discardableResult
  func submitRegisteredIntent(_ token: TunnelIntentAuthority.Token) -> Bool {
    accept(token, target: nil, checkCurrent: true)
  }

  private func accept(
    _ token: TunnelIntentAuthority.Token, target: TunnelTarget?, checkCurrent: Bool
  ) -> Bool {
    guard !isSafeMode() else {
      do { try authority.finish(token) } catch { authority.cancel(token) }
      return false
    }
    if checkCurrent {
      do {
        guard try authority.isCurrent(token) else { return false }
      } catch {
        return false
      }
    }
    requestGeneration &+= 1
    let request = TunnelRequest(generation: requestGeneration, token: token, target: target)
    tunnelRequest?.cancelOperation?()
    tunnelRequest = request
    if let target { publishedTunnelState = target }
    cancelTunnelWait()
    publishConnectionState()
    log("request target=\(request.description) generation=\(request.generation)")
    intentMonitor?.cancel()
    intentMonitor = Task { [weak self, weak request] in
      while !Task.isCancelled {
        do { try await Task.sleep(nanoseconds: 50_000_000) } catch { return }
        guard let self, let request, self.isCurrent(request) else { return }
      }
    }
    driveCoordinator()
    return true
  }

  var hasPendingWork: Bool { tunnelRequest != nil || tunnelWait != nil || isCoordinatorRunning }

  func reloadOnDemandRules() async throws {
    try await withCheckedThrowingContinuation {
      (continuation: CheckedContinuation<Void, Error>) in
      configurationContinuations.append(continuation)
      driveCoordinator()
    }
  }

  func requestStatusRefresh(notifyExternal: Bool) {
    needsStatusRefresh = true
    statusRefreshShouldNotify =
      statusRefreshShouldNotify || notifyExternal
    driveCoordinator()
  }

  func publishConnectionState() {
    let state: String
    if tunnelRequest != nil {
      state = "pending"
    } else {
      switch observedTunnelStatus {
      case .connected:
        state = "connected"
      case .disconnected, .invalid:
        state = "disconnected"
      default:
        state = "pending"
      }
    }
    onConnectionStateChanged(state)
  }

  func handleTunnelStatusNotification(_ notification: Notification) {
    guard let connection = notification.object as? NEVPNConnection,
      managerStore.isManagedConnection(connection)
    else {
      return
    }

    if let wait = tunnelWait,
      wait.manager.connection === connection
    {
      recordObservedTunnelStatus(
        connection.status,
        notifyExternal: false
      )
      return
    }
    guard tunnelWait == nil,
      managerStore.isCachedConnection(connection)
    else {
      return
    }
    recordObservedTunnelStatus(
      connection.status,
      notifyExternal: true
    )
  }

  private func driveCoordinator() {
    guard !isCoordinatorRunning else {
      return
    }
    isCoordinatorRunning = true
    Task { [weak self] in
      await self?.runCoordinator()
    }
  }

  private func runCoordinator() async {
    while true {
      if let request = tunnelRequest {
        await reconcileTunnel(request)
        if tunnelRequest === request {
          try? await Task.sleep(nanoseconds: 50_000_000)
        }
        continue
      }

      if !configurationContinuations.isEmpty {
        let continuations = configurationContinuations
        configurationContinuations.removeAll()
        let error = await performOnDemandRulesReload()
        for continuation in continuations {
          if let error {
            continuation.resume(throwing: error)
          } else {
            continuation.resume()
          }
        }
        continue
      }

      if needsStatusRefresh {
        let notifyExternal = statusRefreshShouldNotify
        needsStatusRefresh = false
        statusRefreshShouldNotify = false
        await performStatusRefresh(notifyExternal: notifyExternal)
        continue
      }

      isCoordinatorRunning = false
      return
    }
  }

  private func reconcileTunnel(_ request: TunnelRequest) async {
    while isCurrent(request) {
      do {
        if request.target == nil {
          let manager = try await awaitRequestOperation(request) {
            try await self.managerStore.loadManager(createIfNeeded: false)
          }
          guard isCurrent(request) else { return }
          let running = try authority.resolve(request.token,
            observedRunning: manager.map { NEHelper.isRunning($0.connection.status) } ?? false)
          request.target = running ? .running : .stopped
          publishedTunnelState = request.target
        }
        switch request.target {
        case .running:
          try await reconcileRunningTunnel(request)
        case .stopped:
          try await reconcileStoppedTunnel(request)
        case nil:
          return
        }
        return
      } catch {
        guard isCurrent(request) else {
          return
        }
        if case TunnelIntentError.busy = error {
          try? await Task.sleep(nanoseconds: 50_000_000)
          continue
        }
        let status = observedTunnelStatus
        if request.preferenceRetryCount == 0,
          managerStore.invalidateCachedManager(forPreferenceError: error)
        {
          request.preferenceRetryCount += 1
          log(
            "\(request.description) retry preferences: \(error.localizedDescription)"
          )
          continue
        }
        log(
          "\(request.description) failed: \(error.localizedDescription)"
        )
        finishTunnelRequest(
          request,
          actualState: stableFailureState(status)
        )
        return
      }
    }
  }

  private func reconcileRunningTunnel(
    _ request: TunnelRequest
  ) async throws {
    while isCurrent(request) {
      let loadedManager = try await awaitRequestOperation(request) {
        try await self.managerStore.loadManager(createIfNeeded: true)
      }
      guard isCurrent(request) else {
        return
      }
      guard let manager = loadedManager else {
        recordObservedTunnelStatus(.invalid, notifyExternal: false)
        finishTunnelRequest(request, actualState: .stopped)
        return
      }

      guard managerStore.isManagedConnection(manager.connection) else {
        throw TunnelIntentError.unsafe
      }
      let status = manager.connection.status
      recordObservedTunnelStatus(status, notifyExternal: false)
      if status.tunnelState == .running {
        finishTunnelRequest(request, actualState: .running)
        return
      }
      if status.tunnelState == nil {
        guard await settleBeforeStart(manager: manager, request: request) else {
          return
        }
        continue
      }

      manager.isEnabled = true
      managerStore.applyNetworkExtensionOptions(to: manager, enableOnDemand: true)
      log("start save preferences")
      do {
        try await awaitRequestOperation(request) {
          try await self.awaitPreferenceResult { completion in
            manager.saveToPreferences(completionHandler: completion)
          }
        }
      } catch {
        guard isCurrent(request) else {
          return
        }
        if finishRunningRequestIfSatisfied(request, manager: manager) {
          return
        }
        throw error
      }
      guard isCurrent(request) else {
        return
      }

      log("start reload preferences")
      do {
        try await awaitRequestOperation(request) {
          try await self.awaitPreferenceResult { completion in
            manager.loadFromPreferences(completionHandler: completion)
          }
        }
      } catch {
        guard isCurrent(request) else {
          return
        }
        if finishRunningRequestIfSatisfied(request, manager: manager) {
          return
        }
        throw error
      }
      guard isCurrent(request) else {
        return
      }

      let preparedStatus = manager.connection.status
      recordObservedTunnelStatus(preparedStatus, notifyExternal: false)
      if preparedStatus.tunnelState == .running {
        finishTunnelRequest(request, actualState: .running)
        return
      }
      if preparedStatus.tunnelState == nil {
        guard await settleBeforeStart(manager: manager, request: request) else {
          return
        }
        continue
      }

      do {
        try authority.perform(request.token, running: true) {
          guard !isSafeMode(), !Task.isCancelled,
            managerStore.isManagedConnection(manager.connection)
          else { throw TunnelIntentError.unsafe }
          try manager.connection.startVPNTunnel()
        }
        log("start requested")
      } catch {
        if finishRunningRequestIfSatisfied(request, manager: manager) {
          return
        }
        throw error
      }

      let result = await waitForTunnelStatus(
        manager: manager,
        request: request,
        purpose: .starting
      )
      guard isCurrent(request) else {
        return
      }
      switch result {
      case .status(let status):
        finishTunnelRequest(
          request,
          actualState: status.tunnelState
        )
      case .superseded:
        return
      }
      return
    }
  }

  private func settleBeforeStart(
    manager: NETunnelProviderManager,
    request: TunnelRequest
  ) async -> Bool {
    let result = await waitForTunnelStatus(
      manager: manager,
      request: request,
      purpose: .settleThenStart
    )
    guard isCurrent(request) else {
      return false
    }
    switch result {
    case .status(let status):
      if status.tunnelState == .running {
        finishTunnelRequest(request, actualState: .running)
        return false
      }
      return true
    case .superseded:
      return false
    }
  }

  private func reconcileStoppedTunnel(
    _ request: TunnelRequest
  ) async throws {
    guard
      let manager = try await awaitRequestOperation(request, {
        try await self.managerStore.loadManager(createIfNeeded: false)
      })
    else {
      recordObservedTunnelStatus(.invalid, notifyExternal: false)
      finishTunnelRequest(request, actualState: .stopped)
      return
    }
    guard isCurrent(request) else {
      return
    }

    let status = manager.connection.status
    recordObservedTunnelStatus(status, notifyExternal: false)
    try authority.perform(request.token, running: false) {
      guard !isSafeMode(), !Task.isCancelled,
        managerStore.isManagedConnection(manager.connection)
      else { throw TunnelIntentError.unsafe }
      manager.connection.stopVPNTunnel()
    }
    log("stop command issued to Network Extension")
    if manager.connection.status.isTerminal {
      finishTunnelRequest(request, actualState: manager.connection.status.tunnelState)
      return
    }
    let result = await waitForTunnelStatus(
      manager: manager,
      request: request,
      purpose: .stopping
    )
    guard isCurrent(request) else {
      return
    }
    switch result {
    case .status(let status):
      finishTunnelRequest(
        request,
        actualState: status.tunnelState
      )
    case .superseded:
      return
    }
  }

  private func waitForTunnelStatus(
    manager: NETunnelProviderManager,
    request: TunnelRequest,
    purpose: TunnelWaitPurpose
  ) async -> TunnelWaitResult {
    await withCheckedContinuation { continuation in
      let wait = TunnelWait(
        request: request,
        purpose: purpose,
        manager: manager,
        continuation: continuation
      )
      tunnelWait = wait
      consumeWaitStatus(manager.connection.status)
    }
  }

  private func consumeWaitStatus(_ status: NEVPNStatus) {
    guard let wait = tunnelWait,
      isCurrent(wait.request)
    else {
      return
    }
    switch wait.purpose {
    case .starting:
      if status.tunnelState == .running {
        resolveTunnelWait(wait, result: .status(status))
        return
      }
      if status.isLifecycleActive {
        wait.hasObservedProgress = true
      }
      if status.isTerminal && wait.hasObservedProgress {
        resolveTunnelWait(wait, result: .status(status))
      }
    case .stopping:
      if status.isTerminal {
        resolveTunnelWait(wait, result: .status(status))
      }
    case .settleThenStart:
      if status.tunnelState != nil {
        resolveTunnelWait(wait, result: .status(status))
      }
    }
  }

  private func resolveTunnelWait(
    _ wait: TunnelWait,
    result: TunnelWaitResult
  ) {
    guard tunnelWait === wait else {
      return
    }
    tunnelWait = nil
    wait.continuation.resume(returning: result)
  }

  private func cancelTunnelWait() {
    guard let wait = tunnelWait else {
      return
    }
    resolveTunnelWait(wait, result: .superseded)
  }

  private func finishRunningRequestIfSatisfied(
    _ request: TunnelRequest,
    manager: NETunnelProviderManager
  ) -> Bool {
    let status = manager.connection.status
    recordObservedTunnelStatus(status, notifyExternal: false)
    guard status.tunnelState == .running else {
      return false
    }
    finishTunnelRequest(request, actualState: .running)
    return true
  }

  private func finishTunnelRequest(
    _ request: TunnelRequest,
    actualState: TunnelTarget?
  ) {
    guard isCurrent(request) else {
      return
    }
    do { try authority.finish(request.token) }
    catch TunnelIntentError.busy { return }
    catch {
      discard(request)
      return
    }
    tunnelRequest = nil
    intentMonitor?.cancel()
    intentMonitor = nil
    defer { publishConnectionState() }
    guard let actualState else {
      log(
        "\(request.description) completed actual=unknown generation=\(request.generation)"
      )
      return
    }
    reportTunnelState(actualState)
    publishedTunnelState = actualState
    log(
      "\(request.description) completed actual=\(actualState.description) generation=\(request.generation)"
    )

    Task { @MainActor [weak self] in
      guard let self,
        self.requestGeneration == request.generation,
        self.tunnelRequest == nil,
        self.publishedTunnelState == actualState,
        (try? self.authority.isLatest(request.token)) == true
      else {
        return
      }
      self.notifyExternalState(actualState)
    }
  }

  private func isCurrent(_ request: TunnelRequest) -> Bool {
    guard tunnelRequest === request, requestGeneration == request.generation else { return false }
    do {
      if !isSafeMode(), !Task.isCancelled, try authority.isCurrent(request.token) { return true }
    } catch TunnelIntentError.busy {
      return true
    } catch { log("intent authority unavailable") }
    discard(request)
    return false
  }

  private func discard(_ request: TunnelRequest) {
    guard tunnelRequest === request else { return }
    tunnelRequest = nil
    intentMonitor?.cancel()
    intentMonitor = nil
    do { try authority.finish(request.token) } catch { authority.cancel(request.token) }
    request.cancelOperation?()
    request.cancelOperation = nil
    cancelTunnelWait()
    publishConnectionState()
  }

  private func performOnDemandRulesReload() async -> Error? {
    var allowPreferenceRetry = true
    while true {
      do {
        guard
          let manager = try await managerStore.loadManager(
            createIfNeeded: false
          )
        else {
          return nil
        }
        let status = manager.connection.status
        managerStore.applyNetworkExtensionOptions(
          to: manager,
          enableOnDemand: status == .connecting || status.tunnelState == .running
        )
        try await awaitPreferenceResult { completion in
          manager.saveToPreferences(completionHandler: completion)
        }
        return nil
      } catch {
        log(
          "reloadOnDemandRules save failed: \(error.localizedDescription)"
        )
        guard allowPreferenceRetry,
          managerStore.invalidateCachedManager(forPreferenceError: error)
        else {
          return error
        }
        allowPreferenceRetry = false
        log("reloadOnDemandRules retry preferences")
      }
    }
  }

  private func performStatusRefresh(notifyExternal: Bool) async {
    let generation = requestGeneration
    do {
      let manager = try await managerStore.loadManager(createIfNeeded: false)
      let status = manager?.connection.status ?? .invalid
      recordObservedTunnelStatus(
        status,
        notifyExternal: false
      )
      if notifyExternal,
        generation == requestGeneration,
        tunnelRequest == nil,
        let state = status.tunnelState
      {
        publishedTunnelState = state
        notifyExternalState(state)
      }
    } catch {
      log("refresh status failed: \(error.localizedDescription)")
    }
  }

  private func recordObservedTunnelStatus(
    _ status: NEVPNStatus,
    notifyExternal: Bool
  ) {
    let previousStatus = observedTunnelStatus
    observedTunnelStatus = status
    defer { publishConnectionState() }
    if previousStatus != status {
      log(
        "status changed \(statusDescription(previousStatus ?? .invalid)) -> \(statusDescription(status)) target=\(tunnelRequest?.description ?? "none")"
      )
    }

    if tunnelWait != nil {
      consumeWaitStatus(status)
      return
    }
    guard tunnelRequest == nil,
      let stableState = status.tunnelState
    else {
      return
    }
    reportTunnelState(stableState)
    if notifyExternal {
      publishExternalState(stableState)
    } else if publishedTunnelState == nil {
      publishedTunnelState = stableState
    }
  }

  private func reportTunnelState(_ state: TunnelTarget) {
    guard reportedTunnelState != state else {
      return
    }
    reportedTunnelState = state
    onTunnelStateChanged(state)
  }

  private func publishExternalState(_ state: TunnelTarget) {
    guard publishedTunnelState != state else {
      return
    }
    publishedTunnelState = state
    notifyExternalState(state)
  }

  private func notifyExternalState(_ state: TunnelTarget) {
    switch state {
    case .running:
      log("sync running tunnel state")
      onExternalStart()
    case .stopped:
      log("sync stopped tunnel state")
      onExternalStop()
    }
  }

  private func awaitRequestOperation<Value>(
    _ request: TunnelRequest, _ operation: @escaping @MainActor () async throws -> Value
  ) async throws -> Value {
    guard isCurrent(request) else { throw TunnelIntentError.superseded }
    defer { request.cancelOperation = nil }
    return try await withCheckedThrowingContinuation { continuation in
      let pending = TunnelOperation(continuation)
      request.cancelOperation = { pending.cancel() }
      pending.task = Task {
        guard self.isCurrent(request) else { pending.cancel(); return }
        do { pending.finish(.success(try await operation())) }
        catch { pending.finish(.failure(error)) }
      }
    }
  }

  private func awaitPreferenceResult(
    _ action: (@escaping @Sendable (Error?) -> Void) -> Void
  ) async throws {
    try await withCheckedThrowingContinuation {
      (continuation: CheckedContinuation<Void, Error>) in
      action { error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume()
        }
      }
    }
  }

  private func stableFailureState(
    _ status: NEVPNStatus?
  ) -> TunnelTarget? {
    status?.tunnelState
  }

  private func statusDescription(_ status: NEVPNStatus) -> String {
    switch status {
    case .invalid:
      return "invalid"
    case .disconnected:
      return "disconnected"
    case .connecting:
      return "connecting"
    case .connected:
      return "connected"
    case .reasserting:
      return "reasserting"
    case .disconnecting:
      return "disconnecting"
    @unknown default:
      return "unknown"
    }
  }

  private func log(_ message: String) {
    logger.debug("\(message, privacy: .public)")
  }
}
