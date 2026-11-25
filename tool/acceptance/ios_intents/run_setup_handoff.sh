#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../../.." && pwd)"
out="$(mktemp -d "${TMPDIR:-/tmp}/zn-ios-handoff.XXXXXX")"
trap 'rm -rf "$out"' EXIT
mkdir -p "$out/Handoff.app/Contents/MacOS" "$out/modules"
cat > "$out/Handoff.app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict><key>CFBundleIdentifier</key><string>org.example.Handoff.$(uuidgen)</string><key>CFBundleExecutable</key><string>Handoff</string></dict></plist>
PLIST
swiftc -swift-version 5 -module-cache-path "$out/cache" -emit-module -emit-library -module-name Shared "$root"/ios/Shared/ClientBundle*.swift -emit-module-path "$out/modules/Shared.swiftmodule" -o "$out/modules/libShared.dylib"
swiftc -swift-version 5 -module-cache-path "$out/cache" -I "$out/modules" -L "$out/modules" -lShared -Xlinker -rpath -Xlinker "$out/modules" "$root/ios/Runner/Storage/SharedStateStore.swift" "$root/ios/NECore/PacketTunnelSharedStateStore.swift" "$root/test/core/ios/setup_handoff.swift" -o "$out/Handoff.app/Contents/MacOS/Handoff"
python3 - "$root" "$out/overlay.json" <<'PYOVERLAY'
import json, sys
from pathlib import Path
root = Path(sys.argv[1])
source = (root / 'core/lib.go').read_text()
start = source.index('func QuickSetup(')
end = source.index('\n}\n', start) + 3
host = Path(sys.argv[2]).with_name('quick_setup_host.go')
host.write_text('package core\nimport ("encoding/json"; "fmt")\n' + source[start:end])
Path(sys.argv[2]).write_text(json.dumps({'Replace': {
    str(root / 'core/ios_setup_handoff_fixture_test.go'): str(root / 'test/core/ios/setup_handoff_test.go'),
    str(root / 'core/ios_quick_setup_host.go'): str(host),
}}))
PYOVERLAY
(cd "$root/core" && ZN_HANDOFF_WIRE="$1" ZN_HANDOFF_NATIVE_BINARY="$out/Handoff.app/Contents/MacOS/Handoff" CGO_ENABLED=0 go test -overlay "$out/overlay.json" -run '^TestIOSSerializedHandoffQuickSetup$' -count=1 -v .)
