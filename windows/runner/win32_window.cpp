#include "win32_window.h"

#include <dwmapi.h>
#include <flutter_windows.h>

#include "resource.h"

namespace {

/// Window attribute that enables dark mode window decorations.
///
/// Redefined in case the developer's machine has a Windows SDK older than
/// version 10.0.22000.0.
/// See: https://docs.microsoft.com/windows/win32/api/dwmapi/ne-dwmapi-dwmwindowattribute
#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE
#define DWMWA_USE_IMMERSIVE_DARK_MODE 20
#endif

constexpr const wchar_t kWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";

/// Registry key for app theme preference.
///
/// A value of 0 indicates apps should use dark mode. A non-zero or missing
/// value indicates apps should use light mode.
constexpr const wchar_t kGetPreferredBrightnessRegKey[] =
  L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize";
constexpr const wchar_t kGetPreferredBrightnessRegValue[] = L"AppsUseLightTheme";

// The number of Win32Window objects that currently exist.
static int g_active_window_count = 0;

using EnableNonClientDpiScaling = BOOL __stdcall(HWND hwnd);

// Scale helper to convert logical scaler values to physical using passed in
// scale factor
int Scale(int source, double scale_factor) {
  return static_cast<int>(source * scale_factor);
}

// Dynamically loads the |EnableNonClientDpiScaling| from the User32 module.
// This API is only needed for PerMonitor V1 awareness mode.
void EnableFullDpiSupportIfAvailable(HWND hwnd) {
  HMODULE user32_module = LoadLibraryA("User32.dll");
  if (!user32_module) {
    return;
  }
  auto enable_non_client_dpi_scaling =
      reinterpret_cast<EnableNonClientDpiScaling*>(
          GetProcAddress(user32_module, "EnableNonClientDpiScaling"));
  if (enable_non_client_dpi_scaling != nullptr) {
    enable_non_client_dpi_scaling(hwnd);
  }
  FreeLibrary(user32_module);
}

}  // namespace

// Manages the Win32Window's window class registration.
class WindowClassRegistrar {
 public:
  ~WindowClassRegistrar() = default;

  // Returns the singleton registrar instance.
  static WindowClassRegistrar* GetInstance() {
    if (!instance_) {
      instance_ = new WindowClassRegistrar();
    }
    return instance_;
  }

  // Returns the name of the window class, registering the class if it hasn't
  // previously been registered.
  const wchar_t* GetWindowClass();

  // Unregisters the window class. Should only be called if there are no
  // instances of the window.
  void UnregisterWindowClass();

 private:
  WindowClassRegistrar() = default;

  static WindowClassRegistrar* instance_;

  bool class_registered_ = false;
};

WindowClassRegistrar* WindowClassRegistrar::instance_ = nullptr;

const wchar_t* WindowClassRegistrar::GetWindowClass() {
  if (!class_registered_) {
    WNDCLASS window_class{};
    window_class.hCursor = LoadCursor(nullptr, IDC_ARROW);
    window_class.lpszClassName = kWindowClassName;
    window_class.style = CS_HREDRAW | CS_VREDRAW;
    window_class.cbClsExtra = 0;
    window_class.cbWndExtra = 0;
    window_class.hInstance = GetModuleHandle(nullptr);
    window_class.hIcon =
        LoadIcon(window_class.hInstance, MAKEINTRESOURCE(IDI_APP_ICON));
    window_class.hbrBackground = 0;
    window_class.lpszMenuName = nullptr;
    window_class.lpfnWndProc = Win32Window::WndProc;
    RegisterClass(&window_class);
    class_registered_ = true;
  }
  return kWindowClassName;
}

void WindowClassRegistrar::UnregisterWindowClass() {
  UnregisterClass(kWindowClassName, nullptr);
  class_registered_ = false;
}

Win32Window::Win32Window() {
  ++g_active_window_count;
}

Win32Window::~Win32Window() {
  --g_active_window_count;
  Destroy();
}

