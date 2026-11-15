import Foundation

@main struct ClassifierTest {
  static func main() {
    let valid = #"{"error":{"code":"unauthenticated"}}"#
    let invalid = ["", "<html>unauthorized</html>", #"{"error":{"code":"edge_blocked"}}"#, #"{\"error\":{\"code\":\"unauthenticated\"}}"#, #"{"error":{"code":"unauthenticated"}"#]
    precondition(ClientBundleRenewalOwner.isAuthoritativeUnauthorized(Data(valid.utf8)))
    for body in invalid { precondition(!ClientBundleRenewalOwner.isAuthoritativeUnauthorized(Data(body.utf8))) }
    precondition(!ClientBundleRenewalOwner.isAuthoritativeUnauthorized(Data(repeating: 65, count: 8193)))
    print("PASS: production classifier accepts valid JSON and rejects malformed JSON, HTML, other codes and oversized bodies")
  }
}
