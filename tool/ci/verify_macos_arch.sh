#!/usr/bin/env bash
# Verify the macOS .app binary matches the expected architecture.
# Usage: verify_macos_arch.sh <build-config> <expected-arch>
# expected-arch: amd64 or arm64
set -euo pipefail

config="$1"   # Debug or Release
arch="$2"     # amd64 or arm64

case "$arch" in
  amd64|x64|x86_64) verify_arch=x86_64 ;;
  arm64)            verify_arch=arm64   ;;
  *) echo "::error::Unknown arch: $arch"; exit 1 ;;
esac

app_dir="build/macos/Build/Products/$config"
app=$(find "$app_dir" -maxdepth 1 -name '*.app' -print -quit)
if [[ -z "$app" ]]; then
  echo "::error::No .app found in $app_dir"
  exit 1
fi

exec_name=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$app/Contents/Info.plist")
binary="$app/Contents/MacOS/$exec_name"

if ! lipo -verify_arch "$verify_arch" "$binary"; then
  actual=$(lipo -archs "$binary")
  echo "::error::Expected $verify_arch but binary has: $actual"
  exit 1
fi

echo "Architecture verified: $verify_arch ($(lipo -archs "$binary"))"
