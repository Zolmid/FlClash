#include "include/zolnit_native_ui/zolnit_native_ui_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "zolnit_native_ui_plugin.h"

namespace {
zolnit::ZolnitNativeUiPlugin* active_plugin = nullptr;
}

namespace zolnit {
void ZolnitNativeUiPluginCApiUnregister(ZolnitNativeUiPlugin* plugin);
}

void zolnit::ZolnitNativeUiPluginCApiUnregister(ZolnitNativeUiPlugin* plugin) {
  if (active_plugin == plugin) {
    active_plugin = nullptr;
  }
}

void ZolnitNativeUiPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  auto* windows_registrar = flutter::PluginRegistrarManager::GetInstance()
      ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar);
  auto plugin = std::make_unique<zolnit::ZolnitNativeUiPlugin>(windows_registrar);
  active_plugin = plugin.get();
  windows_registrar->AddPlugin(std::move(plugin));
}

BOOL ZolnitNativeUiPluginCApiProcessMessage(
    HWND window, UINT message, WPARAM wparam, LPARAM lparam) {
  return active_plugin != nullptr &&
          active_plugin->ProcessMessage(window, message, wparam, lparam)
      ? TRUE
      : FALSE;
}
