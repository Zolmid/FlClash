# Patched updater audit

Reference: `FlClash-Patched` `7ea4597c`, common ancestor
`7c61c90ac20493b474d19c75ec96262b478b4b88`.

| Source | Decision | Local implementation |
| --- | --- | --- |
| `1de91ebb` | Port with changes | `app_update.dart`, `app_update_client.dart`, `app_installer.dart`, `package.dart`; provider, UI and native installation are integrated by their owners. |
| `197967cf` | Port | A release retains its exact tag URL; browser fallback can open that release instead of a moving `latest` link. |
| `43964ff1`, `3934fc9a` | Keep the main implementation | Existing `network_error.dart` owns localized HTTP/Core errors. The updater preserves typed Dio errors instead of adding a second error renderer. |

## Release source and integrity

`repository` is `Zolmid/FlClash`; `upstreamRepository` retains
`chen08209/FlClash` for attribution. Neither endpoint nor package metadata uses
the Patched repository. The GitHub release API is queried first and its
`digest: sha256:…` metadata supplies the checksum. A successful API response
without a usable digest permits a browser update only. If the API is
unavailable, the same repository's `version.json` is a compatibility fallback;
the final fallback reads its release redirect without granting installation.
No new manifest publishing pipeline is required.
A repository with no formal release (including one that has only prereleases)
returns no update when GitHub's release page answers 404. This does not alter
the existing upstream Telegram/Homebrew publication guards in `build.yaml`.

Checksums from the release source detect corrupted or mismatched downloads.
They are not an independent publisher signature.

The updater creates its own `HttpClient` through the base `HttpOverrides`
implementation and explicitly rejects invalid TLS certificates. It never uses
the application's optional certificate bypass. The existing Core proxy decision
and proxy credentials still apply. Initial asset URLs must use HTTPS on
`github.com`, port 443, under this repository's release-download path. Normal
GitHub download redirects to its CDN remain supported. Asset names are plain
safe basenames; URL tag, filename version, target suffix and release tag must
agree. Size must be positive, at most 2 GiB, and a target must have exactly one
matching asset.

## Download and installation

Operations across `AppInstaller` instances are mutually exclusive. Download
partials live under `app-updates/<tag>-<sha256>/`; AppImages use the same scoped
layout beside the installed image so final replacement stays on one filesystem.
Desktop staging directories are mode 0700. A `.part` is promoted only after its
size and SHA256 match. Installation rechecks the recorded verified download;
the privileged Linux path additionally copies into a private root-owned
temporary directory and rechecks the hash there. Cleanup removes only the
current operation's files. Older staging directories remain available to the
platform's normal temporary/cache cleanup.
Privileged package-manager front ends must resolve to standard system binary
directories; a user-writable PATH wrapper cannot become the elevated command.

The client rejects incompatible declared lengths and Content-Range totals,
and bounds every incoming stream chunk before writing it. Size failures cannot
reach promotion, even with an absent or dishonest Content-Length. A complete
server range shorter than the manifest's package size is also rejected.

Range downloads resume after transient failures, restart when a server ignores
Range, validate Content-Range, and retain a partial on cancellation. Cancellation
also cancels the retry timer. Certificate errors, cancellation and ordinary
client errors do not trigger the transient retry path. Download and check errors
remain typed for the existing UI error handling.

Windows passes this instance's PID plus a fresh 64-character hexadecimal nonce
to Inno Setup and uses the attempt-specific `<setup>.<nonce>.ready` path. It
accepts only an exact nonce in that marker and never clears another attempt's
ready or acknowledgement files. The parent
rechecks its deadline and installer exit state after each readiness await and
after flushing a nonce-specific acknowledgement temporary file, then atomically
publishes `<ready>.ack`. A successful acknowledgement rename is the commit
point; the parent does not subsequently report a handshake timeout. Refused
elevation, a wrong marker, an installer exit, an acknowledgement write failure
or a timeout leaves the application running without granting installation.
Inno requires the matching acknowledgement within 30 seconds before it can
wait for this instance to exit. A late ready file after a parent timeout can
therefore never schedule an install for a later ordinary exit. The native
installer owns process-handle verification and atomic ready publication.

macOS enumerates all top-level, non-symlink application bundles and requires
exactly one with the installed bundle identifier and current architecture.
Each attempt has a unique staging/backup directory. Backup cleanup is allowed
only after promotion succeeds; a failed restoration retains this attempt's
backup. It preserves quarantine and never removes another operation's backup
or a static `.previous` directory from an earlier operation.

Android hands an APK in the cache's `app-updates/` subtree to the native app
channel. Native code owns package/version/signature validation, the
PackageInstaller session, unknown-source permission and the system installer.
Its status is `started`,
`permissionDenied`, or `failed`. iOS is explicitly unsupported for in-app package
installation and retains the release-page fallback. Portable desktop copies
also use browser downloads.

`APP_ARCH` is checked against the running ABI. x64 variants are accepted only
for Windows/Linux x64, macOS accepts x64/arm64, and Android uses its APK ABI names.
Version comparison handles prerelease ordering, large numeric prerelease
identifiers, optional `v` and abbreviated core versions. Numeric build numbers
retain the existing application-specific tie break.

## Verification

Focused suites:

- `test/common/app_update_test.dart`: target detection, ABI compatibility,
  official asset metadata, duplicate/version rejection, SHA256, package-manager
  selection, elevated private-copy hash verification. Shell tests substitute a
  local `systemctl` stub and cannot restart the host's helper.
- `test/common/app_update_client_test.dart`: release API/manifest/browser
  fallback, no formal release, typed network errors, a real untrusted TLS server
  under an ambient certificate bypass, verified staging, Content-Length and
  stream limits, operation exclusion, PID/nonce argv.
- `test/common/app_installer_macos_test.dart`: executes the actual installer
  shell with local command stubs and no GUI or DMG mount. Covers a wrong first
  bundle, architecture mismatch, symlinks, multiple matching bundles, promotion
  failure, restoration failure and preservation of other backups.
- `test/common/app_installer_windows_test.dart`: portable file-handshake tests
  for matching readiness, late readiness, wrong nonces, installer exit, deadline
  expiry during acknowledgement writes, publication failure and the atomic
  acknowledgement commit point. These tests do not launch an installer.
- `test/common/app_update_download_test.dart`: interrupted downloads, resume,
  ignored/unsatisfiable ranges, cancellation and non-retriable client errors.
- `test/common/package_version_test.dart`: SemVer ordering, numeric prerelease
  bounds, legacy build comparison and malformed versions.

The TLS key/certificate under `test/fixtures/update_tls_*` are generated,
self-signed test data with no production identity or credentials.

Scoped Dart formatting passed using `/workspace/.flclash-env/env.sh`. Shell
syntax checks passed, and the portable macOS state scenarios were also executed
successfully with the same source script and test command stubs. Flutter tests
and code generation remain coordinated by the shared workspace's root agent.
Native Windows elevation, Android permission/system installer,
macOS mount/replace and actual AppImage/package-manager updates still require
their host platforms. The portable tests cannot prove those host integrations.
