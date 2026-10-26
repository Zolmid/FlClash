import Foundation
import Shared

@MainActor
final class ClientBundleSessionBridge {
  private let tunnel: TunnelController
  private let configuration = ClientBundleRenewalConfiguration.configured()
  private var publisher: ClientBundleSessionPublisher?
  private var counter: UInt64 = 0

  init(tunnel: TunnelController) { self.tunnel = tunnel }

  func configure(_ arguments: Any?) async throws -> ClientBundleRenewalStatus {
    guard let configuration else { return unavailable }
    guard let object = arguments as? [String: Any],
      let data = try? JSONSerialization.data(withJSONObject: object),
      let request = try? JSONDecoder().decode(ConfigurationRequest.self, from: data),
      request.accountGeneration > 0, request.distribution == configuration.distribution
    else { throw ClientBundleEpochError.unavailable }
    let publisher = try makePublisher(configuration)
    let binding = try await publisher.configure(accountID: request.accountId, authorization: request.authorization)
    if await tunnel.getRunTime() > 0 {
      return try await control("restartClientBundleRenewal", epoch: binding.session.rawValue)
    }
    return .init(supported: true, sessionEpoch: binding.session.rawValue, ownerId: binding.owner.rawValue,
      state: "waiting_for_tunnel")
  }

  func logout(_ arguments: Any?) async throws -> Bool {
    guard let configuration else { throw ClientBundleEpochError.unavailable }
    guard let object = arguments as? [String: Any],
      let data = try? JSONSerialization.data(withJSONObject: object),
      let request = try? JSONDecoder().decode(Epoch.self, from: data)
    else { throw ClientBundleEpochError.unavailable }
    try await makePublisher(configuration).logout(sessionEpoch: request.sessionEpoch)
    return true
  }

  func status() async throws -> ClientBundleRenewalStatus {
    guard let configuration else { return unavailable }
    if await tunnel.getRunTime() > 0 { return try await control("clientBundleRenewalStatus", epoch: nil) }
    let authority = try configuration.makeAuthority()
    let current = try await authority.currentBinding()
    let retiring = try await authority.retiringBinding()
    return .init(supported: true, sessionEpoch: current?.session.rawValue, ownerId: current?.owner.rawValue,
      state: retiring == nil ? "waiting_for_tunnel" : "cleanup_pending")
  }

  private var unavailable: ClientBundleRenewalStatus {
    .init(supported: false, state: "signing_capability_required")
  }

  private func makePublisher(_ configuration: ClientBundleRenewalConfiguration) throws -> ClientBundleSessionPublisher {
    if let publisher { return publisher }
    let value = ClientBundleSessionPublisher(authority: try configuration.makeAuthority(),
      credentials: try configuration.makeCredentials()) { [weak self] binding in
      guard let self else { throw ClientBundleCoreError.unavailable }
      try await self.stopOwner(epoch: binding.session.rawValue)
    }
    publisher = value
    return value
  }

  private func stopOwner(epoch: UInt64) async throws {
    guard await tunnel.getRunTime() > 0 else { return }
    _ = try await control("logoutClientBundleRenewal", epoch: epoch)
  }

  private func control(_ method: String, epoch: UInt64?) async throws -> ClientBundleRenewalStatus {
    counter += 1
    let id = "renewal-control-\(counter)"
    let message = try JSONEncoder().encode(Control(id: id, method: method,
      arguments: epoch.map { Epoch(sessionEpoch: $0) }))
    let text = try await tunnel.sendProviderMessage(message)
    guard let body = text.data(using: .utf8),
      let response = try? JSONDecoder().decode(Response.self, from: body),
      response.id == id, response.error == nil, let result = response.result
    else { throw ClientBundleCoreError.unavailable }
    return result
  }

  private struct ConfigurationRequest: Decodable {
    let accountId: String
    let authorization: String
    let accountGeneration: Int
    let distribution: String
  }
  private struct Epoch: Codable { let sessionEpoch: UInt64 }
  private struct Control: Encodable { let id: String; let method: String; let arguments: Epoch? }
  private struct Response: Decodable {
    struct Failure: Decodable { let code: String }
    let id: String?
    let result: ClientBundleRenewalStatus?
    let error: Failure?
  }
}
