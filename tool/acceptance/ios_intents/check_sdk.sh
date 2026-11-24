#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../../.." && pwd)"
out="$(mktemp -d "${TMPDIR:-/tmp}/c-ios-sdk.XXXXXX")"
trap 'rm -rf "$out"' EXIT
sdk="$(xcrun --sdk iphoneos --show-sdk-path)"
xcodebuild -version
xcrun swiftc --version
xcrun --sdk iphoneos --show-sdk-version
flags=(-swift-version 5 -parse-as-library -target arm64-apple-ios15.0 -sdk "$sdk" -module-cache-path "$out/cache")
xcrun swiftc "${flags[@]}" -emit-module -emit-library -static -module-name Shared "$root"/ios/Shared/*.swift -emit-module-path "$out/Shared.swiftmodule" -o "$out/libShared.a"
echo 'PASS: all production Shared sources compile to an unsigned iOS static library'
xcrun swiftc "${flags[@]}" -I "$out" -typecheck "$root"/ios/Runner/Tunnel/*.swift "$root/ios/Runner/Storage/SharedStateStore.swift"
echo 'PASS: production Runner Tunnel sources and SharedStateStore typecheck against the real iOS SDK'
xcrun swiftc -frontend -parse -target arm64-apple-ios15.0 -sdk "$sdk" "$root/ios/Runner/ServiceChannel.swift" "$root/ios/Runner/SceneDelegate.swift"
echo 'PASS: Flutter-facing adapters parse; full Flutter host typecheck remains candidate CI validation'
xcrun swiftc "${flags[@]}" -I "$out" -import-objc-header "$root/ios/NECore/NECore-Bridging-Header.h" -typecheck "$root"/ios/NECore/*.swift
echo 'PASS: all production Network Extension Swift sources typecheck with the production bridge and real iOS SDK'
