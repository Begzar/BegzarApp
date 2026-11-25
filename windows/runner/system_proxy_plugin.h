#ifndef RUNNER_SYSTEM_PROXY_PLUGIN_H_
#define RUNNER_SYSTEM_PROXY_PLUGIN_H_

#include <flutter/binary_messenger.h>

// Registers MethodChannel "begzar/system_proxy" for WinINET proxy control.
void RegisterSystemProxyPlugin(flutter::BinaryMessenger* messenger);

// Best-effort restore of system proxy (e.g. on process exit).
void ClearSystemProxyIfApplied();

#endif  // RUNNER_SYSTEM_PROXY_PLUGIN_H_
