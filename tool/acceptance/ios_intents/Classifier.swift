import Foundation

@main struct ClassifierTest {
  static func main() {
    let valid = #"{"error":{"code":"unauthenticated"}}"#
    let invalid = ["", "<html>unauthorized</html>", #"{"error":{"code":"edge_blocked"}}"#, #"{\"error\":{\"code\":\"unauthenticated\"}}"#, #"{"error":{"code":"unauthenticated"}"#]
    precondition(ClientBundleRenewalOwner.isAuthoritativeUnauthorized(Data(valid.utf8)))
    for body in invalid { precondition(!ClientBundleRenewalOwner.isAuthoritativeUnauthorized(Data(body.utf8))) }
    var bounded = Data(valid.utf8)
    bounded.append(Data(repeating: 32, count: 8192 - bounded.count))
    precondition(ClientBundleRenewalOwner.isAuthoritativeUnauthorized(bounded))
    bounded.append(32)
    precondition((try? JSONSerialization.jsonObject(with: bounded)) != nil)
    precondition(!ClientBundleRenewalOwner.isAuthoritativeUnauthorized(bounded))
    print("PASS: production classifier accepts valid JSON and rejects malformed JSON, HTML, other codes and oversized bodies")
  }
}
