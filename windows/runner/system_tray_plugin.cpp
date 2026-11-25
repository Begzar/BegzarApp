#include "system_tray_plugin.h"

#include <shellapi.h>

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>

#include "resource.h"

namespace {

constexpr UINT kTrayIconId = 1;
constexpr UINT kTrayCallbackMessage = WM_APP + 1;
constexpr UINT kMenuDisconnect = 1001;
constexpr UINT kMenuExit = 1002;

HWND g_hwnd = nullptr;
NOTIFYICONDATAW g_nid = {};
bool g_tray_added = false;
bool g_allow_quit = false;
std::shared_ptr<flutter::MethodChannel<flutter::EncodableValue>> g_channel;

void EnsureTrayIcon() {
  if (g_tray_added || g_hwnd == nullptr) {
    return;
  }

  ZeroMemory(&g_nid, sizeof(g_nid));
  g_nid.cbSize = sizeof(g_nid);
  g_nid.hWnd = g_hwnd;
  g_nid.uID = kTrayIconId;
  g_nid.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP;
  g_nid.uCallbackMessage = kTrayCallbackMessage;
  g_nid.hIcon = LoadIcon(GetModuleHandle(nullptr), MAKEINTRESOURCE(IDI_APP_ICON));
  wcsncpy_s(g_nid.szTip, L"Begzar", _TRUNCATE);

  if (Shell_NotifyIconW(NIM_ADD, &g_nid)) {
    g_nid.uVersion = NOTIFYICON_VERSION_4;
    Shell_NotifyIconW(NIM_SETVERSION, &g_nid);
    g_tray_added = true;
  }
}

void RemoveTrayIcon() {
  if (!g_tray_added) {
    return;
  }
  Shell_NotifyIconW(NIM_DELETE, &g_nid);
  g_tray_added = false;
}

// Quits for real: destroying the window runs FlutterWindow::OnDestroy, which
// puts the system proxy back before the process ends.
void Quit() {
  g_allow_quit = true;
  RemoveTrayIcon();
  DestroyWindow(g_hwnd);
}

void ShowContextMenu() {
  if (g_hwnd == nullptr) {
    return;
  }

  POINT pt;
  GetCursorPos(&pt);

  HMENU menu = CreatePopupMenu();
  // Connection action only — no Connect from tray.
  AppendMenuW(menu, MF_STRING, kMenuDisconnect, L"Disconnect");
  // Exit is required so the app can fully quit (close button only hides).
  AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
  AppendMenuW(menu, MF_STRING, kMenuExit, L"Exit");

  SetForegroundWindow(g_hwnd);
  const UINT cmd = TrackPopupMenu(
      menu,
      TPM_RETURNCMD | TPM_NONOTIFY | TPM_RIGHTBUTTON | TPM_BOTTOMALIGN |
          TPM_RIGHTALIGN,
      pt.x, pt.y, 0, g_hwnd, nullptr);
  DestroyMenu(menu);

  if (cmd == kMenuDisconnect) {
    if (g_channel) {
      g_channel->InvokeMethod("disconnectRequested", nullptr);
    }
  } else if (cmd == kMenuExit) {
    Quit();
  }
}

}  // namespace

void SystemTrayHideToTray() {
  if (g_hwnd == nullptr) {
    return;
  }
  EnsureTrayIcon();
  ShowWindow(g_hwnd, SW_HIDE);
}

void SystemTrayShowWindow() {
  if (g_hwnd == nullptr) {
    return;
  }
  ShowWindow(g_hwnd, SW_SHOW);
  ShowWindow(g_hwnd, SW_RESTORE);
  SetForegroundWindow(g_hwnd);
}

void SystemTrayCleanup() {
  RemoveTrayIcon();
  g_hwnd = nullptr;
  g_channel.reset();
}

bool SystemTrayHandleMessage(HWND hwnd, UINT message, WPARAM wparam,
                             LPARAM lparam, LRESULT* result) {
  if (message == WM_CLOSE && !g_allow_quit) {
    SystemTrayHideToTray();
    *result = 0;
    return true;
  }

  // Windows ends the session this way at logoff and shutdown, and the
  // installer's Restart Manager does the same to free the files it replaces.
  // None of them can be answered by hiding to tray, so the app quits as the
  // tray's Exit does.
  if (message == WM_ENDSESSION && wparam == TRUE && g_hwnd != nullptr) {
    Quit();
    *result = 0;
    return true;
  }

  if (message == kTrayCallbackMessage) {
    const UINT tray_msg = LOWORD(lparam);
    if (tray_msg == WM_LBUTTONUP || tray_msg == NIN_SELECT ||
        tray_msg == NIN_KEYSELECT) {
      SystemTrayShowWindow();
      *result = 0;
      return true;
    }
    if (tray_msg == WM_RBUTTONUP || tray_msg == WM_CONTEXTMENU) {
      ShowContextMenu();
      *result = 0;
      return true;
    }
  }

  return false;
}

void RegisterSystemTrayPlugin(flutter::BinaryMessenger* messenger, HWND hwnd) {
  g_hwnd = hwnd;
  g_allow_quit = false;

  // Outbound only: the channel carries the tray's Disconnect click up to Dart
  // and takes nothing back. Showing, hiding and quitting are all driven from
  // window messages and the tray menu below, so there is no inbound call for a
  // handler to answer.
  g_channel =
      std::make_shared<flutter::MethodChannel<flutter::EncodableValue>>(
          messenger, "begzar/system_tray",
          &flutter::StandardMethodCodec::GetInstance());
}
