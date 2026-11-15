#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../../.." && pwd)"
out="$(mktemp -d "${TMPDIR:-/tmp}/c-ios-authority.XXXXXX")"
pids=()
cleanup() {
  for pid in "${pids[@]:-}"; do
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then kill "$pid"; wait "$pid" || true; fi
  done
  rm -rf "$out"
}
trap cleanup EXIT
wait_file() {
  for ((attempt=0; attempt<500; attempt++)); do
    if [[ -e "$1" ]]; then return; fi
    sleep 0.01
  done
  echo "FAIL: process barrier timed out" >&2
  exit 1
}
swiftc -swift-version 5 -module-cache-path "$out/cache" "$root/ios/Shared/TunnelIntentAuthority.swift" "$root/tool/acceptance/ios_intents/AuthorityProcess.swift" -o "$out/authority-test"
"$out/authority-test" unit "$out"
mkdir "$out/invalidate" "$out/compete"
"$out/authority-test" pending-start "$out/invalidate" &
pids+=("$!")
wait_file "$out/invalidate/ready"
"$out/authority-test" stop "$out/invalidate"
touch "$out/invalidate/release"
wait "${pids[0]}"
[[ ! -e "$out/invalidate/late-start" && -e "$out/invalidate/stopped" ]]
pids=()
"$out/authority-test" hold-effect "$out/compete" &
pids+=("$!")
wait_file "$out/compete/locked"
"$out/authority-test" expect-busy "$out/compete"
touch "$out/compete/unlock"
wait "${pids[0]}"
pids=()
"$out/authority-test" stop "$out/compete"
[[ -e "$out/compete/started" && -e "$out/compete/stopped" ]]
echo 'PASS: independent processes exited; stop follows completed start critical section'
