#include "zolnit_native_ui_plugin.h"

#include <flutter/standard_method_codec.h>
#include <flutter/method_result.h>

#include <windows.h>

#include <optional>

namespace zolnit {
namespace {

constexpr char kChannel[] = "com.zolmid.zolnit/native-ui";

class SnapshotResult final : public flutter::MethodResult<flutter::EncodableValue> {
 public:
  explicit SnapshotResult(std::function<void(const std::string&)> on_success,
                          std::function<void()> on_failure = {})
      : on_success_(std::move(on_success)), on_failure_(std::move(on_failure)) {}

 protected:
  void SuccessInternal(const flutter::EncodableValue* result) override {
    if (const auto* json = result == nullptr ? nullptr : std::get_if<std::string>(result)) {
      on_success_(*json);
    } else if (on_failure_) {
      on_failure_();
    }
  }

  void ErrorInternal(const std::string&, const std::string&,
                     const flutter::EncodableValue*) override { if (on_failure_) on_failure_(); }
  void NotImplementedInternal() override { if (on_failure_) on_failure_(); }

 private:
  std::function<void(const std::string&)> on_success_;
  std::function<void()> on_failure_;
};

const std::string* JsonArgument(
    const flutter::MethodCall<flutter::EncodableValue>& call) {
  return std::get_if<std::string>(call.arguments());
}

const double* NumberAt(const flutter::EncodableMap& map, const char* key) {
  const auto found = map.find(flutter::EncodableValue(key));
  return found == map.end() ? nullptr : std::get_if<double>(&found->second);
}

}  // namespace

void ZolnitNativeUiPluginCApiUnregister(ZolnitNativeUiPlugin* plugin);

void ZolnitNativeUiPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto plugin = std::make_unique<ZolnitNativeUiPlugin>(registrar);
  registrar->AddPlugin(std::move(plugin));
}

ZolnitNativeUiPlugin::ZolnitNativeUiPlugin(
    flutter::PluginRegistrarWindows* registrar)
    : registrar_(registrar),
      channel_(std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), kChannel,
          &flutter::StandardMethodCodec::GetInstance())) {
  channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        HandleMethodCall(call, std::move(result));
      });

  auto* view = registrar_->GetView();
  const HWND flutter_view = view == nullptr ? nullptr : view->GetNativeWindow();
  surface_ = std::make_unique<WinUiSurface>(
      flutter_view, [this](const std::string& command) { PerformCommand(command); });
  window_proc_delegate_id_ = registrar_->RegisterTopLevelWindowProcDelegate(
      [this](HWND window, UINT message, WPARAM wparam, LPARAM lparam)
          -> std::optional<LRESULT> {
        return ProcessMessage(window, message, wparam, lparam) ? std::optional<LRESULT>(0)
                                                               : std::nullopt;
      });
}

ZolnitNativeUiPlugin::~ZolnitNativeUiPlugin() {
  alive_.reset();
  if (window_proc_delegate_id_) {
    registrar_->UnregisterTopLevelWindowProcDelegate(*window_proc_delegate_id_);
  }
  channel_->SetMethodCallHandler(nullptr);
  ZolnitNativeUiPluginCApiUnregister(this);
}

void ZolnitNativeUiPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (call.method_name() == "isAvailable") {
    const bool available = surface_ != nullptr && surface_->Initialize();
    if (available) {
      RequestSnapshot();
    }
    result->Success(flutter::EncodableValue(available));
    return;
  }
  if (call.method_name() == "publishSnapshot") {
    const auto* json = JsonArgument(call);
    if (json == nullptr || !surface_->PublishSnapshot(*json)) {
      result->Error("invalid_snapshot", "Snapshot did not satisfy contract.v1.");
      return;
    }
    result->Success();
    return;
  }
  if (call.method_name() == "setSurfaceBounds") {
    const auto* bounds = std::get_if<flutter::EncodableMap>(call.arguments());
    const auto* x = bounds == nullptr ? nullptr : NumberAt(*bounds, "x");
    const auto* y = bounds == nullptr ? nullptr : NumberAt(*bounds, "y");
    const auto* width = bounds == nullptr ? nullptr : NumberAt(*bounds, "width");
    const auto* height = bounds == nullptr ? nullptr : NumberAt(*bounds, "height");
    const auto* ratio = bounds == nullptr ? nullptr : NumberAt(*bounds, "devicePixelRatio");
    if (x == nullptr || y == nullptr || width == nullptr || height == nullptr ||
        ratio == nullptr || !surface_->SetBounds(*x, *y, *width, *height, *ratio)) {
      result->Error("invalid_surface_bounds", "Expected x, y, width, height, devicePixelRatio.");
      return;
    }
    result->Success();
    return;
  }
  if (call.method_name() == "showSurface") {
    surface_->Show();
    result->Success();
    return;
  }
  if (call.method_name() == "hideSurface") {
    surface_->Hide();
    result->Success();
    return;
  }
  result->NotImplemented();
}

void ZolnitNativeUiPlugin::RequestSnapshot() {
  channel_->InvokeMethod(
      "getSnapshot", nullptr,
      std::make_unique<SnapshotResult>([this](const std::string& json) {
        surface_->PublishSnapshot(json);
      }));
}

void ZolnitNativeUiPlugin::PerformCommand(const std::string& command) {
  const std::weak_ptr<bool> alive = alive_;
  const auto complete = [this, alive, command]() {
    if (alive.expired()) return;
    surface_->CompleteCommand(command);
  };
  channel_->InvokeMethod("performCommand",
      std::make_unique<flutter::EncodableValue>(command),
      std::make_unique<SnapshotResult>([complete](const std::string&) { complete(); }, complete));
}

bool ZolnitNativeUiPlugin::ProcessMessage(HWND window, UINT message,
                                          WPARAM wparam, LPARAM lparam) {
  return surface_ != nullptr && surface_->ProcessMessage(window, message, wparam, lparam);
}

}  // namespace zolnit
