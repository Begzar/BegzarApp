#include "system_proxy_plugin.h"

#include <windows.h>
#include <wininet.h>

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>

#include "utils.h"

#pragma comment(lib, "wininet.lib")

namespace {

constexpr wchar_t kInternetSettingsKey[] =
    L"Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings";

// Where the snapshot below outlives the process that took it.
//
// The globals that follow are what the running app restores from, and they die
// with it. A crash, a kill, or a power loss therefore leaves the machine
// pointed at a relay port that no longer has anything listening on it — every
// app honouring the system proxy loses the network, and nothing on screen says
// why. `clearProxy` cannot repair that on the next launch either: it is guarded
// by `g_proxy_applied_by_us`, which a fresh process starts with false.
//
// So the snapshot is written here as well as held in memory, and a launch
// finding one left over puts it back. Same bargain the ad gate makes — what
// cannot be caught on the way out gets caught on the way in.
constexpr wchar_t kRecoveryKey[] = L"Software\\Begzar\\ProxyRecovery";

bool g_proxy_applied_by_us = false;
DWORD g_previous_proxy_enable = 0;
bool g_had_previous_proxy_server = false;
std::wstring g_previous_proxy_server;
bool g_had_previous_proxy_override = false;
std::wstring g_previous_proxy_override;

void NotifyProxySettingsChanged() {
  InternetSetOption(nullptr, INTERNET_OPTION_SETTINGS_CHANGED, nullptr, 0);
  InternetSetOption(nullptr, INTERNET_OPTION_REFRESH, nullptr, 0);
}

bool ReadDword(HKEY key, const wchar_t* name, DWORD* out_value) {
  DWORD type = 0;
  DWORD size = sizeof(DWORD);
  return RegQueryValueExW(key, name, nullptr, &type,
                          reinterpret_cast<LPBYTE>(out_value), &size) ==
             ERROR_SUCCESS &&
         type == REG_DWORD;
}

bool ReadString(HKEY key, const wchar_t* name, std::wstring* out_value) {
  DWORD type = 0;
  DWORD size = 0;
  if (RegQueryValueExW(key, name, nullptr, &type, nullptr, &size) !=
          ERROR_SUCCESS ||
      type != REG_SZ || size == 0) {
    return false;
  }
  out_value->assign(size / sizeof(wchar_t), L'\0');
  if (RegQueryValueExW(key, name, nullptr, &type,
                       reinterpret_cast<LPBYTE>(out_value->data()),
                       &size) != ERROR_SUCCESS) {
    out_value->clear();
    return false;
  }
  while (!out_value->empty() && out_value->back() == L'\0') {
    out_value->pop_back();
  }
  return true;
}

void SnapshotCurrentProxy(HKEY key) {
  g_previous_proxy_enable = 0;
  ReadDword(key, L"ProxyEnable", &g_previous_proxy_enable);

  g_previous_proxy_server.clear();
  g_had_previous_proxy_server = ReadString(key, L"ProxyServer",
                                           &g_previous_proxy_server);

  g_previous_proxy_override.clear();
  g_had_previous_proxy_override =
      ReadString(key, L"ProxyOverride", &g_previous_proxy_override);
}

bool WriteDword(HKEY key, const wchar_t* name, DWORD value) {
  return RegSetValueExW(key, name, 0, REG_DWORD,
                        reinterpret_cast<const BYTE*>(&value),
                        sizeof(value)) == ERROR_SUCCESS;
}

bool WriteString(HKEY key, const wchar_t* name, const std::wstring& value) {
  const auto bytes =
      static_cast<DWORD>((value.size() + 1) * sizeof(wchar_t));
  return RegSetValueExW(key, name, 0, REG_SZ,
                        reinterpret_cast<const BYTE*>(value.c_str()),
                        bytes) == ERROR_SUCCESS;
}

// Records what we are about to apply, and what was there before it.
//
// `AppliedServer` is the half that makes recovery safe: it says which proxy is
// ours, so a launch can tell "we left this behind" from "the user has since
// set their own", and never restores over somebody else's setting.
void WriteRecoverySnapshot(const std::wstring& applied_server) {
  HKEY key = nullptr;
  if (RegCreateKeyExW(HKEY_CURRENT_USER, kRecoveryKey, 0, nullptr, 0,
                      KEY_READ | KEY_WRITE, nullptr, &key,
                      nullptr) != ERROR_SUCCESS) {
    return;
  }
  WriteString(key, L"AppliedServer", applied_server);
  WriteDword(key, L"PrevEnable", g_previous_proxy_enable);
  WriteDword(key, L"HadPrevServer", g_had_previous_proxy_server ? 1 : 0);
  WriteString(key, L"PrevServer", g_previous_proxy_server);
  WriteDword(key, L"HadPrevOverride", g_had_previous_proxy_override ? 1 : 0);
  WriteString(key, L"PrevOverride", g_previous_proxy_override);
  RegCloseKey(key);
}

void DeleteRecoverySnapshot() {
  RegDeleteKeyW(HKEY_CURRENT_USER, kRecoveryKey);
}

bool ApplySystemProxy(const std::wstring& proxy_server) {
  HKEY key = nullptr;
  if (RegOpenKeyExW(HKEY_CURRENT_USER, kInternetSettingsKey, 0,
                    KEY_READ | KEY_WRITE, &key) != ERROR_SUCCESS) {
    return false;
  }

  if (!g_proxy_applied_by_us) {
    SnapshotCurrentProxy(key);
  }

  const std::wstring override_list =
      L"localhost;127.*;10.*;172.16.*;172.17.*;172.18.*;172.19.*;"
      L"172.20.*;172.21.*;172.22.*;172.23.*;172.24.*;172.25.*;172.26.*;"
      L"172.27.*;172.28.*;172.29.*;172.30.*;172.31.*;192.168.*;<local>";

  const bool ok = WriteDword(key, L"ProxyEnable", 1) &&
                  WriteString(key, L"ProxyServer", proxy_server) &&
                  WriteString(key, L"ProxyOverride", override_list);
  RegCloseKey(key);

  if (ok) {
    g_proxy_applied_by_us = true;
    WriteRecoverySnapshot(proxy_server);
    NotifyProxySettingsChanged();
  }
  return ok;
}

bool RestoreSystemProxy() {
  if (!g_proxy_applied_by_us) {
    return true;
  }

  HKEY key = nullptr;
  if (RegOpenKeyExW(HKEY_CURRENT_USER, kInternetSettingsKey, 0,
                    KEY_READ | KEY_WRITE, &key) != ERROR_SUCCESS) {
    return false;
  }

  WriteDword(key, L"ProxyEnable", g_previous_proxy_enable);

  if (g_had_previous_proxy_server) {
    WriteString(key, L"ProxyServer", g_previous_proxy_server);
  } else {
    RegDeleteValueW(key, L"ProxyServer");
  }

  if (g_had_previous_proxy_override) {
    WriteString(key, L"ProxyOverride", g_previous_proxy_override);
  } else {
    RegDeleteValueW(key, L"ProxyOverride");
  }

  RegCloseKey(key);
  g_proxy_applied_by_us = false;
  DeleteRecoverySnapshot();
  NotifyProxySettingsChanged();
  return true;
}

// Puts back a proxy the previous run was killed before it could restore.
//
// Only when the machine is still on the exact proxy we applied. Anything else
// means the setting has moved on — the user pointed it somewhere themselves, or
// another tool owns it now — and the snapshot is stale rather than pending, so
// it is dropped without touching the current setting. Restoring blind is how a
// recovery path becomes the thing it was written to prevent.
void RecoverStaleProxy() {
  HKEY recovery = nullptr;
  if (RegOpenKeyExW(HKEY_CURRENT_USER, kRecoveryKey, 0, KEY_READ, &recovery) !=
      ERROR_SUCCESS) {
    return;  // Nothing pending: the last run shut down cleanly.
  }

  std::wstring applied_server;
  DWORD prev_enable = 0;
  DWORD had_prev_server = 0;
  DWORD had_prev_override = 0;
  std::wstring prev_server;
  std::wstring prev_override;

  const bool readable = ReadString(recovery, L"AppliedServer", &applied_server);
  ReadDword(recovery, L"PrevEnable", &prev_enable);
  ReadDword(recovery, L"HadPrevServer", &had_prev_server);
  ReadDword(recovery, L"HadPrevOverride", &had_prev_override);
  ReadString(recovery, L"PrevServer", &prev_server);
  ReadString(recovery, L"PrevOverride", &prev_override);
  RegCloseKey(recovery);

  if (!readable || applied_server.empty()) {
    DeleteRecoverySnapshot();
    return;
  }

  HKEY settings = nullptr;
  if (RegOpenKeyExW(HKEY_CURRENT_USER, kInternetSettingsKey, 0,
                    KEY_READ | KEY_WRITE, &settings) != ERROR_SUCCESS) {
    return;  // Leave the snapshot; a later launch may be able to open it.
  }

  DWORD current_enable = 0;
  std::wstring current_server;
  ReadDword(settings, L"ProxyEnable", &current_enable);
  ReadString(settings, L"ProxyServer", &current_server);

  if (current_enable == 0 || current_server != applied_server) {
    RegCloseKey(settings);
    DeleteRecoverySnapshot();
    return;
  }

  WriteDword(settings, L"ProxyEnable", prev_enable);
  if (had_prev_server != 0) {
    WriteString(settings, L"ProxyServer", prev_server);
  } else {
    RegDeleteValueW(settings, L"ProxyServer");
  }
  if (had_prev_override != 0) {
    WriteString(settings, L"ProxyOverride", prev_override);
  } else {
    RegDeleteValueW(settings, L"ProxyOverride");
  }
  RegCloseKey(settings);

  DeleteRecoverySnapshot();
  NotifyProxySettingsChanged();
}

}  // namespace

