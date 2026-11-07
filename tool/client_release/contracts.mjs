export const APP_ID = 'com.zolmid.zolnit';
export const MAX_ASSET_BYTES = 2 * 1024 * 1024 * 1024;
export const MAX_PART_BYTES = 8 * 1024 * 1024;
export const MIN_NONFINAL_PART_BYTES = 5 * 1024 * 1024;
export const TAG = /^v(0|[1-9]\d{0,9})\.(0|[1-9]\d{0,9})\.(0|[1-9]\d{0,9})$/;
export const NAME = /^ZolNit-(\d+\.\d+\.\d+)-(android-(?:arm64-v8a|armeabi-v7a|x86_64)\.apk|macos-(?:arm64|x64)\.dmg|windows-(?:arm64|x64)(?:-setup\.exe|\.(?:zip))|linux-(?:arm64|x64|x64-v[123])\.(?:AppImage|deb|rpm|tar\.zst|zip))$/;

export function compareTags(left, right) {
  const a = left.slice(1).split('.').map(Number), b = right.slice(1).split('.').map(Number);
  for (let index = 0; index < a.length; index += 1) if (a[index] !== b[index]) return a[index] - b[index];
  return 0;
}
export function exactPath(url) {
  if (url.search || /%|\/\/|\.\./.test(url.pathname)) return null;
  return url.pathname;
}
export function validateManifest(manifest) {
  if (!manifest || Object.keys(manifest).length !== 4 || manifest.schema_version !== 1 ||
      manifest.app_id !== APP_ID || manifest.updates_enabled !== true || !Array.isArray(manifest.releases) ||
      manifest.releases.length !== 1) throw new Error('invalid canonical manifest');
  const [release] = manifest.releases;
  if (!release || Object.keys(release).length !== 3 || !TAG.test(release.tag) ||
      typeof release.notes !== 'string' || new TextEncoder().encode(release.notes).length > 32768 || !Array.isArray(release.assets) || !release.assets.length || release.assets.length > 64) throw new Error('invalid release');
  const seen = new Set();
  for (const asset of release.assets) {
    if (!asset || Object.keys(asset).length !== 4 || !NAME.test(asset.name) || !asset.name.includes(`-${release.tag.slice(1)}-`) ||
        !Number.isSafeInteger(asset.size) || asset.size < 1 || asset.size > MAX_ASSET_BYTES ||
        !/^[a-f0-9]{64}$/.test(asset.sha256) || asset.url !== `https://link.zolmid.com/client/downloads/${release.tag}/${asset.name}` || seen.has(asset.name)) {
      throw new Error('invalid release asset');
    }
    seen.add(asset.name);
  }
  return release;
}
export function assetKey(tag, name) { return `releases/${tag}/${name}`; }
export function sha256Hex(bytes) { return crypto.subtle.digest('SHA-256', bytes).then(x => [...new Uint8Array(x)].map(b => b.toString(16).padStart(2, '0')).join('')); }
export function b64urlJson(value) { return JSON.parse(atob(value.replace(/-/g, '+').replace(/_/g, '/'))); }
