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

Manual runs are disabled by default. An explicitly approved export check can
also run on a workflow-file push to `codex/apple-distribution-prep` with the
exact `ci(ios): validate approved export-only archive` subject prefix. This
branch trigger always selects App Store export without uploading to TestFlight.
It does not modify or invoke `client-release.yml`. It checks out the trusted tools revision
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

`signing_transport.py` provides bounded, injectable transport for the staged
device runner: source authorization, job claim/renew/complete, verified private
archive downloads, and lease-bound multipart uploads to R2. It refreshes its
caller-provided OIDC token for every request, rejects redirects, and reports
errors without response bodies or credentials. Its synthetic tests do not
enable the production signing runner or prove an end-to-end device install.

## Device signer (disabled by default)

`device_signer.py` connects the modules above into two opt-in operations. Every mode exits
with status 3 unless `ZOLNIT_APPLE_DEVICE_SIGNING_ENABLED=true`.

- `archive-prepare` binds a prepared stable tag tree (tag commit, `pubspec.yaml` version and
  build, and the `core/Clash.Meta` gitlink plus checkout equal to `--core-sha`) to an unsigned
  direct-distribution `.xcarchive` whose Runner, NECore, and Widget versions match. It packs a
  deterministic zip that `extract_verified_archive` accepts. Relative symlinks resolving inside the
  archive are materialized. Absolute, escaping, dangling, or cyclic links, special files, and key
  material fail. `_CodeSignature`, `CodeResources`, and provisioning profiles are stripped, and
  executable bits are kept. The zip is re-extracted and revalidated before a 0600 receipt is written.
- `archive-publish` uploads that zip and posts `signer/archive-ready` with `schema_version: 1`,
  tag, source SHA, build, key, digest, size, and extensions exactly
  `[com.zolmid.zolnit.NECore, com.zolmid.zolnit.Widget]`. The reply must be `state: ready` with
  identical fields.
- `sign-one` claims at most one job and asks `GET /__release/v1/apple/signed/status/{job_id}`
  (lease, tag, source, archive digest, and expected artifact key in headers). On `ready`, it
  completes with the stored metadata and skips Apple, export, and upload. Otherwise it downloads and
  extracts the verified archive, ensures the device and three per-device Ad Hoc profiles through the
  App Store Connect API, signs and exports a private copy, and verifies the IPA's signed entitlements
  and embedded profile digests. It then renews the lease, uploads with `apple_device_resource_id`,
  and completes. The artifact expiry is computed once, as the minimum of now + 7 days and every
  profile expiry, and is used for both upload and completion.

A heartbeat renews the lease every 60 seconds (retrying every 10 seconds on transient errors) and
enforces a hard 30-minute ceiling. A 4xx renewal, an expiring or regressing deadline, or the ceiling
marks the lease lost. The cancellable runner then kills the active process group, such as
`xcodebuild` or `codesign`, and no upload or completion follows. Transient completion failures are
retried three times, and a later run recovers through the status endpoint.

Each multipart PUT carries `X-Content-Sha256` (lowercase hex of that part) together with
`X-Final-Part` and, for signed uploads, `X-Signing-Lease`. A permanent provisioning, archive, or export
failure that happens before upload starts is reported once, while the lease is still live, as
`{outcome: failed, error_code, retryable: false}`. The `error_code` is either the stable module code,
`export_validation_failed`, or `export_command_failed`. Transient Apple errors (5xx, 429, 401, 403, network),
transport and OIDC errors, a lost lease, and anything after upload starts are never reported as failed.
Those jobs recover through lease expiry or the status endpoint, so a stored ready artifact is never
overwritten.

The OIDC factory reads `ACTIONS_ID_TOKEN_REQUEST_URL`/`ACTIONS_ID_TOKEN_REQUEST_TOKEN`. It accepts only
HTTPS `*.actions.githubusercontent.com`, appends only `audience=zolnit-apple-device-signer`, and sends
the request token as a header. It rejects redirects, checks the audience, issuer, and expiry, and
refreshes when less than 120 seconds of validity remain. `--config` must be an owner-only 0600 JSON
file with exactly these keys: `schema_version`, `team_id`, `api_key_path`, `api_key_id`,
`api_issuer_id`, `signing_keychain`, `signing_identity` (SHA-1), `certificate_resource_id`,
`certificate_sha256` (DER), and `bundle_resource_ids` ({`app`, `necore`, `widget`}).
The keychain identity must match the certificate digest. UDIDs never appear in argv, paths, or output.

`.github/workflows/apple-device-signer.yml` runs only through `workflow_dispatch` on
`codex/apple-distribution-prep` with the repository variable `APPLE_DEVICE_SIGNING_ENABLED == 'true'`.
A push of the file to that branch only registers the workflow. Inputs: `operation` (`sign` |
`archive`), plus `source_tag` for archive only. Required configuration is the existing
`apple-distribution` secrets `APPLE_BUILD_P12_BASE64`, `APPLE_BUILD_P12_PASSWORD`,
`APPLE_ASC_API_KEY_ID`, `APPLE_ASC_API_ISSUER_ID`, and `APPLE_ASC_API_KEY_P8_BASE64`, plus these variables:
`APPLE_DEVICE_SIGNER_TOOLS_SHA` (must equal the dispatched commit), `APPLE_DEVICE_SIGNER_CORE_SHA`,
`APPLE_DEVICE_CERTIFICATE_RESOURCE_ID`, `APPLE_DEVICE_CERTIFICATE_SHA256`,
`APPLE_BUNDLE_RESOURCE_ID_APP`, `APPLE_BUNDLE_RESOURCE_ID_NECORE`, and `APPLE_BUNDLE_RESOURCE_ID_WIDGET`.
It uploads no artifacts, never uses the App Store profiles, and never uploads to TestFlight.
