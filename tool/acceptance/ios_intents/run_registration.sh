#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../../.." && pwd)"
out="$(mktemp -d "${TMPDIR:-/tmp}/c-ios-registration.XXXXXX")"
trap 'chmod -R u+rwX "$out" 2>/dev/null || true; rm -rf "$out"' EXIT
mkdir "$out/source"
for path in ios/Shared/NEHelper.swift ios/Shared/TunnelIntentAuthority.swift ios/Shared/TunnelIntentClient.swift ios/Runner/Tunnel/TunnelCoordinator.swift ios/Runner/Tunnel/TunnelTypes.swift ios/Runner/ServiceChannel.swift; do
  if [[ -n "${IOS_REGISTRATION_BASELINE:-}" ]]; then git -C "$root" show "$IOS_REGISTRATION_BASELINE:$path" > "$out/source/$(basename "$path")"
  else cp "$root/$path" "$out/source/$(basename "$path")"; fi
done
python3 - "$out" <<'PY'
from pathlib import Path
import sys
out = Path(sys.argv[1])
s = (out / 'source/ServiceChannel.swift').read_text()
actions = s[s.index('enum QuickAction:'):s.index('@MainActor\nfinal class ServiceChannel')]
methods = s[s.index('  @discardableResult\n  static func request('):s.index('  private init(messenger:')]
(out / 'QueueAdapter.swift').write_text('''import Foundation
import Shared
''' + actions + '''@MainActor final class ServiceChannel {
  static var instance: ServiceChannel?
  static let pendingQuickAction = PendingTunnelIntent()
  static let quickActionAuthority = TunnelIntentAuthority(directory: URL(fileURLWithPath: CommandLine.arguments[2]))
  let sharedStateStore = Store()
  let tunnelController: Controller
  var isInitialized = false
  var quickActionDrain: Task<Void, Never>?
  init(controller: Controller) { tunnelController = controller }
  func log(_ message: String) {}
''' + methods + '''  func initialize() { isInitialized = true; drainQuickActions() }
}
''')
PY
swiftc -swift-version 5 -emit-module -emit-library -module-name NetworkExtension "$root/tool/acceptance/ios_intents/NetworkExtension.swift" -emit-module-path "$out/NetworkExtension.swiftmodule" -o "$out/libNetworkExtension.dylib" -module-cache-path "$out/cache"
flags=(-swift-version 5 -I "$out" -L "$out" -lNetworkExtension -Xlinker -rpath -Xlinker "$out" -module-cache-path "$out/cache")
swiftc "${flags[@]}" -emit-module -emit-library -module-name Shared "$out/source/NEHelper.swift" "$out/source/TunnelIntentAuthority.swift" "$out/source/TunnelIntentClient.swift" -emit-module-path "$out/Shared.swiftmodule" -o "$out/libShared.dylib"
swiftc "${flags[@]}" -lShared "$out/source/TunnelCoordinator.swift" "$out/source/TunnelTypes.swift" "$out/QueueAdapter.swift" "$root/tool/acceptance/ios_intents/Registration.swift" -o "$out/registration-test"
for lane in ${IOS_REGISTRATION_LANES:-runner shared queue}; do
  for mode in ${IOS_REGISTRATION_MODES:-short later cross external cancel timeout io}; do
    "$out/registration-test" "$lane-$mode" "$out/$lane-$mode"
  done
done
