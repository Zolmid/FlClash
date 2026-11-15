#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../../.." && pwd)"
out="${TMPDIR:-/tmp}/c-ios-intents-a1-race-$$"
trap 'rm -rf "$out"' EXIT
mkdir -p "$out/Race.app/Contents/MacOS" "$out/modules"
cat > "$out/Race.app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>CFBundleIdentifier</key><string>org.example.IntentRaceFixture</string><key>CFBundleExecutable</key><string>Race</string></dict></plist>
PLIST
swiftc -swift-version 5 -emit-module -emit-library -module-name NetworkExtension "$root/tool/acceptance/ios_intents/NetworkExtension.swift" -emit-module-path "$out/modules/NetworkExtension.swiftmodule" -o "$out/modules/libNetworkExtension.dylib" -module-cache-path "$out/modules/cache"
swiftc -swift-version 5 -I "$out/modules" -L "$out/modules" -lNetworkExtension -Xlinker -rpath -Xlinker "$out/modules" "$root/ios/Shared/NEHelper.swift" "$root/tool/acceptance/ios_intents/RedRace.swift" -o "$out/Race.app/Contents/MacOS/Race" -module-cache-path "$out/modules/cache"
"$out/Race.app/Contents/MacOS/Race"
