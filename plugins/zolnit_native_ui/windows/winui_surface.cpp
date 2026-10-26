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
#include <winrt/Microsoft.UI.Xaml.Controls.Primitives.h>
#include <winrt/Microsoft.UI.Xaml.Hosting.h>
#include <winrt/Microsoft.UI.Xaml.Media.h>
#include <winrt/Microsoft.UI.Xaml.Markup.h>
#include <winrt/Microsoft.UI.Xaml.Automation.h>
#include <winrt/Microsoft.UI.Xaml.Media.Imaging.h>
#include <winrt/Microsoft.UI.Dispatching.h>
#include <winrt/Microsoft.UI.Content.h>
#include <winrt/Microsoft.UI.h>
#include <winrt/Microsoft.UI.Interop.h>
#include <winrt/Windows.Data.Json.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Globalization.h>
#include <winrt/Windows.Globalization.NumberFormatting.h>
#include <winrt/Windows.Graphics.h>
#include <winrt/base.h>

#include <algorithm>
#include <cmath>
#include <sstream>
#include <limits>
#include <optional>
#include <set>
#include <vector>
#include <string_view>

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
  return static_cast<int64_t>(object.GetNamedNumber(name, static_cast<double>(fallback)));
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

struct ReturnRouteOption {
  winrt::hstring id;
  winrt::hstring label;
};

struct ReturnRoute {
  winrt::hstring title;
  winrt::hstring selected_id;
  bool enabled;
  std::vector<ReturnRouteOption> options;
};

