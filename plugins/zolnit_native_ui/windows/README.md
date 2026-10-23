# ZolNit WinUI 3 island

This is a Win32 Flutter-plugin host for a Windows App SDK WinUI 3 XAML Island.
It uses `DesktopWindowXamlSource`, not a Flutter Fluent imitation or a second
application/session owner. The Flutter view remains the native parent HWND.

## Pinned dependency

The required NuGet packages are `Microsoft.WindowsAppSDK` `1.7.250401001`,
`Microsoft.Windows.CppWinRT` `2.0.240405.15`, and its declared WebView2 metadata
dependency `Microsoft.Web.WebView2` `1.0.2903.40`; all downloads have pinned SHA256 checks.
On a normal Windows Flutter build, CMake invokes `scripts/restore-winappsdk.ps1`.
It restores that exact package under the CMake build directory, and uses the
pinned `Microsoft.Windows.CppWinRT` tool to generate the C++/WinRT projection
there. Nothing is installed globally and a warm build reuses the cache. The
only CI command is:

```powershell
flutter build windows --debug
```

The Visual Studio Desktop C++ workload and a Windows 10/11 SDK remain required
for the compiler and base Windows projections. The Flutter registrar requires
a shared plugin library; the Dart `ZOLNIT_NATIVE_UI` define controls presentation
without replacing that library with a CMake interface target.

`flutter build windows --debug` is the Windows runner compile entrypoint. It
also verifies that the generated registrar links the plugin and packages the
bootstrap DLL. This repository cannot run that check on macOS.
The plugin bundles `Microsoft.WindowsAppRuntime.Bootstrap.dll`, but it is a
framework-dependent integration: a matching Windows App Runtime must be present
on a new machine. The plugin does not claim to be self-contained; release
packaging must either install the matching runtime or add an explicit
self-contained Windows App SDK deployment step.

## Flutter host contract

`isAvailable` initializes the island and calls Dart `getSnapshot`. The shared
channel remains `com.zolmid.zolnit/native-ui`, with JSON strings in the standard
method codec. `publishSnapshot` and `performCommand` use the frozen v1 contract.

The Flutter host may additionally call these presentation-only methods:

* `setSurfaceBounds` with a StandardCodec map containing `x`, `y`, `width`,
  `height`, and `devicePixelRatio` doubles in Flutter-view logical pixels. The
  plugin turns them into child-HWND physical pixels.
* `showSurface` after the Flutter placeholder is ready, and `hideSurface` before
  that placeholder is removed.

The plugin registers the Flutter Windows top-level message delegate itself and
passes keyboard messages through WinUI's `ContentPreTranslateMessage`. The C
API message helper remains available for an embedding host that does not expose
Flutter's registrar delegate.

The island is destroyed before its `WindowsXamlManager` and dispatcher queue.
It retains only the current presentation snapshot in memory and clears
account-specific content when `accountGeneration` changes.

## Known limits of this integration

* x64 only; ARM64 and x86 Flutter Windows builds must use the Flutter surface.
* The projection is generated from the pinned package's `Microsoft.UI.Xaml`,
  `Microsoft.UI.Text`, `Microsoft.UI`, `Microsoft.Foundation` and
  `Microsoft.Graphics` metadata, plus the Windows SDK, with the pinned
  `cppwinrt`. `Microsoft.UI.Xaml.winmd` references WebView2 types; if
  generation reports `Microsoft.Web.WebView2.Core` as missing, pass
  `-DZOLNIT_WEBVIEW2_WINMD=<Microsoft.Web.WebView2.Core.winmd>` from the
  WebView2 `1.0.2903.40` package. That package is not restored or hash-pinned
  here.
* The plugin target re-enables C++ exceptions (the Flutter standard settings
  define `_HAS_EXCEPTIONS=0`), which C++/WinRT requires.
* Keyboard pre-translation uses the `ContentPreTranslateMessage` export, which
  is not in a public header and is unverified; the documented
  `IInputPreTranslateKeyboardSourceInterop` cannot forward a host message.
* Not yet verified on a Windows runner: compile, DLL load on a machine without
  the Windows App Runtime, focus/Tab/IME, UIA, DPI and airspace behavior.