bool Win32Window::Create(const std::wstring& title,
                         const Point& origin,
                         const Size& size) {
  Destroy();

  const wchar_t* window_class =
      WindowClassRegistrar::GetInstance()->GetWindowClass();

  const POINT target_point = {static_cast<LONG>(origin.x),
                              static_cast<LONG>(origin.y)};
  HMONITOR monitor = MonitorFromPoint(target_point, MONITOR_DEFAULTTONEAREST);
  UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
  double scale_factor = dpi / 96.0;

  // Resizable within ±30% of the design client size, by drag only. A maximize
  // box would offer to fill the screen and then land on +30%, because
  // WM_GETMINMAXINFO clamps it like any other sizing — a button that visibly
  // does not do what it says. WS_OVERLAPPEDWINDOW minus that box.
  const DWORD window_style =
      WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX | WS_THICKFRAME;
  base_client_width_ = size.width;
  base_client_height_ = size.height;

  // |size| is the desired client area (logical pixels); expand for chrome.
  RECT frame = {0, 0, Scale(size.width, scale_factor),
                Scale(size.height, scale_factor)};
  ::AdjustWindowRect(&frame, window_style, FALSE);

  int frame_width = frame.right - frame.left;
  int frame_height = frame.bottom - frame.top;
  int left = Scale(origin.x, scale_factor);
  int top = Scale(origin.y, scale_factor);

  // The design is 852pt tall, and this asked the monitor for its DPI but never
  // for how much of it the user can reach. On a 1366x768 laptop that opens a
  // window roughly 160px past the bottom of the screen, and the part that goes
  // over the edge is the nav bar — the only way to Settings and to the
  // account. The same arithmetic overflows a 1080p panel at 125%, which is
  // what Windows itself recommends on most 15-inch laptops.
  //
  // The frame is folded into the work area, which is the monitor minus the
  // taskbar, and then moved to sit inside it: an origin fixed at (10, 10) is
  // already most of the way off a short screen. Width is folded on the same
  // rule and will not move — 393pt plus chrome is narrower than any display
  // this runs on — but the axis is not special, and a rule that reads the
  // monitor on one side and assumes on the other is the bug we just had.
  MONITORINFO monitor_info = {};
  monitor_info.cbSize = sizeof(MONITORINFO);
  if (::GetMonitorInfo(monitor, &monitor_info)) {
    const RECT& work = monitor_info.rcWork;
    const int work_width = work.right - work.left;
    const int work_height = work.bottom - work.top;

    if (frame_width > work_width) {
      frame_width = work_width;
    }
    if (frame_height > work_height) {
      frame_height = work_height;
    }
    if (left + frame_width > work.right) {
      left = work.right - frame_width;
    }
    if (top + frame_height > work.bottom) {
      top = work.bottom - frame_height;
    }
    if (left < work.left) {
      left = work.left;
    }
    if (top < work.top) {
      top = work.top;
    }
  }

  HWND window = CreateWindow(
      window_class, title.c_str(), window_style,
      left, top, frame_width, frame_height,
      nullptr, nullptr, GetModuleHandle(nullptr), this);

  if (!window) {
    return false;
  }

  UpdateTheme(window);

  return OnCreate();
}

bool Win32Window::Show() {
  return ShowWindow(window_handle_, SW_SHOWNORMAL);
}

// static
LRESULT CALLBACK Win32Window::WndProc(HWND const window,
                                      UINT const message,
                                      WPARAM const wparam,
                                      LPARAM const lparam) noexcept {
  if (message == WM_NCCREATE) {
    auto window_struct = reinterpret_cast<CREATESTRUCT*>(lparam);
    SetWindowLongPtr(window, GWLP_USERDATA,
                     reinterpret_cast<LONG_PTR>(window_struct->lpCreateParams));

    auto that = static_cast<Win32Window*>(window_struct->lpCreateParams);
    EnableFullDpiSupportIfAvailable(window);
    that->window_handle_ = window;
  } else if (Win32Window* that = GetThisFromHandle(window)) {
    return that->MessageHandler(window, message, wparam, lparam);
  }

  return DefWindowProc(window, message, wparam, lparam);
}

