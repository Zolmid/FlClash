import Foundation
import NetworkExtension

@main struct Race {
  @MainActor static func manager() -> NETunnelProviderManager {
    let manager = NETunnelProviderManager()
    let config = NETunnelProviderProtocol()
    config.providerBundleIdentifier = NEHelper.providerBundleIdentifier
    manager.protocolConfiguration = config
    NETunnelProviderManager.manager = manager
    NETunnelProviderManager.pauseReload = false
    NETunnelProviderManager.pauseLoad = false
    NETunnelProviderManager.loadCount = 0
    return manager
  }
  @MainActor static func until(_ condition: () -> Bool) async {
    for _ in 0..<100_000 { if condition() { return }; await Task.yield() }
    fatalError("fixture timed out")
  }
  @MainActor static func resumeSave(_ error: Error? = nil) {
    let continuation = NETunnelProviderManager.saveContinuation!
    NETunnelProviderManager.saveContinuation = nil
    if let error { continuation.resume(throwing: error) } else { continuation.resume() }
  }
  @MainActor static func main() async throws {
    let defaults = UserDefaults(suiteName: NEHelper.appGroupIdentifier)!
    defaults.removePersistentDomain(forName: NEHelper.appGroupIdentifier)
    let first = manager()
    let old = Task { try await NEHelper.start() }
    await until { NETunnelProviderManager.saveContinuation != nil }
    _ = try await NEHelper.stop()
    resumeSave()
    _ = try await old.value
    guard first.connection.starts == 0 else {
      print("FAIL: superseded start launched after stop"); exit(1)
    }
    print("PASS: superseded start did not launch")

    let reload = manager()
    NETunnelProviderManager.pauseReload = true
    let reloading = Task { try await NEHelper.start() }
    await until { NETunnelProviderManager.saveContinuation != nil }
    resumeSave()
    await until { NETunnelProviderManager.reloadContinuation != nil }
    _ = try await NEHelper.stop()
    NETunnelProviderManager.reloadContinuation!.resume()
    NETunnelProviderManager.reloadContinuation = nil
    _ = try await reloading.value
    precondition(reload.connection.starts == 0)

    let toggled = manager()
    let starting = Task { try await NEHelper.start() }
    await until { NETunnelProviderManager.saveContinuation != nil }
    try await NEHelper.toggle()
    resumeSave()
    _ = try await starting.value
    precondition(toggled.connection.starts == 0)

    let canceled = manager()
    let canceledTask = Task { try await NEHelper.start() }
    await until { NETunnelProviderManager.saveContinuation != nil }
    canceledTask.cancel()
    resumeSave()
    _ = try await canceledTask.value
    precondition(canceled.connection.starts == 0)

    let retry = manager()
    let retryTask = Task { try await NEHelper.start() }
    await until { NETunnelProviderManager.saveContinuation != nil }
    NETunnelProviderManager.pauseLoad = true
    resumeSave(NSError(domain: NEVPNErrorDomain, code: NEVPNError.Code.configurationStale.rawValue))
    await until { NETunnelProviderManager.loadContinuation != nil }
    NETunnelProviderManager.pauseLoad = false
    let waitingLoad = NETunnelProviderManager.loadContinuation!
    NETunnelProviderManager.loadContinuation = nil
    _ = try await NEHelper.stop()
    waitingLoad.resume()
    _ = try await retryTask.value
    precondition(retry.connection.starts == 0)

    let failure = manager()
    let failingTask = Task { try await NEHelper.start() }
    await until { NETunnelProviderManager.saveContinuation != nil }
    resumeSave(NSError(domain: NEVPNErrorDomain, code: NEVPNError.Code.configurationDisabled.rawValue))
    do { _ = try await failingTask.value; fatalError("expected error") } catch {}
    precondition(failure.connection.starts == 0)

    let repeated = manager()
    let older = Task { try await NEHelper.start() }
    await until { NETunnelProviderManager.saveContinuation != nil }
    let oldSave = NETunnelProviderManager.saveContinuation!
    NETunnelProviderManager.saveContinuation = nil
    let newer = Task { try await NEHelper.start() }
    await until { NETunnelProviderManager.saveContinuation != nil }
    oldSave.resume()
    _ = try await older.value
    precondition(repeated.connection.starts == 0)
    resumeSave()
    _ = try await newer.value
    precondition(repeated.connection.starts == 1)
    _ = try await NEHelper.start()
    precondition(repeated.connection.starts == 1)
    _ = try await NEHelper.stop()
    _ = try await NEHelper.stop()
    precondition(repeated.connection.stops == 1)

    let recovered = manager()
    let recovering = Task { try await NEHelper.start() }
    await until { NETunnelProviderManager.saveContinuation != nil }
    resumeSave(NSError(domain: NEVPNErrorDomain, code: NEVPNError.Code.configurationStale.rawValue))
    await until { NETunnelProviderManager.saveContinuation != nil }
    resumeSave()
    _ = try await recovering.value
    precondition(recovered.connection.starts == 1 && NETunnelProviderManager.loadCount == 2)

    let safe = manager()
    defaults.set(true, forKey: "safeMode")
    let safeStart = try await NEHelper.start()
    precondition(!safeStart && safe.connection.starts == 0)
    defaults.removePersistentDomain(forName: NEHelper.appGroupIdentifier)
    print("PASS: stop during reload/retry, toggle, cancellation, failure, repeat requests, retry recovery and safe mode")
  }
}
