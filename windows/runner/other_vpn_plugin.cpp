#include "other_vpn_plugin.h"

// Winsock 2 has to come before windows.h, which otherwise pulls in the old
// winsock.h that iphlpapi.h then collides with.
#include <winsock2.h>
#include <windows.h>
#include <iphlpapi.h>
#include <ras.h>
#include <raserror.h>
#include <shellapi.h>

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <array>
#include <cwchar>
#include <memory>
#include <string>
#include <vector>

#pragma comment(lib, "iphlpapi.lib")
#pragma comment(lib, "rasapi32.lib")

namespace {

// Where Windows keeps its VPN connections.
constexpr wchar_t kVpnSettingsUri[] = L"ms-settings:network-vpn";

// ShellExecute reports success with any value above this.
constexpr INT_PTR kShellExecuteFailureCeiling = 32;

// Driver names that give a VPN away when its adapter reports itself as
// ordinary Ethernet, as the TAP drivers OpenVPN and others ship do.
constexpr std::array<const wchar_t*, 4> kVpnDriverNames = {
    L"TAP-Windows", L"OpenVPN", L"WireGuard", L"Wintun"};

// The Wintun adapter Begzar's own tunnel helper opens in tunnel mode. The
// helper names it (TunnelAdapterName in the engine's physif package), so a
// rename changes both sides or neither.
constexpr wchar_t kOwnAdapterName[] = L"Begzar";

// The VPN profiles from Windows' Settings that are connected, the one kind of
// VPN Windows lets another app hang up.
//
// RAS also runs PPPoE broadband, dial-up and mobile modems, which are the
// user's own internet rather than a VPN. Only the device type says which is
// which, so a connection counts only when it names itself a VPN: anything
// else, including a type Windows adds later, is left alone, because hanging
// it up would cut the user off.
std::vector<HRASCONN> ActiveVpnConnections() {
  DWORD bytes = 0;
  DWORD count = 0;
  // Asked with no buffer first, which reports the size it needs. No
  // connections at all answers success with a count of zero.
  if (RasEnumConnectionsW(nullptr, &bytes, &count) != ERROR_BUFFER_TOO_SMALL ||
      count == 0) {
    return {};
  }

  std::vector<RASCONNW> connections(count);
  connections[0].dwSize = sizeof(RASCONNW);
  bytes = static_cast<DWORD>(connections.size() * sizeof(RASCONNW));
  if (RasEnumConnectionsW(connections.data(), &bytes, &count) !=
      ERROR_SUCCESS) {
    return {};
  }

  std::vector<HRASCONN> handles;
  for (DWORD index = 0; index < count; ++index) {
    if (_wcsicmp(connections[index].szDeviceType, RASDT_Vpn) == 0) {
      handles.push_back(connections[index].hrasconn);
    }
  }
  return handles;
}

bool NamesVpnDriver(const wchar_t* description) {
  if (description == nullptr) return false;
  const std::wstring text(description);
  for (const wchar_t* name : kVpnDriverNames) {
    if (text.find(name) != std::wstring::npos) return true;
  }
  return false;
}

// Whether an adapter that is up carries a VPN: the virtual type Wintun-based
// VPNs use, or a driver named for what it is.
//
// Only a sign that names a VPN counts, because a false alarm costs more than a
// miss. So the broad types are left out. Point-to-point is also every USB
// modem, PPPoE link and dial-up, and Windows' own VPN profiles are found
// through RAS instead. Tunnel-type adapters cover Teredo and 6to4, which sit
// on most machines doing nothing.
//
// Begzar's own adapter is left out by name. It is a Wintun adapter like any
// other, and it can still be up for a moment after a disconnect while the
// helper takes it down, which would refuse the next connect.
bool IsVpnAdapter(const IP_ADAPTER_ADDRESSES& adapter) {
  if (adapter.OperStatus != IfOperStatusUp) return false;
  if (adapter.FriendlyName != nullptr &&
      std::wstring(adapter.FriendlyName) == kOwnAdapterName) {
    return false;
  }
  if (adapter.IfType == IF_TYPE_PROP_VIRTUAL) return true;
  return NamesVpnDriver(adapter.Description);
}

bool AnyVpnAdapterUp() {
  constexpr ULONG kFlags = GAA_FLAG_SKIP_ANYCAST | GAA_FLAG_SKIP_MULTICAST |
                           GAA_FLAG_SKIP_DNS_SERVER;
  ULONG size = 0;
  if (GetAdaptersAddresses(AF_UNSPEC, kFlags, nullptr, nullptr, &size) !=
      ERROR_BUFFER_OVERFLOW) {
    return false;
  }

  std::vector<unsigned char> buffer(size);
  auto* adapters = reinterpret_cast<IP_ADAPTER_ADDRESSES*>(buffer.data());
  if (GetAdaptersAddresses(AF_UNSPEC, kFlags, nullptr, adapters, &size) !=
      NO_ERROR) {
    return false;
  }

  for (auto* adapter = adapters; adapter != nullptr; adapter = adapter->Next) {
    if (IsVpnAdapter(*adapter)) return true;
  }
  return false;
}

// Whether a VPN other than Begzar's own is up. The proxy modes run no adapter,
// and tunnel mode's adapter is ruled out by name in IsVpnAdapter, so anything
// found here belongs to something else.
bool IsVpnOn() { return !ActiveVpnConnections().empty() || AnyVpnAdapterUp(); }

// Hangs up Windows' own VPN profiles. A third-party VPN's adapter is
// untouched, and the check afterwards is what tells the user so.
void TurnOffVpn() {
  for (HRASCONN connection : ActiveVpnConnections()) {
    RasHangUpW(connection);
  }
}

bool OpenVpnSettings() {
  const auto opened = reinterpret_cast<INT_PTR>(ShellExecuteW(
      nullptr, L"open", kVpnSettingsUri, nullptr, nullptr, SW_SHOWNORMAL));
  return opened > kShellExecuteFailureCeiling;
}

}  // namespace

void RegisterOtherVpnPlugin(flutter::BinaryMessenger* messenger) {
  const auto channel =
      std::make_shared<flutter::MethodChannel<flutter::EncodableValue>>(
          messenger, "cloud.begzar.begzar/other_vpn",
          &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [channel](const flutter::MethodCall<flutter::EncodableValue>& call,
                std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                    result) {
        const auto& method = call.method_name();
        if (method == "isVpnOn") {
          result->Success(flutter::EncodableValue(IsVpnOn()));
        } else if (method == "turnOffVpn") {
          TurnOffVpn();
          result->Success();
        } else if (method == "openVpnSettings") {
          result->Success(flutter::EncodableValue(OpenVpnSettings()));
        } else {
          result->NotImplemented();
        }
      });
}
