import Foundation

@main enum ClientBundleHTTPTransportCheck {
  static func main() throws {
    let transport = try ClientBundleHTTPTransport(
      origin: URL(string: "https://link.zolmid.com")!, coreVersion: "fixture",
      platform: "ios", distribution: "direct")
    let binding = ClientBundleRenewalState.Binding(session: .init(1), owner: .init(1))
    let authorization = ClientBundleAuthorization(
      accountID: "fixture", binding: binding, value: "Bearer SYNTHETIC_ONLY")
    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    for path in ["bundle", "subscription/state"] {
      let request = try transport.makeRequest(
        URL(string: "https://link.zolmid.com/api/v1/zolnit/client/\(path)")!,
        authorization: authorization, headers: [:])
      precondition(request.value(forHTTPHeaderField: "User-Agent") == "ZolNit/v\(version) clash-verge Platform/ios")
    }
  }
}
