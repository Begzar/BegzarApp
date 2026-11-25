#ifndef RUNNER_OTHER_VPN_PLUGIN_H_
#define RUNNER_OTHER_VPN_PLUGIN_H_

#include <flutter/binary_messenger.h>

// Registers MethodChannel "cloud.begzar.begzar/other_vpn": whether another VPN
// is on, hanging up the ones Windows itself runs, and opening VPN settings.
void RegisterOtherVpnPlugin(flutter::BinaryMessenger* messenger);

#endif  // RUNNER_OTHER_VPN_PLUGIN_H_