std::optional<ReturnRoute> ParseReturnRoute(const wdj::JsonObject& snapshot) {
  try {
    if (!snapshot.HasKey(L"returnRoute") ||
        snapshot.GetNamedValue(L"returnRoute").ValueType() != wdj::JsonValueType::Object) return std::nullopt;
    const auto value = snapshot.GetNamedObject(L"returnRoute");
    const auto title = Text(value, L"title");
    if (title.empty() || title.size() > 4096 || !value.HasKey(L"enabled") ||
        value.GetNamedValue(L"enabled").ValueType() != wdj::JsonValueType::Boolean) return std::nullopt;
    const auto options = value.GetNamedArray(L"options");
    if (options.Size() > 3) return std::nullopt;
    ReturnRoute route{title, L"", value.GetNamedBoolean(L"enabled"), {}};
    std::set<std::wstring> ids;
    for (const auto& raw : options) {
      if (raw.ValueType() != wdj::JsonValueType::Object) return std::nullopt;
      const auto option = raw.GetObject();
      const auto id = Text(option, L"id");
      const auto label = Text(option, L"label");
      if ((id != L"direct" && id != L"hk_lite" && id != L"hk_optimized") ||
          label.empty() || label.size() > 4096 || !ids.insert(std::wstring(id)).second) return std::nullopt;
      route.options.push_back({id, label});
    }
    if (value.HasKey(L"selectedId") && value.GetNamedValue(L"selectedId").ValueType() != wdj::JsonValueType::Null) {
      route.selected_id = Text(value, L"selectedId");
      if (ids.count(std::wstring(route.selected_id)) == 0) return std::nullopt;
    }
    return route;
  } catch (const winrt::hresult_error&) {
    return std::nullopt;
  }
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
  static constexpr const wchar_t* kUnits[] = {L"B", L"KiB", L"MiB", L"GiB", L"TiB"};
  if (!value) return L"\u2014";
  double scaled = static_cast<double>(*value);
  size_t unit = 0;
  while (scaled >= 1024 && unit + 1 < std::size(kUnits)) {
    scaled /= 1024;
    ++unit;
  }
  auto languages = winrt::single_threaded_vector<winrt::hstring>();
  languages.Append(locale);
  auto formatter = winrt::Windows::Globalization::NumberFormatting::DecimalFormatter(
      languages, winrt::Windows::Globalization::GeographicRegion().Code());
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
  return winrt::hstring(
      (L"file:///" + directory + L"data/flutter_assets/assets/images/zolnit-horizontal-dark.png").c_str());
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
  std::set<std::string> pending_commands;
  bool com_initialized = false;
  bool runtime_bootstrapped = false;
  std::string servers_fingerprint;
  winrt::hstring mode_rule_label;
  winrt::hstring mode_global_label;
  muxc::TextBlock state_text{nullptr};
  muxc::TextBlock plan_text{nullptr};
  muxc::TextBlock plan_heading{nullptr};
  muxc::TextBlock remaining_heading{nullptr};
  muxc::TextBlock remaining_text{nullptr};
  muxc::TextBlock route_heading{nullptr};
  muxc::TextBlock route_text{nullptr};
  muxc::TextBlock connect_label{nullptr};
  muxc::TextBlock power_glyph{nullptr};
  muxc::ProgressBar usage_progress{nullptr};
  muxc::TextBlock traffic_text{nullptr};
  muxc::TextBlock upload_text{nullptr};
  muxc::TextBlock download_text{nullptr};
  muxc::Button connect_button{nullptr};
  muxc::ComboBox mode_box{nullptr};
  muxc::ComboBox return_route_box{nullptr};
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
  state_->navigation.OpenPaneLength(210);
  state_->navigation.CompactPaneLength(56);
  for (const auto& destination : {L"connect", L"servers", L"plans", L"account"}) {
    auto item = muxc::NavigationViewItem();
    auto icon = muxc::FontIcon();
    icon.FontFamily(mux::Media::FontFamily(L"Segoe MDL2 Assets"));
    const std::wstring_view target(destination);
    icon.Glyph(target == L"connect" ? L"\xE80F" : target == L"servers" ? L"\xE774"
        : target == L"plans" ? L"\xE8C7" : L"\xE77B");
    item.Icon(icon);
    item.Tag(winrt::box_value(winrt::hstring(destination)));
    item.Content(winrt::box_value(winrt::hstring(L"")));
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
  page.Spacing(18);
  page.Padding(mux::Thickness{28, 24, 28, 28});
  page.MaxWidth(1320);
  page.HorizontalAlignment(mux::HorizontalAlignment::Stretch);

  const auto brand_uri = BrandAssetUri();
  if (!brand_uri.empty()) {
    auto brand = muxc::Image();
    auto brand_source = mux::Media::Imaging::BitmapImage();
    brand_source.UriSource(winrt::Windows::Foundation::Uri(brand_uri));
    brand.Source(brand_source);
    brand.Height(32);
    brand.HorizontalAlignment(mux::HorizontalAlignment::Left);
    auto brand_backdrop = muxc::Border();
    brand_backdrop.Background(mux::Media::SolidColorBrush(winrt::Microsoft::UI::ColorHelper::FromArgb(255, 32, 44, 51)));
    brand_backdrop.Padding(mux::Thickness{12, 8, 12, 8});
    brand_backdrop.CornerRadius(mux::CornerRadius{8, 8, 8, 8});
    brand_backdrop.HorizontalAlignment(mux::HorizontalAlignment::Left);
    brand_backdrop.Child(brand);
    page.Children().Append(brand_backdrop);
  }

  auto dashboard = muxc::Grid();
  dashboard.ColumnSpacing(18);
  dashboard.RowSpacing(18);
  for (int index = 0; index < 2; ++index) {
    dashboard.ColumnDefinitions().Append(muxc::ColumnDefinition());
    auto row = muxc::RowDefinition();
    row.Height(mux::GridLengthHelper::FromValueAndType(1, mux::GridUnitType::Auto));
    dashboard.RowDefinitions().Append(row);
  }
  auto hero = muxc::Border();
  hero.CornerRadius(mux::CornerRadius{8, 8, 8, 8});
  hero.MinHeight(278);
  auto hero_grid = muxc::Grid();
  hero_grid.Padding(mux::Thickness{24, 24, 24, 24});
  auto map = mux::Markup::XamlReader::Load(LR"(<Viewbox xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" Opacity="0.09" IsHitTestVisible="False" Margin="8">
    <Path Width="600" Height="290" Fill="#506A7A" Data="M30,67 L84,23 174,35 204,75 138,116 120,157 66,116 Z M144,139 L222,157 234,197 186,267 162,212 Z M258,55 L330,29 378,52 456,29 570,73 510,122 426,116 390,157 330,113 Z M282,113 L360,125 384,177 324,232 288,177 Z M462,197 L540,194 570,235 498,252 Z"/>
  </Viewbox>)").as<mux::UIElement>();
  hero_grid.Children().Append(map);
  auto hero_content = muxc::StackPanel();
  hero_content.Spacing(14);
  hero_content.VerticalAlignment(mux::VerticalAlignment::Center);
  hero_content.HorizontalAlignment(mux::HorizontalAlignment::Center);
  state_->state_text = muxc::TextBlock();
  state_->state_text.FontSize(22);
  state_->state_text.TextWrapping(mux::TextWrapping::Wrap);
  state_->state_text.TextAlignment(mux::TextAlignment::Center);
  hero_content.Children().Append(state_->state_text);

  state_->connect_button = muxc::Button();
  state_->connect_button.Width(80);
  state_->connect_button.Height(80);
  state_->connect_button.CornerRadius(mux::CornerRadius{40, 40, 40, 40});
  state_->connect_button.HorizontalAlignment(mux::HorizontalAlignment::Center);
  state_->power_glyph = muxc::TextBlock();
  state_->power_glyph.FontFamily(mux::Media::FontFamily(L"Segoe MDL2 Assets"));
  state_->power_glyph.Text(L"\xE7E8");
  state_->power_glyph.FontSize(30);
  state_->connect_button.Content(state_->power_glyph);
  state_->connect_button.Click([this](auto&&, auto&&) {
    const auto connection = Text(state_->snapshot, L"connectionState");
    EmitCommand(connection == L"connected" || connection == L"connecting" ? "disconnect" : "connect", "{}");
  });
  hero_content.Children().Append(state_->connect_button);
  state_->connect_label = muxc::TextBlock();
  state_->connect_label.TextAlignment(mux::TextAlignment::Center);
  state_->connect_label.TextWrapping(mux::TextWrapping::Wrap);
  hero_content.Children().Append(state_->connect_label);
  state_->route_text = muxc::TextBlock();
  state_->route_text.TextAlignment(mux::TextAlignment::Center);
  state_->route_text.TextWrapping(mux::TextWrapping::Wrap);
  hero_content.Children().Append(state_->route_text);
  hero_grid.Children().Append(hero_content);
  hero.Child(hero_grid);
  dashboard.Children().Append(hero);

  auto membership = muxc::Border();
  membership.CornerRadius(mux::CornerRadius{8, 8, 8, 8});
  membership.Padding(mux::Thickness{25, 25, 25, 25});
  membership.MinHeight(278);
  membership.Background(mux::Media::SolidColorBrush(winrt::Microsoft::UI::ColorHelper::FromArgb(255, 32, 44, 51)));
  auto membership_content = muxc::StackPanel();
  membership_content.Spacing(16);
  const auto membership_text = [](double size, bool muted) {
    auto text = muxc::TextBlock();
    text.FontSize(size);
    text.TextWrapping(mux::TextWrapping::Wrap);
    text.Foreground(mux::Media::SolidColorBrush(muted
        ? winrt::Microsoft::UI::ColorHelper::FromArgb(255, 168, 183, 189)
        : winrt::Microsoft::UI::ColorHelper::FromArgb(255, 233, 239, 236)));
    return text;
  };
  state_->plan_heading = membership_text(12, true);
  state_->plan_text = membership_text(22, false);
  state_->remaining_heading = membership_text(12, true);
  state_->remaining_text = membership_text(28, false);
  state_->traffic_text = membership_text(12, true);
  state_->usage_progress = muxc::ProgressBar();
  state_->usage_progress.Maximum(1);
  state_->usage_progress.IsIndeterminate(false);
  state_->usage_progress.Foreground(mux::Media::SolidColorBrush(winrt::Microsoft::UI::ColorHelper::FromArgb(255, 171, 199, 214)));
  membership_content.Children().Append(state_->plan_heading);
  membership_content.Children().Append(state_->plan_text);
  membership_content.Children().Append(state_->remaining_heading);
  membership_content.Children().Append(state_->remaining_text);
  membership_content.Children().Append(state_->usage_progress);
  membership_content.Children().Append(state_->traffic_text);
  membership.Child(membership_content);
  muxc::Grid::SetRow(membership, 1);
  dashboard.Children().Append(membership);
  dashboard.SizeChanged([membership](const auto& sender, const auto& args) {
    const auto dashboard = sender.template as<muxc::Grid>();
    const bool wide = args.NewSize().Width >= 720;
    dashboard.ColumnDefinitions().GetAt(0).Width(mux::GridLengthHelper::FromValueAndType(wide ? 1.35 : 1, mux::GridUnitType::Star));
    dashboard.ColumnDefinitions().GetAt(1).Width(wide
        ? mux::GridLengthHelper::FromValueAndType(1, mux::GridUnitType::Star)
        : mux::GridLengthHelper::FromPixels(0));
    muxc::Grid::SetColumn(membership, wide ? 1 : 0);
    muxc::Grid::SetRow(membership, wide ? 0 : 1);
  });
  page.Children().Append(dashboard);

  auto rates = muxc::Border();
  rates.Padding(mux::Thickness{20, 16, 20, 16});
  rates.CornerRadius(mux::CornerRadius{8, 8, 8, 8});
  auto rate_content = muxc::StackPanel();
  rate_content.Spacing(12);
  state_->upload_text = muxc::TextBlock();
  state_->download_text = muxc::TextBlock();
  state_->upload_text.TextWrapping(mux::TextWrapping::Wrap);
  state_->download_text.TextWrapping(mux::TextWrapping::Wrap);
  rate_content.Children().Append(state_->upload_text);
  rate_content.Children().Append(state_->download_text);
  rates.Child(rate_content);
  page.Children().Append(rates);

  auto routes = muxc::Border();
  routes.Padding(mux::Thickness{20, 20, 20, 20});
  routes.CornerRadius(mux::CornerRadius{8, 8, 8, 8});
  auto route_content = muxc::StackPanel();
  route_content.Spacing(14);
  state_->route_heading = muxc::TextBlock();
  state_->route_heading.FontSize(16);
  route_content.Children().Append(state_->route_heading);
  state_->mode_box = muxc::ComboBox();
  state_->mode_box.HorizontalAlignment(mux::HorizontalAlignment::Stretch);
  state_->mode_box.SelectionChanged([this](auto&&, auto&&) {
    if (state_->rendering) return;
    const auto index = state_->mode_box.SelectedIndex();
    if (index >= 0) EmitCommand("setMode", index == 0 ? "{\"mode\":\"rule\"}" : "{\"mode\":\"global\"}");
  });
  route_content.Children().Append(state_->mode_box);
  state_->return_route_box = muxc::ComboBox();
  state_->return_route_box.HorizontalAlignment(mux::HorizontalAlignment::Stretch);
  state_->return_route_box.Visibility(mux::Visibility::Collapsed);
  state_->return_route_box.SelectionChanged([this](auto&&, auto&&) {
    if (state_->rendering || !state_->pending_commands.empty()) return;
    const auto route = ParseReturnRoute(state_->snapshot);
    const auto index = state_->return_route_box.SelectedIndex();
    if (!route || !route->enabled || index < 0 || static_cast<size_t>(index) >= route->options.size()) return;
    EmitCommand("selectReturnRoute", "{\"optionId\":\"" + Utf8(route->options[static_cast<size_t>(index)].id) + "\"}");
  });
  route_content.Children().Append(state_->return_route_box);
  state_->server_list = muxc::ListView();
  state_->server_list.SelectionChanged([this](auto&&, const auto& args) {
    if (state_->rendering) return;
    const auto selected = args.AddedItems().Size() == 0 ? nullptr : args.AddedItems().GetAt(0).try_as<muxc::NavigationViewItem>();
    if (selected != nullptr && selected.Tag() != nullptr) {
      EmitCommand("selectServer", "{\"serverId\":\"" + EscapeJson(Utf8(winrt::unbox_value<winrt::hstring>(selected.Tag()))) + "\"}");
    }
  });
  route_content.Children().Append(state_->server_list);
  routes.Child(route_content);
  page.Children().Append(routes);

  auto scroll = muxc::ScrollViewer();
  scroll.HorizontalScrollBarVisibility(muxc::ScrollBarVisibility::Disabled);
  scroll.Content(page);
  muxc::Grid::SetColumn(scroll, 1);
  root.Children().Append(scroll);
  root.SizeChanged([rail, navigation = state_->navigation](auto&&, const auto& args) {
    const bool compact = args.NewSize().Width < 760;
    rail.Width(mux::GridLengthHelper::FromPixels(compact ? 56 : 210));
    navigation.PaneDisplayMode(compact ? muxc::NavigationViewPaneDisplayMode::LeftCompact : muxc::NavigationViewPaneDisplayMode::Left);
    navigation.IsPaneOpen(!compact);
  });
  const auto apply_palette = [this, hero, rates, routes] {
    const bool dark = state_->root.ActualTheme() == mux::ElementTheme::Dark;
    const auto ink = mux::Media::SolidColorBrush(dark
        ? winrt::Microsoft::UI::ColorHelper::FromArgb(255, 233, 239, 236)
        : winrt::Microsoft::UI::ColorHelper::FromArgb(255, 40, 54, 62));
    const auto paper = mux::Media::SolidColorBrush(dark
        ? winrt::Microsoft::UI::ColorHelper::FromArgb(255, 21, 30, 36)
        : winrt::Microsoft::UI::ColorHelper::FromArgb(255, 243, 244, 239));
    const auto surface = mux::Media::SolidColorBrush(dark
        ? winrt::Microsoft::UI::ColorHelper::FromArgb(255, 32, 44, 51)
        : winrt::Microsoft::UI::ColorHelper::FromArgb(255, 255, 253, 249));
    state_->root.Background(paper);
    state_->navigation.Background(paper);
    hero.Background(surface);
    rates.Background(surface);
    routes.Background(surface);
    for (const auto& text : {state_->state_text, state_->connect_label, state_->route_text,
                             state_->route_heading, state_->upload_text, state_->download_text}) text.Foreground(ink);
  };
  root.ActualThemeChanged([apply_palette](auto&&, auto&&) { apply_palette(); });
  apply_palette();
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
  state_->pending_commands.clear();
  state_->servers_fingerprint.clear();
  state_->connection_command_pending = false;
  state_->plan_text.Text(L"");
  state_->remaining_text.Text(L"");
  state_->route_text.Text(L"");
  state_->usage_progress.Visibility(mux::Visibility::Collapsed);
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
  const auto action_label = connection == L"connected" ? Label(labels, L"disconnect") : Label(labels, L"connect");
  state_->connect_label.Text(safe_mode ? Label(labels, L"safeMode") : action_label);
  mux::Automation::AutomationProperties::SetName(state_->connect_button, action_label);
  const bool dark = state_->root.ActualTheme() == mux::ElementTheme::Dark;
  state_->connect_button.Background(mux::Media::SolidColorBrush(connection == L"connected"
      ? winrt::Microsoft::UI::ColorHelper::FromArgb(255, 80, 106, 122)
      : dark ? winrt::Microsoft::UI::ColorHelper::FromArgb(255, 52, 73, 84)
             : winrt::Microsoft::UI::ColorHelper::FromArgb(255, 220, 231, 237)));
  state_->connect_button.Foreground(mux::Media::SolidColorBrush(connection == L"connected" || dark
      ? winrt::Microsoft::UI::ColorHelper::FromArgb(255, 233, 239, 236)
      : winrt::Microsoft::UI::ColorHelper::FromArgb(255, 80, 106, 122)));
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
  const auto return_route = ParseReturnRoute(state_->snapshot);
  state_->return_route_box.Visibility(return_route ? mux::Visibility::Visible : mux::Visibility::Collapsed);
  state_->return_route_box.Items().Clear();
  state_->return_route_box.SelectedIndex(-1);
  if (return_route) {
    state_->return_route_box.Header(winrt::box_value(return_route->title));
    winrt::Microsoft::UI::Xaml::Automation::AutomationProperties::SetName(state_->return_route_box, return_route->title);
    int32_t selected_index = -1;
    for (size_t index = 0; index < return_route->options.size(); ++index) {
      const auto& option = return_route->options[index];
      state_->return_route_box.Items().Append(winrt::box_value(option.label));
      if (option.id == return_route->selected_id) selected_index = static_cast<int32_t>(index);
    }
    state_->return_route_box.SelectedIndex(selected_index);
    state_->return_route_box.IsEnabled(return_route->enabled && state_->pending_commands.empty());
  }
  state_->mode_box.IsEnabled(session == L"signedIn" && !safe_mode);
  state_->server_list.IsEnabled(session == L"signedIn" && !safe_mode);

  const auto plan = Text(state_->snapshot, L"planName");
  state_->plan_heading.Text(Label(labels, L"currentPlan"));
  state_->remaining_heading.Text(Label(labels, L"trafficRemaining"));
  state_->route_heading.Text(Label(labels, L"selectServer"));
  state_->plan_text.Text(plan.empty() ? Label(labels, L"noPlan") : plan);
  const auto locale = Text(state_->snapshot, L"locale", L"en");
  const auto used = OptionalInteger(usage, L"usedBytes");
  const auto total = OptionalInteger(usage, L"totalBytes");
  state_->remaining_text.Text(used && total
      ? FormatBytes((std::max)(int64_t{0}, *total - *used), false, locale) : L"\u2014");
  state_->traffic_text.Text(Label(labels, L"trafficUsed") + L" \u00B7 " +
      FormatBytes(used, false, locale) + L" / " + FormatBytes(total, false, locale));
  state_->usage_progress.Visibility(used && total && *total > 0 ? mux::Visibility::Visible : mux::Visibility::Collapsed);
  state_->usage_progress.Value(used && total && *total > 0
      ? (std::min)(1.0, static_cast<double>(*used) / static_cast<double>(*total)) : 0);
  state_->upload_text.Text(Label(labels, L"upload") + L": " +
                           FormatBytes(OptionalInteger(traffic, L"uploadBps"), true, locale));
  state_->download_text.Text(Label(labels, L"download") + L": " +
                             FormatBytes(OptionalInteger(traffic, L"downloadBps"), true, locale));

  winrt::hstring selected_route = L"\u2014";
  for (const auto& value : servers) {
    const auto server = value.GetObject();
    if (Text(server, L"id") == Text(state_->snapshot, L"selectedServerId")) {
      selected_route = Text(server, L"name");
      const auto latency = OptionalInteger(server, L"latencyMs");
      auto languages = winrt::single_threaded_vector<winrt::hstring>();
      languages.Append(locale);
      auto formatter = winrt::Windows::Globalization::NumberFormatting::DecimalFormatter(
          languages, winrt::Windows::Globalization::GeographicRegion().Code());
      formatter.FractionDigits(0);
      selected_route = selected_route + L" \u00B7 " + (latency ? formatter.FormatInt(*latency) + L" ms" : L"\u2014");
      break;
    }
  }
  state_->route_text.Text(selected_route);
  const auto servers_fingerprint = Utf8(servers.Stringify());
  if (servers_fingerprint != state_->servers_fingerprint) {
    state_->server_list.Items().Clear();
    const auto selected_server = Text(state_->snapshot, L"selectedServerId");
    for (const auto& value : servers) {
      const auto server = value.GetObject();
      auto item = muxc::NavigationViewItem();
      item.Tag(winrt::box_value(Text(server, L"id")));
      item.Content(winrt::box_value(Text(server, L"name")));
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
    item.Content(winrt::box_value(Label(labels, winrt::unbox_value<winrt::hstring>(item.Tag()).c_str())));
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
  state_->pending_commands.insert(Utf8(id));
  state_->return_route_box.IsEnabled(false);
  on_command_("{\"schemaVersion\":1,\"id\":\"" + EscapeJson(Utf8(id)) +
              "\",\"accountGeneration\":" + std::to_string(state_->account_generation) +
              ",\"action\":\"" + action + "\",\"payload\":" + payload + "}");
}

void WinUiSurface::CompleteCommand(const std::string& command_json) {
  try {
    const auto command = wdj::JsonObject::Parse(winrt::to_hstring(command_json));
    if (Integer(command, L"accountGeneration", -1) != state_->account_generation) return;
    state_->pending_commands.erase(Utf8(Text(command, L"id")));
    const auto route = ParseReturnRoute(state_->snapshot);
    state_->return_route_box.IsEnabled(route && route->enabled && state_->pending_commands.empty());
  } catch (const winrt::hresult_error&) {
    return;
  }
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
