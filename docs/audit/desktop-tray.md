# Desktop tray integration audit

The comparison uses merge base `7c61c90` and the pinned Patched tip
`7ea4597c9182d40cd57da9fc2f2d5cc0a5f84c2f` (`patched-audit/main`).
The target keeps FlClash's current window plugin, lifecycle owners and UI assets.

| Patched changes | Result in this branch |
| --- | --- |
| `01238a37`, `8012efc6`, `e5cd6e32`, `2f30e433` shell/menu integration | Preserve the current tray facade, add the missing native menu capabilities and retain the status item's autosave name. |
| `066fba27`, `70fba956` Linux activation | Forward the native event timestamp and consumed Wayland activation token through tray events and item callbacks, the existing window visibility queue, and `plugins/window` to GTK. No `window_manager` dependency is restored. |
| `dfcd6e8e`, `72b5e22d` delay batches and aliases | Send one keyed native batch for changed presentations. Index every group entry by its resolved proxy and test URL so aliases in other groups receive the same measurement. |
| `577d80c0`, `6b8f8201`, `a3ce0316` submenu construction | Defer unopened macOS and Windows submenus. Keep Linux's complete GTK tree before AppIndicator/DBusMenu export, following Patched's final correction of its earlier lazy Linux implementation. |
| `7a26ddcf`, `e592f91e` desktop proxy selection | Expose groups and node selection on all three desktops, controlled by `showTrayProxySelection`. Show selected names, pending tests, delays, failures and warnings. |
| `1a33045d`, `9064d6ec`, `e013aca6`, `834f3f25` Windows menu state | Patch stable keyed rows instead of rebuilding during tests or selections. Defer structural replacements until menu close, keep the displayed callbacks alive, and retain native checkmarks. |
| `e592f91e`, `834f3f25` persistent delay actions | Per-group delay tests stay open on macOS and Windows; Windows handles mouse, Enter and Space using a native menu session. |
| `4f79fff2` profile actions | Add profile selection and subscription update actions. Re-read the selected profile and update state when invoked. |
| `4a5e0e69`, `3322cb97`, `f64371e9`, `5ea6daee` macOS rows | Carry the final native menu presentation, keyed updates and deferred rows, including warning foregrounds and cached image reuse. Keep the mainline speed-title renderer and its cap-height alignment. |
| `103cb8d8` Windows shell recovery | Retain mainline's accepted-show contract and continuing shell registration retries. Do not adopt Patched's later retry-attempt cap. Hide still removes any registration whose add may have landed. |
| `38b8e3d9` Linux SVG icons | Generate dedicated SVG assets from mainline's existing status sources, including the safe-mode icon. Other platforms' assets remain unchanged. |
| `e5772789` separators | Keep a single boundary between profile, proxy and ordinary action sections. |

Changes involving the old window-manager fork, window geometry, global hotkey
registration, proxy configuration or the privileged helper are outside this tray
port. Their existing mainline owners remain in place.

## Preserved contracts

- `AppTray.shutdown()` remains terminal; title, menu and later delay updates cannot
  recreate a hidden tray.
- Native `show` returns acceptance. Dart caches an unchanged signature only after
  acceptance and refreshes callbacks without a native rebuild when appropriate.
- The plugin serializes mutations. Tracking an open Windows menu does not block
  live row updates, while structural replacements retain only the latest request.
  Updates for a replacement's new keys stay in its pending snapshot even when the
  still-visible menu rejects those keys.
- Safe-mode state, icons and the macOS-only speed title retain mainline behavior.
- Delay work stays in the existing `ProxiesAction` task pool and pending-test
  state. The tray does not add a test scheduler or write zero into stored delays.
- Mainline's delay and pending-test providers publish live views. Tray refreshes
  compare cached presentations for indexed menu targets, rather than comparing
  aliased previous and next maps or scanning measurements from old profiles.
  Pending tests use their own state; a measured zero remains `0 ms`.
- Activation details remain attached to their queued show request. GTK consumes
  the token only on an active show; inactive shows keep their existing behavior.

## Validation

- Tray plugin Dart analysis and tests: passed (64 tests); the macOS native test is
  skipped on this Linux host.
- Window plugin Dart analysis and tests, including activation arguments: passed
  (14 tests).
- Linux native tray CTest: passed against GTK 3.24 and Ayatana AppIndicator,
  including 2,000-node initial DBusMenu export, nested items, keyed batches,
  selection updates, reopening and cleanup.
- Linux window plugin C++14 syntax check with `-Wall -Werror`: passed.
- Targeted root tests cover menu settings, alias delay batches, safe-mode assets,
  shutdown and activation ordering; the parent task runs these with the shared
  generated-code snapshot.

The standalone Linux native test additionally needs `libdbusmenu-gtk3-dev`
(`dbusmenu-gtk3-0.4`) and Xvfb. Product builds retain their existing GTK and
Ayatana AppIndicator / libappindicator fallback requirements.
Windows and macOS native tests are included but were not executed here. These
checks do not establish rendered appearance, real shell input, compositor focus
or Windows/macOS device behavior.
