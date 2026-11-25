#ifndef RUNNER_SYSTEM_TRAY_PLUGIN_H_
#define RUNNER_SYSTEM_TRAY_PLUGIN_H_

#include <flutter/binary_messenger.h>
#include <windows.h>

// System tray: close hides to tray; menu has Disconnect (+ Exit to quit).
void RegisterSystemTrayPlugin(flutter::BinaryMessenger* messenger, HWND hwnd);

// Handle tray-related window messages. Returns true if handled.
bool SystemTrayHandleMessage(HWND hwnd, UINT message, WPARAM wparam,
                             LPARAM lparam, LRESULT* result);

// Hide main window and keep running in tray.
void SystemTrayHideToTray();

// Show and focus the main window.
void SystemTrayShowWindow();

// Remove tray icon (e.g. on destroy).
void SystemTrayCleanup();

#endif  // RUNNER_SYSTEM_TRAY_PLUGIN_H_