LRESULT
Win32Window::MessageHandler(HWND hwnd,
                            UINT const message,
                            WPARAM const wparam,
                            LPARAM const lparam) noexcept {
  switch (message) {
    case WM_DESTROY:
      window_handle_ = nullptr;
      Destroy();
      if (quit_on_close_) {
        PostQuitMessage(0);
      }
      return 0;

    case WM_DPICHANGED: {
      auto newRectSize = reinterpret_cast<RECT*>(lparam);
      LONG newWidth = newRectSize->right - newRectSize->left;
      LONG newHeight = newRectSize->bottom - newRectSize->top;

      SetWindowPos(hwnd, nullptr, newRectSize->left, newRectSize->top, newWidth,
                   newHeight, SWP_NOZORDER | SWP_NOACTIVATE);

      return 0;
    }
    case WM_SIZE: {
      RECT rect = GetClientArea();
      if (child_content_ != nullptr) {
        // Size and position the child window.
        MoveWindow(child_content_, rect.left, rect.top, rect.right - rect.left,
                   rect.bottom - rect.top, TRUE);
      }
      return 0;
    }

    case WM_GETMINMAXINFO: {
      if (base_client_width_ == 0 || base_client_height_ == 0) {
        break;
      }
      auto* info = reinterpret_cast<MINMAXINFO*>(lparam);
      const DWORD style = static_cast<DWORD>(GetWindowLongPtr(hwnd, GWL_STYLE));
      const DWORD ex_style =
          static_cast<DWORD>(GetWindowLongPtr(hwnd, GWL_EXSTYLE));
      const UINT dpi = ::GetDpiForWindow(hwnd);
      const double scale_factor = dpi / 96.0;

      const auto track_size_for_client = [&](unsigned int client_w,
                                             unsigned int client_h) -> SIZE {
        RECT frame = {0, 0, Scale(static_cast<int>(client_w), scale_factor),
                      Scale(static_cast<int>(client_h), scale_factor)};
        ::AdjustWindowRectExForDpi(&frame, style, FALSE, ex_style, dpi);
        SIZE out{};
        out.cx = frame.right - frame.left;
        out.cy = frame.bottom - frame.top;
        return out;
      };

      constexpr double kRange = 0.30;
      const unsigned int min_w = static_cast<unsigned int>(
          base_client_width_ * (1.0 - kRange) + 0.5);
      const unsigned int min_h = static_cast<unsigned int>(
          base_client_height_ * (1.0 - kRange) + 0.5);
      const unsigned int max_w = static_cast<unsigned int>(
          base_client_width_ * (1.0 + kRange) + 0.5);
      const unsigned int max_h = static_cast<unsigned int>(
          base_client_height_ * (1.0 + kRange) + 0.5);

      const SIZE min_track = track_size_for_client(min_w, min_h);
      const SIZE max_track = track_size_for_client(max_w, max_h);
      info->ptMinTrackSize.x = min_track.cx;
      info->ptMinTrackSize.y = min_track.cy;
      info->ptMaxTrackSize.x = max_track.cx;
      info->ptMaxTrackSize.y = max_track.cy;

      // The floor is a design preference; the screen is not. Where a panel is
      // too short for even 70% of the design height, a minimum that has not
      // heard of the work area pulls the window straight back over the bottom
      // edge — including the one `Create` just folded to fit, because this
      // clamps a size the program asks for exactly as it clamps a drag. So the
      // floor yields: a window whose every part can be reached beats one that
      // keeps its proportions off-screen.
      MONITORINFO monitor_info = {};
      monitor_info.cbSize = sizeof(MONITORINFO);
      HMONITOR monitor = ::MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
      if (::GetMonitorInfo(monitor, &monitor_info)) {
        const RECT& work = monitor_info.rcWork;
        const LONG work_width = work.right - work.left;
        const LONG work_height = work.bottom - work.top;
        if (info->ptMinTrackSize.x > work_width) {
          info->ptMinTrackSize.x = work_width;
        }
        if (info->ptMinTrackSize.y > work_height) {
          info->ptMinTrackSize.y = work_height;
        }
      }
      return 0;
    }

    case WM_ACTIVATE:
      if (child_content_ != nullptr) {
        SetFocus(child_content_);
      }
      return 0;

    case WM_DWMCOLORIZATIONCOLORCHANGED:
      UpdateTheme(hwnd);
      return 0;
  }

  return DefWindowProc(window_handle_, message, wparam, lparam);
}

void Win32Window::Destroy() {
  OnDestroy();

  if (window_handle_) {
    DestroyWindow(window_handle_);
    window_handle_ = nullptr;
  }
  if (g_active_window_count == 0) {
    WindowClassRegistrar::GetInstance()->UnregisterWindowClass();
  }
}

Win32Window* Win32Window::GetThisFromHandle(HWND const window) noexcept {
  return reinterpret_cast<Win32Window*>(
      GetWindowLongPtr(window, GWLP_USERDATA));
}

void Win32Window::SetChildContent(HWND content) {
  child_content_ = content;
  SetParent(content, window_handle_);
  RECT frame = GetClientArea();

  MoveWindow(content, frame.left, frame.top, frame.right - frame.left,
             frame.bottom - frame.top, true);

  SetFocus(child_content_);
}

RECT Win32Window::GetClientArea() {
  RECT frame;
  GetClientRect(window_handle_, &frame);
  return frame;
}

HWND Win32Window::GetHandle() {
  return window_handle_;
}

void Win32Window::SetQuitOnClose(bool quit_on_close) {
  quit_on_close_ = quit_on_close;
}

bool Win32Window::OnCreate() {
  // No-op; provided for subclasses.
  return true;
}

void Win32Window::OnDestroy() {
  // No-op; provided for subclasses.
}

void Win32Window::UpdateTheme(HWND const window) {
  DWORD light_mode;
  DWORD light_mode_size = sizeof(light_mode);
  LSTATUS result = RegGetValue(HKEY_CURRENT_USER, kGetPreferredBrightnessRegKey,
                               kGetPreferredBrightnessRegValue,
                               RRF_RT_REG_DWORD, nullptr, &light_mode,
                               &light_mode_size);

  if (result == ERROR_SUCCESS) {
    BOOL enable_dark_mode = light_mode == 0;
    DwmSetWindowAttribute(window, DWMWA_USE_IMMERSIVE_DARK_MODE,
                          &enable_dark_mode, sizeof(enable_dark_mode));
  }
}
