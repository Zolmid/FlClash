#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../../.." && pwd)"
out="$(mktemp -d "${TMPDIR:-/tmp}/c-ios-cross.XXXXXX")"
trap 'rm -rf "$out"' EXIT
mkdir -p "$out/Race.app/Contents/MacOS" "$out/modules" "$out/source"
bundle="org.example.IntentFixture.$(uuidgen)"
cat > "$out/Race.app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict><key>CFBundleIdentifier</key><string>$bundle</string><key>CFBundleExecutable</key><string>Race</string></dict></plist>
PLIST
swiftc -swift-version 5 -emit-module -emit-library -module-name NetworkExtension "$root/tool/acceptance/ios_intents/NetworkExtension.swift" -emit-module-path "$out/modules/NetworkExtension.swiftmodule" -o "$out/modules/libNetworkExtension.dylib" -module-cache-path "$out/modules/cache"
flags=(-swift-version 5 -I "$out/modules" -L "$out/modules" -lNetworkExtension -Xlinker -rpath -Xlinker "$out/modules" -module-cache-path "$out/modules/cache")
if [[ -n "${IOS_INTENTS_BASELINE:-}" ]]; then
  for file in NEHelper TunnelCoordinator TunnelTypes; do
    if [[ "$file" = NEHelper ]]; then path="ios/Shared/$file.swift"; else path="ios/Runner/Tunnel/$file.swift"; fi
    git -C "$root" show "$IOS_INTENTS_BASELINE:$path" > "$out/source/$file.swift"
  done
  sources=("$out/source/NEHelper.swift" "$out/source/TunnelCoordinator.swift" "$out/source/TunnelTypes.swift")
  flags+=(-DLEGACY_INTENTS)
else
  swiftc "${flags[@]}" -emit-module -emit-library -module-name Shared "$root/ios/Shared/NEHelper.swift" "$root/ios/Shared/TunnelIntentAuthority.swift" "$root/ios/Shared/TunnelIntentClient.swift" -emit-module-path "$out/modules/Shared.swiftmodule" -o "$out/modules/libShared.dylib"
  flags+=(-lShared)
  sources=("$root/ios/Runner/Tunnel/TunnelCoordinator.swift" "$root/ios/Runner/Tunnel/TunnelTypes.swift")
fi
swiftc "${flags[@]}" "${sources[@]}" "$root/tool/acceptance/ios_intents/CrossEntry.swift" -o "$out/Race.app/Contents/MacOS/Race"
"$out/Race.app/Contents/MacOS/Race" "$out/authority"
if [[ -z "${IOS_INTENTS_BASELINE:-}" ]]; then
  swiftc -parse-as-library "${flags[@]}" "$root/tool/acceptance/ios_intents/RedRace.swift" -o "$out/client-tests"
  "$out/client-tests" "$out/client-authority"
fi
