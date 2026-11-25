#ifndef RUNNER_TUNNEL_HELPER_PLUGIN_H_
#define RUNNER_TUNNEL_HELPER_PLUGIN_H_

#include <flutter/binary_messenger.h>
#include <windows.h>

// Registers the method channel "begzar/tunnel_helper". Its "launch" method
// starts begzar-tun.exe, from beside begzar.exe, through the Windows admin
// prompt, with the UTF-8 string in the "parameters" argument as its command
// line. It answers "started", "declined", "missing" or "failed".
//
// `window` is the app's main window, which owns the admin prompt.
void RegisterTunnelHelperPlugin(flutter::BinaryMessenger* messenger,
                                HWND window);

#endif  // RUNNER_TUNNEL_HELPER_PLUGIN_H_
