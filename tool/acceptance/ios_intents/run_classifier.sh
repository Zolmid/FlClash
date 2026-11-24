#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../../.." && pwd)"
out="$(mktemp -d "${TMPDIR:-/tmp}/c-ios-classifier.XXXXXX")"
trap 'rm -rf "$out"' EXIT
mkdir -p "$out"
swiftc -swift-version 5 -module-cache-path "$out/cache" "$root/ios/Shared/ClientBundleRenewalState.swift" "$root/ios/Shared/ClientBundleRenewalConfiguration.swift" "$root/ios/Shared/ClientBundleEpochStore.swift" "$root/ios/Shared/ClientBundleKeychainStore.swift" "$root/ios/Shared/ClientBundleRenewalOwner.swift" "$root/tool/acceptance/ios_intents/Classifier.swift" -o "$out/classifier"
"$out/classifier"
xcrun swiftc -swift-version 5 -warnings-as-errors -module-cache-path "$out/cache" -parse-as-library \
  "$root"/ios/Shared/ClientBundle*.swift \
  "$root/test/core/ios/client_bundle_http_transport.swift" -o "$out/http-transport"
"$out/http-transport"

xcrun swiftc -swift-version 5 -warnings-as-errors -module-cache-path "$out/cache" -parse-as-library \
  "$root/ios/NECore/NETransportPathMonitor.swift" \
  "$root/test/core/ios/native_transport_path.swift" -o "$out/native-transport-path"
"$out/native-transport-path"
