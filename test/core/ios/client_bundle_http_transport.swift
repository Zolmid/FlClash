import Foundation

@main enum ClientBundleHTTPTransportCheck {
  static func main() async throws {
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
    let owned = try ClientBundleHTTPTransport(origin: URL(string: "https://link.zolmid.com")!,
      coreVersion: "fixture", platform: "ios", distribution: "direct", coreCall: { data in
        let value = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        precondition(value["method"] as? String == "firstPartyHTTP")
        let arguments = value["arguments"] as! [String: Any]
        precondition(arguments["owned-dns-only"] as? Bool == true)
        precondition((arguments["headers"] as! [String: String])["Authorization"] == "Bearer SYNTHETIC_ONLY")
        return try JSONSerialization.data(withJSONObject: ["id": value["id"]!,
          "result": ["status": 200, "body": Data("fixture".utf8).base64EncodedString(), "headers": [:]]])
      })
    let response = try await owned.fetch(authorization: authorization)
    precondition(response.status == 200 && response.body == Data("fixture".utf8))
    let failing = try ClientBundleHTTPTransport(origin: URL(string: "https://link.zolmid.com")!,
      coreVersion: "fixture", platform: "ios", distribution: "direct", coreCall: { data in
        let value = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        return try JSONSerialization.data(withJSONObject: ["id": value["id"]!, "error": ["code": "network"]])
      })
    do { _ = try await failing.fetch(authorization: authorization); preconditionFailure("strict request fell back") }
    catch ClientBundleTransportError.unavailable {}

  }
}
