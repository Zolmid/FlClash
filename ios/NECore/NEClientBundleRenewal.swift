import Foundation
import Shared

actor NEClientBundleRenewal {
  private let configuration = ClientBundleRenewalConfiguration.configured()
  private var owner: ClientBundleRenewalOwner?
  private var binding: ClientBundleRenewalState.Binding?
  private var monitor: Task<Void, Never>?
  private var requested = false
  private var failure: String?

  func start() async {
    guard configuration != nil else { return }
    requested = true
    await ensureOwner()
    if monitor == nil {
      monitor = Task { [weak self] in
        while !Task.isCancelled {
          do { try await Task.sleep(nanoseconds: 15_000_000_000) }
          catch { return }
          await self?.ensureOwner()
        }
      }
    }
  }

  func restart(sessionEpoch: UInt64) async throws -> ClientBundleRenewalStatus {
    try await stop(sessionEpoch: nil, invalidatingSession: false)
    guard let configuration,
      let current = try await configuration.makeAuthority().currentBinding(),
      current.session.rawValue == sessionEpoch else { return await status() }
    await start()
    return await status()
  }

  func stop(sessionEpoch: UInt64?, invalidatingSession: Bool) async throws {
    if let sessionEpoch, let binding, binding.session.rawValue != sessionEpoch { return }
    requested = false
    monitor?.cancel()
    monitor = nil
    if let owner {
      if invalidatingSession { await owner.logout() } else { await owner.stop() }
      if await owner.phase() == .terminating { await owner.retryCleanup() }
      guard await owner.phase() == .inactive else { throw ClientBundleCoreError.unavailable }
    }
    owner = nil
    binding = nil
  }

  func status() async -> ClientBundleRenewalStatus {
    if let owner {
      let value = await owner.status()
      return .init(supported: value.supported, sessionEpoch: binding?.session.rawValue,
        ownerId: binding?.owner.rawValue, ownsRenewal: value.ownsRenewal, ready: value.ready,
        state: value.state, expiresAt: value.expiresAt)
    }
    return .init(supported: configuration != nil,
      state: failure ?? (configuration == nil ? "signing_capability_required" : "stopped"))
  }

  func handle(_ message: Data) async -> Data? {
    guard let call = try? JSONDecoder().decode(Control.self, from: message),
      ["clientBundleRenewalStatus", "restartClientBundleRenewal", "logoutClientBundleRenewal"].contains(call.method)
    else { return nil }
    do {
      switch call.method {
      case "restartClientBundleRenewal":
        guard let epoch = call.arguments?.sessionEpoch else { throw ClientBundleEpochError.staleSession }
        let value = try await restart(sessionEpoch: epoch)
        return try JSONEncoder().encode(Receipt(id: call.id, result: value, error: nil))
      case "logoutClientBundleRenewal":
        guard let epoch = call.arguments?.sessionEpoch else { throw ClientBundleEpochError.staleSession }
        try await stop(sessionEpoch: epoch, invalidatingSession: true)
      default:
        break
      }
      return try JSONEncoder().encode(Receipt(id: call.id, result: await status(), error: nil))
    } catch {
      return try? JSONEncoder().encode(Receipt(id: call.id, result: nil,
        error: .init(code: "native_renewal_incomplete", message: "Native renewal operation did not complete")))
    }
  }

  private func ensureOwner() async {
    guard requested, let configuration else { return }
    do {
      if let owner, await owner.phase() != .inactive {
        if await owner.phase() == .terminating { await owner.retryCleanup() }
        return
      }
      let authority = try configuration.makeAuthority()
      guard let current = try await authority.currentBinding() else { return }
      let credentials = try configuration.makeCredentials()
      let next = try await authority.claimOwner(sessionEpoch: current.session.rawValue)
      let authorization = try await credentials.read(for: next)
      let version = try await coreVersion()
      guard requested, try await authority.isCurrent(next) else { return }
      let core = ClientBundleCoreAdapter(binding: next, accountID: authorization.accountID, call: Self.invoke)
      let transport = try ClientBundleHTTPTransport(origin: configuration.origin,
        coreVersion: version, platform: "ios", distribution: configuration.distribution)
      let renewal = ClientBundleRenewalOwner(credentials: credentials, transport: transport, control: authority, core: core)
      owner = renewal
      binding = next
      await renewal.start(next)
      failure = nil
    } catch {
      failure = "native_renewal_unavailable"
    }
  }

  private func coreVersion() async throws -> String {
    let request = Data(#"{"id":"renewal-version","method":"getCoreVersion","arguments":null}"#.utf8)
    let body = try await Self.invoke(request)
    guard let value = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
      value["error"] == nil || value["error"] is NSNull,
      let version = value["result"] as? String, !version.isEmpty else { throw ClientBundleCoreError.unavailable }
    return version
  }

  private static func invoke(_ data: Data) async throws -> Data {
    try await withCheckedThrowingContinuation { continuation in
      NECoreBridge.invokeMethod(data) { response in
        if let response { continuation.resume(returning: response) }
        else { continuation.resume(throwing: ClientBundleCoreError.unavailable) }
      }
    }
  }

  private struct Control: Decodable {
    struct Arguments: Decodable { let sessionEpoch: UInt64? }
    let id: String?
    let method: String
    let arguments: Arguments?
  }
  private struct Receipt: Encodable {
    struct Failure: Encodable { let code: String; let message: String }
    let id: String?
    let result: ClientBundleRenewalStatus?
    let error: Failure?
  }
}
