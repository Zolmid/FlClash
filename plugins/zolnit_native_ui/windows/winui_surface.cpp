#include "winui_surface.h"

#include <windows.h>
#include <appmodel.h>
#include <MddBootstrap.h>
#include <WindowsAppSDK-VersionInfo.h>

#ifdef GetCurrentTime
#undef GetCurrentTime
#endif

#include <winrt/Microsoft.UI.Xaml.h>
#include <winrt/Microsoft.UI.Xaml.Controls.h>
#include <winrt/Microsoft.UI.Xaml.Hosting.h>
#include <winrt/Microsoft.UI.Xaml.Media.h>
#include <winrt/Microsoft.UI.Xaml.Media.Imaging.h>
#include <winrt/Microsoft.UI.Dispatching.h>
#include <winrt/Microsoft.UI.Content.h>
#include <winrt/Microsoft.UI.h>
#include <winrt/Microsoft.UI.Interop.h>
#include <winrt/Windows.Data.Json.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Globalization.NumberFormatting.h>
#include <winrt/Windows.Graphics.h>
#include <winrt/base.h>

#include <algorithm>
#include <cmath>
#include <sstream>
#include <limits>
#include <optional>

namespace zolnit {
namespace {

namespace muxc = winrt::Microsoft::UI::Xaml::Controls;
namespace mux = winrt::Microsoft::UI::Xaml;
namespace muxh = winrt::Microsoft::UI::Xaml::Hosting;
namespace mud = winrt::Microsoft::UI::Dispatching;
namespace muic = winrt::Microsoft::UI::Content;
namespace wdj = winrt::Windows::Data::Json;

std::string Utf8(const winrt::hstring& value) {
  return winrt::to_string(value);
}

winrt::hstring Text(const wdj::JsonObject& object, const wchar_t* name,
                    const winrt::hstring& fallback = L"") {
  if (!object.HasKey(name) ||
      object.GetNamedValue(name).ValueType() != wdj::JsonValueType::String) {
    return fallback;
  }
  return object.GetNamedString(name);
}

bool Bool(const wdj::JsonObject& object, const wchar_t* name, bool fallback = false) {
  return object.GetNamedBoolean(name, fallback);
}

int64_t Integer(const wdj::JsonObject& object, const wchar_t* name,
                int64_t fallback = 0) {
  return static_cast<int64_t>(object.GetNamedNumber(name, fallback));
}

std::optional<int64_t> OptionalInteger(const wdj::JsonObject& object,
                                       const wchar_t* name) {
  if (!object.HasKey(name) ||
      object.GetNamedValue(name).ValueType() != wdj::JsonValueType::Number) {
    return std::nullopt;
  }
  const auto value = object.GetNamedNumber(name);
  if (!std::isfinite(value) || value < 0 || std::floor(value) != value ||
      value >= static_cast<double>((std::numeric_limits<int64_t>::max)())) {
    return std::nullopt;
  }
  return static_cast<int64_t>(value);
}

bool HasRequiredLabels(const wdj::JsonObject& labels) {
  constexpr const wchar_t* kLabels[] = {
      L"connect", L"disconnect", L"disconnected", L"connecting", L"connected",
      L"disconnecting", L"connectionFailed", L"smartMode", L"globalMode",
      L"servers", L"plans", L"account", L"refresh", L"preferences", L"help",
      L"trafficRemaining", L"trafficUsed", L"upload", L"download", L"noPlan",
      L"noServers", L"signIn", L"restoringSession", L"offline", L"retry",
      L"safeMode", L"selectServer", L"currentPlan", L"loading",
  };
  return std::all_of(std::begin(kLabels), std::end(kLabels), [&](const auto* key) {
    return labels.HasKey(key) && labels.GetNamedValue(key).ValueType() == wdj::JsonValueType::String;
  });
}

winrt::hstring Label(const wdj::JsonObject& labels, const wchar_t* key) {
  return labels.GetNamedString(key, key);
}

winrt::hstring FormatBytes(std::optional<int64_t> value, bool per_second,
                           const winrt::hstring& locale) {
  static constexpr const wchar_t* kUnits[] = {L"B", L"KB", L"MB", L"GB", L"TB"};
  if (!value) return L"\u2014";
  double scaled = static_cast<double>(*value);
  size_t unit = 0;
  while (scaled >= 1024 && unit + 1 < std::size(kUnits)) {
    scaled /= 1024;
    ++unit;
  }
  auto languages = winrt::single_threaded_vector<winrt::hstring>();
  languages.Append(locale);
  auto formatter = winrt::Windows::Globalization::NumberFormatting::DecimalFormatter(languages);
  formatter.FractionDigits(scaled < 10 && unit > 0 ? 1 : 0);
  return formatter.FormatDouble(scaled) + L" " + kUnits[unit] + (per_second ? L"/s" : L"");
}

std::string EscapeJson(const std::string& text) {
  std::ostringstream result;
  for (const char character : text) {
    if (character == '"' || character == '\\') {
      result << '\\';
    }
    result << character;
  }
  return result.str();
}

winrt::hstring BrandAssetUri() {
  const HMODULE module = ::GetModuleHandleW(nullptr);
  wchar_t path[MAX_PATH]{};
  const DWORD length = ::GetModuleFileNameW(module, path, MAX_PATH);
  if (length == 0 || length == MAX_PATH) {
    return L"";
  }
  std::wstring directory(path, length);
  directory.erase(directory.find_last_of(L"\\/") + 1);
  std::replace(directory.begin(), directory.end(), L'\\', L'/');
  return L"file:///" + directory + L"assets/images/zolnit-horizontal-dark.png";
}

// Unverified against a Windows runtime: ContentPreTranslateMessage is not declared
// in any shipped public header. The documented
// IInputPreTranslateKeyboardSourceInterop only lets a host receive callbacks and
// cannot forward a host MSG, so it is not a drop-in replacement. A missing export
// leaves keyboard pre-translation inactive and never crashes.
bool PreTranslateMessage(const MSG& message) {
  using ContentPreTranslateMessageFn = BOOL(WINAPI*)(const MSG*);
  static const auto callback = []() -> ContentPreTranslateMessageFn {
    const HMODULE module = ::LoadLibraryW(L"Microsoft.UI.Windowing.Core.dll");
    return module == nullptr ? nullptr : reinterpret_cast<ContentPreTranslateMessageFn>(
        ::GetProcAddress(module, "ContentPreTranslateMessage"));
  }();
  return callback != nullptr && callback(&message) != FALSE;
}

}  // namespace

struct WinUiSurface::State {
  mud::DispatcherQueueController dispatcher{nullptr};
  muxh::WindowsXamlManager xaml_manager{nullptr};
  muxh::DesktopWindowXamlSource source{nullptr};
  muic::DesktopChildSiteBridge bridge{nullptr};
  wdj::JsonObject snapshot{nullptr};
  int64_t revision = -1;
  int64_t account_generation = -1;
  bool visible = false;
  bool rendering = false;
  bool connection_command_pending = false;
  bool com_initialized = false;
  bool runtime_bootstrapped = false;
  std::string servers_fingerprint;
  winrt::hstring mode_rule_label;
  winrt::hstring mode_global_label;
  muxc::TextBlock state_text{nullptr};
  muxc::TextBlock plan_text{nullptr};
  muxc::TextBlock traffic_text{nullptr};
  muxc::TextBlock upload_text{nullptr};
  muxc::TextBlock download_text{nullptr};
  muxc::Button connect_button{nullptr};
  muxc::ComboBox mode_box{nullptr};
  muxc::ListView server_list{nullptr};
  muxc::NavigationView navigation{nullptr};
  muxc::Grid root{nullptr};
};

WinUiSurface::WinUiSurface(HWND parent, CommandCallback on_command)
    : parent_(parent), on_command_(std::move(on_command)), state_(new State()) {}

WinUiSurface::~WinUiSurface() {
  ReleaseRuntime();
  delete state_;
  state_ = nullptr;
}

// Releases every WinRT object (UI tree, snapshot, bridge, source, XAML manager,
// dispatcher, in that order via State's member order) before the dynamic
// dependency and COM apartment are shut down, then leaves a fresh empty State.
void WinUiSurface::ReleaseRuntime() {
  if (state_ == nullptr) {
    return;
  }
  const bool bootstrapped = state_->runtime_bootstrapped;
  const bool com_initialized = state_->com_initialized;
  try {
    if (state_->source) {
      state_->source.Content(nullptr);
      state_->source.Close();
    }
    if (state_->xaml_manager) {
      state_->xaml_manager.Close();
    }
  } catch (const winrt::hresult_error&) {
  }
  delete state_;
  state_ = new State();
  if (bootstrapped) {
    MddBootstrapShutdown();
  }
  if (com_initialized) {
    ::CoUninitialize();
  }
}

bool WinUiSurface::Initialize() {
  if (state_->source) {
    return true;
  }
  if (parent_ == nullptr || ::GetCurrentThreadId() != ::GetWindowThreadProcessId(parent_, nullptr)) {
    return false;
  }
  try {
    const HRESULT com_result = ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    if (FAILED(com_result)) {
      return false;
    }
    state_->com_initialized = com_result == S_OK;
    PACKAGE_VERSION minimum_runtime{};
    minimum_runtime.Version = WINDOWSAPPSDK_RUNTIME_VERSION_UINT64;
    winrt::check_hresult(MddBootstrapInitialize(
        WINDOWSAPPSDK_RELEASE_MAJORMINOR,
        WINDOWSAPPSDK_RELEASE_VERSION_TAG_W,
        minimum_runtime));
    state_->runtime_bootstrapped = true;
    if (!mud::DispatcherQueue::GetForCurrentThread()) {
      state_->dispatcher = mud::DispatcherQueueController::CreateOnCurrentThread();
    }
    state_->xaml_manager = muxh::WindowsXamlManager::InitializeForCurrentThread();
    state_->source = muxh::DesktopWindowXamlSource();
    state_->source.Initialize(winrt::Microsoft::UI::GetWindowIdFromWindow(parent_));
    state_->bridge = state_->source.SiteBridge().as<muic::DesktopChildSiteBridge>();
    state_->source.TakeFocusRequested([this](auto&&, auto&&) {
      ::SetFocus(parent_);
    });
    BuildView();
    state_->bridge.Hide();
    return true;
  } catch (const winrt::hresult_error&) {
    ReleaseRuntime();
    return false;
  }
}

void WinUiSurface::BuildView() {
  auto root = muxc::Grid();
  state_->root = root;
  root.Resources().MergedDictionaries().Append(muxc::XamlControlsResources());
  auto rail = muxc::ColumnDefinition();
  rail.Width(mux::GridLengthHelper::FromPixels(220));
  auto content = muxc::ColumnDefinition();
  content.Width(mux::GridLengthHelper::FromValueAndType(1, mux::GridUnitType::Star));
  root.ColumnDefinitions().Append(rail);
  root.ColumnDefinitions().Append(content);

  state_->navigation = muxc::NavigationView();
  state_->navigation.IsSettingsVisible(false);
  state_->navigation.PaneDisplayMode(muxc::NavigationViewPaneDisplayMode::Left);
  for (const auto& destination : {L"connect", L"servers", L"plans", L"account"}) {
    auto item = muxc::NavigationViewItem();
    item.Tag(winrt::box_value(winrt::hstring(destination)));
    item.Content(winrt::hstring(destination));
    state_->navigation.MenuItems().Append(item);
  }
  state_->navigation.SelectionChanged([this](auto&&, const auto& args) {
    if (state_->rendering) {
      return;
    }
    const auto item = args.SelectedItem().try_as<muxc::NavigationViewItem>();
    if (item != nullptr && item.Tag() != nullptr) {
      EmitCommand("navigate", "{\"destination\":\"" + Utf8(winrt::unbox_value<winrt::hstring>(item.Tag())) + "\"}");
    }
  });
  muxc::Grid::SetColumn(state_->navigation, 0);
  root.Children().Append(state_->navigation);

  auto page = muxc::StackPanel();
  page.Spacing(14);
  page.Padding(mux::Thickness{28, 24, 28, 24});
  muxc::Grid::SetColumn(page, 1);

  state_->state_text = muxc::TextBlock();
  state_->state_text.FontSize(24);
  page.Children().Append(state_->state_text);

  const auto brand_uri = BrandAssetUri();
  if (!brand_uri.empty()) {
    auto brand = muxc::Image();
    auto brand_source = mux::Media::Imaging::BitmapImage();
    brand_source.UriSource(winrt::Windows::Foundation::Uri(brand_uri));
    brand.Source(brand_source);
    brand.MaxHeight(36);
    page.Children().Append(brand);
  }

  state_->connect_button = muxc::Button();
  state_->connect_button.MinWidth(160);
  state_->connect_button.Click([this](auto&&, auto&&) {
    const auto connection = Text(state_->snapshot, L"connectionState");
    EmitCommand(connection == L"connected" || connection == L"connecting" ? "disconnect" : "connect", "{}");
  });
  page.Children().Append(state_->connect_button);

  state_->mode_box = muxc::ComboBox();
  state_->mode_box.SelectionChanged([this](auto&&, auto&&) {
    if (state_->rendering) {
      return;
    }
    const auto index = state_->mode_box.SelectedIndex();
    if (index >= 0) {
      EmitCommand("setMode", index == 0 ? "{\"mode\":\"rule\"}" : "{\"mode\":\"global\"}");
    }
  });
  page.Children().Append(state_->mode_box);

  state_->plan_text = muxc::TextBlock();
  state_->traffic_text = muxc::TextBlock();
  state_->upload_text = muxc::TextBlock();
  state_->download_text = muxc::TextBlock();
  page.Children().Append(state_->plan_text);
  page.Children().Append(state_->traffic_text);
  page.Children().Append(state_->upload_text);
  page.Children().Append(state_->download_text);

  state_->server_list = muxc::ListView();
  state_->server_list.SelectionChanged([this](auto&&, const auto& args) {
    if (state_->rendering) {
      return;
    }
    const auto selected = args.AddedItems().Size() == 0 ? nullptr : args.AddedItems().GetAt(0).try_as<muxc::NavigationViewItem>();
    if (selected != nullptr && selected.Tag() != nullptr) {
      EmitCommand("selectServer", "{\"serverId\":\"" + EscapeJson(Utf8(winrt::unbox_value<winrt::hstring>(selected.Tag()))) + "\"}");
    }
  });
  page.Children().Append(state_->server_list);
  root.Children().Append(page);
  state_->source.Content(root);
}

bool WinUiSurface::PublishSnapshot(const std::string& snapshot_json) {
  if (!Initialize()) {
    return false;
  }
  try {
    const auto snapshot = wdj::JsonObject::Parse(winrt::to_hstring(snapshot_json));
    if (Integer(snapshot, L"schemaVersion", -1) != 1 || !snapshot.HasKey(L"labels")) {
      return false;
    }
    const auto labels = snapshot.GetNamedObject(L"labels");
    if (!HasRequiredLabels(labels)) {
      return false;
    }
    const int64_t revision = Integer(snapshot, L"revision", -1);
    const int64_t generation = Integer(snapshot, L"accountGeneration", -1);
    if (revision < 0 || generation < 0 || revision <= state_->revision) {
      return revision >= 0;
    }
    const auto previous_snapshot = state_->snapshot;
    if (state_->account_generation >= 0 && generation != state_->account_generation) {
      ClearAccountState();
    }
    state_->snapshot = snapshot;
    try {
      Render();
    } catch (...) {
      state_->snapshot = previous_snapshot;
      throw;
    }
    state_->revision = revision;
    state_->account_generation = generation;
    state_->connection_command_pending = false;
    return true;
  } catch (const winrt::hresult_error&) {
    return false;
  }
}

void WinUiSurface::ClearAccountState() {
  state_->server_list.Items().Clear();
  state_->servers_fingerprint.clear();
  state_->connection_command_pending = false;
  state_->plan_text.Text(L"");
  state_->traffic_text.Text(L"");
  state_->upload_text.Text(L"");
  state_->download_text.Text(L"");
}

void WinUiSurface::Render() {
  // Read every required container first so a malformed snapshot throws before
  // any visible state is changed.
  const auto labels = state_->snapshot.GetNamedObject(L"labels");
  const auto usage = state_->snapshot.GetNamedObject(L"usage");
  const auto traffic = state_->snapshot.GetNamedObject(L"traffic");
  const auto servers = state_->snapshot.GetNamedArray(L"servers");
  struct RenderingScope {
    bool& flag;
    explicit RenderingScope(bool& value) : flag(value) { flag = true; }
    ~RenderingScope() { flag = false; }
  } rendering_scope(state_->rendering);
  const auto connection = Text(state_->snapshot, L"connectionState");
  const auto session = Text(state_->snapshot, L"sessionStatus");
  const bool safe_mode = Bool(state_->snapshot, L"safeMode");
  state_->root.FlowDirection(Text(state_->snapshot, L"textDirection") == L"rtl"
                                 ? mux::FlowDirection::RightToLeft
                                 : mux::FlowDirection::LeftToRight);
  const bool actionable = session == L"signedIn" && !safe_mode &&
                          (connection == L"connected" || connection == L"disconnected" || connection == L"failed");
  const auto state_label = connection == L"connected" ? Label(labels, L"connected")
      : connection == L"connecting" ? Label(labels, L"connecting")
      : connection == L"disconnecting" ? Label(labels, L"disconnecting")
      : connection == L"failed" ? Label(labels, L"connectionFailed")
      : session == L"restoring" ? Label(labels, L"restoringSession")
      : session == L"offline" ? Label(labels, L"offline")
      : session == L"signedOut" ? Label(labels, L"signIn") : Label(labels, L"disconnected");
  state_->state_text.Text(state_label);
  state_->connect_button.Content(winrt::box_value(connection == L"connected" ? Label(labels, L"disconnect") : Label(labels, L"connect")));
  state_->connect_button.IsEnabled(actionable && !state_->connection_command_pending);

  const auto rule_label = Label(labels, L"smartMode");
  const auto global_label = Label(labels, L"globalMode");
  if (rule_label != state_->mode_rule_label || global_label != state_->mode_global_label) {
    state_->mode_box.Items().Clear();
    state_->mode_box.Items().Append(winrt::box_value(rule_label));
    state_->mode_box.Items().Append(winrt::box_value(global_label));
    state_->mode_rule_label = rule_label;
    state_->mode_global_label = global_label;
  }
  state_->mode_box.SelectedIndex(Text(state_->snapshot, L"mode") == L"global" ? 1 : 0);
  state_->mode_box.IsEnabled(session == L"signedIn" && !safe_mode);
  state_->server_list.IsEnabled(session == L"signedIn" && !safe_mode);

  const auto plan = Text(state_->snapshot, L"planName");
  state_->plan_text.Text(plan.empty() ? Label(labels, L"noPlan") : Label(labels, L"currentPlan") + L": " + plan);
  const auto locale = Text(state_->snapshot, L"locale", L"en");
  state_->traffic_text.Text(Label(labels, L"trafficUsed") + L": " +
                            FormatBytes(OptionalInteger(usage, L"usedBytes"), false, locale));
  state_->upload_text.Text(Label(labels, L"upload") + L": " +
                           FormatBytes(OptionalInteger(traffic, L"uploadBps"), true, locale));
  state_->download_text.Text(Label(labels, L"download") + L": " +
                             FormatBytes(OptionalInteger(traffic, L"downloadBps"), true, locale));

  const auto servers_fingerprint = Utf8(servers.Stringify());
  if (servers_fingerprint != state_->servers_fingerprint) {
    state_->server_list.Items().Clear();
    const auto selected_server = Text(state_->snapshot, L"selectedServerId");
    for (const auto& value : servers) {
      const auto server = value.GetObject();
      auto item = muxc::NavigationViewItem();
      item.Tag(winrt::box_value(Text(server, L"id")));
      item.Content(Text(server, L"name"));
      item.IsEnabled(Bool(server, L"available"));
      state_->server_list.Items().Append(item);
      if (Text(server, L"id") == selected_server) {
        state_->server_list.SelectedItem(item);
      }
    }
    if (servers.Size() == 0) {
      state_->server_list.Items().Append(winrt::box_value(Label(labels, L"noServers")));
    }
    state_->servers_fingerprint = servers_fingerprint;
  }
  for (uint32_t index = 0; index < state_->navigation.MenuItems().Size(); ++index) {
    const auto item = state_->navigation.MenuItems().GetAt(index).as<muxc::NavigationViewItem>();
    item.Content(Label(labels, winrt::unbox_value<winrt::hstring>(item.Tag()).c_str()));
    if (Text(state_->snapshot, L"destination") == winrt::unbox_value<winrt::hstring>(item.Tag())) {
      state_->navigation.SelectedItem(item);
    }
  }
}

void WinUiSurface::EmitCommand(const std::string& action, const std::string& payload) {
  if (state_->account_generation < 0 || !on_command_) {
    return;
  }
  GUID guid{};
  ::CoCreateGuid(&guid);
  wchar_t id[40]{};
  ::StringFromGUID2(guid, id, static_cast<int>(std::size(id)));
  if (action == "connect" || action == "disconnect") {
    state_->connection_command_pending = true;
    state_->connect_button.IsEnabled(false);
  }
  on_command_("{\"schemaVersion\":1,\"id\":\"" + EscapeJson(Utf8(id)) +
              "\",\"accountGeneration\":" + std::to_string(state_->account_generation) +
              ",\"action\":\"" + action + "\",\"payload\":" + payload + "}");
}

bool WinUiSurface::SetBounds(double x, double y, double width, double height,
                             double device_pixel_ratio) {
  if (!Initialize()) {
    return false;
  }
  if (device_pixel_ratio <= 0 || width < 0 || height < 0) {
    return false;
  }
  state_->bridge.MoveAndResize(winrt::Windows::Graphics::RectInt32{
      static_cast<int32_t>(std::lround(x * device_pixel_ratio)),
      static_cast<int32_t>(std::lround(y * device_pixel_ratio)),
      static_cast<int32_t>(std::lround(width * device_pixel_ratio)),
      static_cast<int32_t>(std::lround(height * device_pixel_ratio)),
  });
  return true;
}

void WinUiSurface::Show() {
  if (Initialize() && state_->bridge != nullptr) {
    state_->visible = true;
    state_->bridge.Show();
  }
}

void WinUiSurface::Hide() {
  if (state_->bridge != nullptr) {
    state_->visible = false;
    state_->bridge.Hide();
  }
}

bool WinUiSurface::ProcessMessage(HWND window, UINT message, WPARAM wparam, LPARAM lparam) {
  if (!state_->visible || state_->bridge == nullptr ||
      window != ::GetAncestor(parent_, GA_ROOT)) {
    return false;
  }
  const MSG input{window, message, wparam, lparam, 0, {0, 0}};
  return PreTranslateMessage(input);
}

}  // namespace zolnit
