#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../../.." && pwd)"
out="$(mktemp -d "${TMPDIR:-/tmp}/c-ios-completion.XXXXXX")"
trap 'rm -rf "$out"' EXIT
swiftc -swift-version 5 -emit-module -emit-library -module-name NetworkExtension "$root/tool/acceptance/ios_intents/NetworkExtension.swift" -emit-module-path "$out/NetworkExtension.swiftmodule" -o "$out/libNetworkExtension.dylib" -module-cache-path "$out/cache"
flags=(-swift-version 5 -I "$out" -L "$out" -lNetworkExtension -Xlinker -rpath -Xlinker "$out" -module-cache-path "$out/cache")
swiftc "${flags[@]}" -emit-module -emit-library -module-name Shared "$root/ios/Shared/NEHelper.swift" "$root/ios/Shared/TunnelIntentAuthority.swift" "$root/ios/Shared/TunnelIntentClient.swift" -emit-module-path "$out/Shared.swiftmodule" -o "$out/libShared.dylib"
swiftc -parse-as-library "${flags[@]}" -lShared "$root/tool/acceptance/ios_intents/Completion.swift" -o "$out/completion-test"
"$out/completion-test" "$out/data"
