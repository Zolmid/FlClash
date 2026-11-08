#!/usr/bin/env bash
set -euo pipefail
bundle=$(realpath "$1")
dest=$(realpath -m "$2")
stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT
root="$stage/ZolNit.AppDir"
mkdir -p "$root/usr/lib/ZolNit" "$(dirname "$dest")"
cp -a "$bundle"/. "$root/usr/lib/ZolNit/"
test -x "$root/usr/lib/ZolNit/ZolNit"
install -Dm644 linux/packaging/appimage/runtime.LICENSE "$root/usr/share/licenses/appimage-runtime/LICENSE"
cp assets/images/icon.png "$root/zolnit.png"
ln -s zolnit.png "$root/.DirIcon"
cat > "$root/AppRun" <<'APP'
#!/bin/sh
set -eu
base=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
exec "$base/usr/lib/ZolNit/ZolNit" "$@"
APP
chmod 755 "$root/AppRun"
cat > "$root/zolnit.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=ZolNit
GenericName=VPN Client
GenericName[zh_CN]=VPN 客户端
Comment=Connect to a location included in your ZolNit plan.
Comment[zh_CN]=连接套餐内的线路。
Exec=AppRun %U
Icon=zolnit
Categories=Network;
MimeType=x-scheme-handler/zolnit;
StartupWMClass=com.zolmid.zolnit
DESKTOP
runtime="$stage/runtime"
if [[ -n "${ZOLNIT_APPIMAGE_RUNTIME:-}" ]]; then
  cp "$ZOLNIT_APPIMAGE_RUNTIME" "$runtime"
else
  python3 "$(dirname -- "$0")/prefetch_appimage_runtime.py" --output "$runtime"
fi
printf '%s  %s\n' 2fca8b443c92510f1483a883f60061ad09b46b978b2631c807cd873a47ec260d "$runtime" | sha256sum -c -
mksquashfs "$root" "$stage/payload" -noappend -all-root -no-xattrs -comp zstd -no-progress
cat "$runtime" "$stage/payload" > "$stage/ZolNit.AppImage"
chmod 755 "$stage/ZolNit.AppImage"
offset=$("$stage/ZolNit.AppImage" --appimage-offset)
test "$offset" = "$(wc -c < "$runtime" | tr -d ' ')"
(cd "$stage" && ./ZolNit.AppImage --appimage-extract >/dev/null)
cmp "$bundle/ZolNit" "$stage/squashfs-root/usr/lib/ZolNit/ZolNit"
cmp "$bundle/manifest.json" "$stage/squashfs-root/usr/lib/ZolNit/manifest.json"
install -m755 "$stage/ZolNit.AppImage" "$dest"