void ClearSystemProxyIfApplied() { RestoreSystemProxy(); }

void RegisterSystemProxyPlugin(flutter::BinaryMessenger* messenger) {
  // Before anything can set a proxy, put back one the last run left behind.
  RecoverStaleProxy();

  const auto channel =
      std::make_shared<flutter::MethodChannel<flutter::EncodableValue>>(
          messenger, "begzar/system_proxy",
          &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [channel](const flutter::MethodCall<flutter::EncodableValue>& call,
                std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                    result) {
        if (call.method_name() == "setProxy") {
          const auto* args =
              std::get_if<flutter::EncodableMap>(call.arguments());
          if (args == nullptr) {
            result->Error("invalid_args", "Expected map arguments");
            return;
          }

          auto host_it = args->find(flutter::EncodableValue("host"));
          auto port_it = args->find(flutter::EncodableValue("port"));
          if (host_it == args->end() || port_it == args->end()) {
            result->Error("invalid_args", "host and port are required");
            return;
          }

          const auto* host = std::get_if<std::string>(&host_it->second);
          const auto* port = std::get_if<int32_t>(&port_it->second);
          if (host == nullptr || port == nullptr) {
            // Flutter may encode port as int64
            const auto* port64 = std::get_if<int64_t>(&port_it->second);
            if (host == nullptr || port64 == nullptr) {
              result->Error("invalid_args", "Invalid host/port types");
              return;
            }
            const std::wstring proxy =
                Utf16FromUtf8(*host + ":" + std::to_string(*port64));
            result->Success(flutter::EncodableValue(ApplySystemProxy(proxy)));
            return;
          }

          const std::wstring proxy =
              Utf16FromUtf8(*host + ":" + std::to_string(*port));
          result->Success(flutter::EncodableValue(ApplySystemProxy(proxy)));
          return;
        }

        if (call.method_name() == "clearProxy") {
          result->Success(flutter::EncodableValue(RestoreSystemProxy()));
          return;
        }

        result->NotImplemented();
      });
}
