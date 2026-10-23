#ifndef FLUTTER_PLUGIN_ZOLNIT_NATIVE_UI_PLUGIN_C_API_H_
#define FLUTTER_PLUGIN_ZOLNIT_NATIVE_UI_PLUGIN_C_API_H_

#include <flutter_plugin_registrar.h>
#include <windows.h>

#ifdef ZOLNIT_NATIVE_UI_PLUGIN_IMPL
#define ZOLNIT_NATIVE_UI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define ZOLNIT_NATIVE_UI_PLUGIN_EXPORT __declspec(dllimport)
#endif

#ifdef __cplusplus
extern "C" {
#endif

ZOLNIT_NATIVE_UI_PLUGIN_EXPORT void ZolnitNativeUiPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar);

// Forward before Flutter dispatch to preserve keyboard focus across the XAML island.
ZOLNIT_NATIVE_UI_PLUGIN_EXPORT BOOL ZolnitNativeUiPluginCApiProcessMessage(
    HWND window, UINT message, WPARAM wparam, LPARAM lparam);

#ifdef __cplusplus
}
#endif

#endif  // FLUTTER_PLUGIN_ZOLNIT_NATIVE_UI_PLUGIN_C_API_H_
