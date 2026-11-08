# iOS distribution preparation

This is a local, reversible preparation and export verification tool for stable
release tags (`vX.Y.Z`, default `v1.1.4`). It prepares and verifies manual
export for the three iOS targets:

- `com.zolmid.zolnit`
- `com.zolmid.zolnit.NECore` (`PlugIns/NECore.appex`)
- `com.zolmid.zolnit.Widget` (`PlugIns/Widget.appex`)

All three profiles must be present, non-expired, non-future-dated, owned by
Team `52QSDX4Y94`, set `get-task-allow=false`, declare
`packet-tunnel-provider`, include `group.com.zolmid.zolnit`, and authorize
`52QSDX4Y94.com.zolmid.zolnit.renewal` in `keychain-access-groups` for Runner
and NECore. Archive and exported bundles must carry
`ZolNitRenewalKeychainAccessGroup=52QSDX4Y94.com.zolmid.zolnit.renewal` and
`ZolNitRenewalWhileLocked=true` in both Runner and NECore `Info.plist`, and
signed exports must retain `52QSDX4Y94.com.zolmid.zolnit.renewal` in both
targets' signed entitlements. Ad Hoc
(`release-testing`) requires non-empty `ProvisionedDevices` and
`ProvisionsAllDevices=false`; App Store Connect (`app-store-connect`) forbids
`ProvisionedDevices` and requires `beta-reports-active=true` on the main app
profile. The default mode is read-only preflight/plan. Only `--execute` can
call `xcodebuild`, and it requires a valid `.xcarchive` bundle directory,
explicit `--team-id`, `--profile-sha256` for all three targets, and CMS
signature chain verification via `openssl cms -verify` against Apple Root CA
without `security cms` keychain writes or `-noverify` (raw `.plist` files are
rejected in `--execute`). Add
`--export-options-path /absolute/ExportOptions.plist` to retain the generated
0600 file; without it the file is temporary and removed after verification.

Examples (paths are intentionally placeholders):

```sh
python3 /absolute/tools/tool/apple_distribution/apple_distribution.py \
  --prepare-source \
  --repo /absolute/source \
  --source-tag v1.1.4 \
  --distribution app-store-connect

python3 tool/apple_distribution/apple_distribution.py \
  --source-tag v1.1.4 \
  --distribution release-testing \
  --app-profile /absolute/app.mobileprovision \
  --necore-profile /absolute/NECore.mobileprovision \
  --widget-profile /absolute/Widget.mobileprovision

python3 tool/apple_distribution/apple_distribution.py --execute \
  --source-tag v1.1.4 \
  --distribution app-store-connect \
  --team-id 52QSDX4Y94 \
  --archive-path /absolute/Runner.xcarchive \
  --export-path /absolute/export \
  --signing-identity 0123456789ABCDEF0123456789ABCDEF01234567 \
  --signing-keychain /absolute/temp.keychain-db \
  --app-profile /absolute/app.mobileprovision \
  --necore-profile /absolute/NECore.mobileprovision \
  --widget-profile /absolute/Widget.mobileprovision \
  --profile-sha256 app=<64-hex-sha256> \
  --profile-sha256 necore=<64-hex-sha256> \
  --profile-sha256 widget=<64-hex-sha256>
```

`release-testing` is the Ad Hoc export path; `app-store-connect` is the
TestFlight/App Store Connect export path (with optional `--upload-testflight`
argv support via `--asc-api-key-id`, `--asc-api-issuer-id`, and
`--asc-api-key-path` using `xcrun altool --upload-app ... --api-key ... --api-issuer ...`
and `API_PRIVATE_KEYS_DIR`). Unit tests use synthetic fixtures and fake command
runners and do not represent real Apple code-signing verification.

The workflow is manual-only and disabled by default. It does not modify or
invoke `client-release.yml`. It checks out the trusted tools revision
(`GITHUB_SHA`) under `tools/` and the stable release tag (`refs/tags/vX.Y.Z`)
under `source/`, verifies both SHAs, runs `source_preparation.py`
(`--prepare-source`) to project `direct` (Ad Hoc) or `apple-app-store`
(TestFlight) renewal configuration, builds an unsigned archive, and manually
signs the archive with the isolated temporary keychain before `--execute`
export. Missing secrets, missing signing identity, or an unsigned archive
without `--signing-identity` fail clearly.

Not connected here: server-side one-time device registration, idempotent task
queue, Apple Developer API/device registration, GitHub secret provisioning,
R2 storage, TestFlight upload, device installation, and end-to-end CI/R2
acceptance. No real credentials or private key material are generated.
