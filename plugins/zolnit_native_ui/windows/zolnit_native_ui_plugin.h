#ifndef ZOLNIT_NATIVE_UI_PLUGIN_H_
#define ZOLNIT_NATIVE_UI_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>
#include <optional>

#include "winui_surface.h"

namespace zolnit {

class ZolnitNativeUiPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  explicit ZolnitNativeUiPlugin(flutter::PluginRegistrarWindows* registrar);
  ~ZolnitNativeUiPlugin() override;

  bool ProcessMessage(HWND window, UINT message, WPARAM wparam, LPARAM lparam);

  ZolnitNativeUiPlugin(const ZolnitNativeUiPlugin&) = delete;
  ZolnitNativeUiPlugin& operator=(const ZolnitNativeUiPlugin&) = delete;

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void RequestSnapshot();
  void PerformCommand(const std::string& command);

  flutter::PluginRegistrarWindows* registrar_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  std::unique_ptr<WinUiSurface> surface_;
  std::optional<int> window_proc_delegate_id_;
};

}  // namespace zolnit

#endif  // ZOLNIT_NATIVE_UI_PLUGIN_H_
