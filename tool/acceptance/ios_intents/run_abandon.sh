#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../../.." && pwd)"
out="$(mktemp -d "${TMPDIR:-/tmp}/c-ios-abandon.XXXXXX")"
trap 'rm -rf "$out"' EXIT
swiftc -swift-version 5 -emit-module -emit-library -module-name NetworkExtension "$root/tool/acceptance/ios_intents/NetworkExtension.swift" -emit-module-path "$out/NetworkExtension.swiftmodule" -o "$out/libNetworkExtension.dylib" -module-cache-path "$out/cache"
flags=(-swift-version 5 -I "$out" -L "$out" -lNetworkExtension -Xlinker -rpath -Xlinker "$out" -module-cache-path "$out/cache")
swiftc "${flags[@]}" -emit-module -emit-library -module-name Shared "$root/ios/Shared/NEHelper.swift" "$root/ios/Shared/TunnelIntentAuthority.swift" "$root/ios/Shared/TunnelIntentClient.swift" -emit-module-path "$out/Shared.swiftmodule" -o "$out/libShared.dylib"
swiftc "${flags[@]}" -lShared "$root/ios/Runner/Tunnel/TunnelCoordinator.swift" "$root/ios/Runner/Tunnel/TunnelTypes.swift" "$root/tool/acceptance/ios_intents/Abandon.swift" -o "$out/abandon-test"
for mode in never unadmitted superseded owned finished busy prior same-runner quick widget busy-superseded cancel; do
  "$out/abandon-test" "$mode" "$out/$mode"
done
