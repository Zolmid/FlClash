#ifndef ZOLNIT_NATIVE_UI_WINUI_SURFACE_H_
#define ZOLNIT_NATIVE_UI_WINUI_SURFACE_H_

#include <windows.h>

#include <functional>
#include <string>

namespace zolnit {

class WinUiSurface {
 public:
  using CommandCallback = std::function<void(const std::string&)>;

  WinUiSurface(HWND parent, CommandCallback on_command);
  ~WinUiSurface();

  WinUiSurface(const WinUiSurface&) = delete;
  WinUiSurface& operator=(const WinUiSurface&) = delete;

  bool Initialize();
  bool PublishSnapshot(const std::string& snapshot_json);
  bool SetBounds(double x, double y, double width, double height,
                 double device_pixel_ratio);
  void Show();
  void Hide();
  bool ProcessMessage(HWND window, UINT message, WPARAM wparam, LPARAM lparam);

 private:
  struct State;

  void BuildView();
  void Render();
  void EmitCommand(const std::string& action, const std::string& payload);
  void ClearAccountState();
  void ReleaseRuntime();

  HWND parent_ = nullptr;
  CommandCallback on_command_;
  State* state_ = nullptr;
};

}  // namespace zolnit

#endif  // ZOLNIT_NATIVE_UI_WINUI_SURFACE_H_
