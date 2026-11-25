#include "tunnel_helper_plugin.h"

#include <windows.h>
#include <shellapi.h>

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>
#include <vector>

#include "utils.h"

namespace {

// These are the channel, method and argument names that
// PlatformTunnelHelperLauncher uses on the Dart side, so each one changes on
// both sides or on neither.
constexpr char kChannelName[] = "begzar/tunnel_helper";
constexpr char kLaunchMethod[] = "launch";
constexpr char kParametersArgument[] = "parameters";

// The answers, by the names HelperLaunchOutcome gives them on the Dart side.
constexpr char kStarted[] = "started";
constexpr char kDeclined[] = "declined";
constexpr char kMissing[] = "missing";
constexpr char kFailed[] = "failed";

// The helper ships beside begzar.exe.
constexpr wchar_t kHelperFileName[] = L"begzar-tun.exe";

// Windows accepts paths of up to this many UTF-16 code units, terminator
// included.
constexpr DWORD kMaxPathLength = 32768;

// Returns the path begzar-tun.exe has beside the running executable, or an
// empty string when Windows will not say where that executable is.
std::wstring HelperPath() {
  std::vector<wchar_t> buffer(kMaxPathLength);
  const DWORD length = GetModuleFileNameW(nullptr, buffer.data(),
                                          static_cast<DWORD>(buffer.size()));
  // A path that filled the buffer was cut short.
  if (length == 0 || length >= buffer.size()) return std::wstring();

  const std::wstring executable(buffer.data(), length);
  const size_t separator = executable.find_last_of(L'\\');
  if (separator == std::wstring::npos) return std::wstring();
  return executable.substr(0, separator + 1) + kHelperFileName;
}

bool IsFile(const std::wstring& path) {
  const DWORD attributes = GetFileAttributesW(path.c_str());
  return attributes != INVALID_FILE_ATTRIBUTES &&
         (attributes & FILE_ATTRIBUTE_DIRECTORY) == 0;
}

// Reads the helper's command line out of the call. Anything but a map holding
// a string under "parameters" is refused rather than launched.
const std::string* ParametersOf(const flutter::EncodableValue* arguments) {
  if (arguments == nullptr) return nullptr;
  const auto* map = std::get_if<flutter::EncodableMap>(arguments);
  if (map == nullptr) return nullptr;
  const auto found = map->find(flutter::EncodableValue(kParametersArgument));
  if (found == map->end()) return nullptr;
  return std::get_if<std::string>(&found->second);
}

// Starts the helper elevated and answers how that went.
//
// With SEE_MASK_NOASYNC, ShellExecuteExW does not return until the consent
// prompt has been answered, so this blocks the platform thread for as long as
// the prompt is up. Nothing is lost by that: the prompt sits on the secure
// desktop, where the app cannot be reached until it is answered anyway.
//
// The prompt is owned by `window`. Without an owner Windows can raise it behind
// the app or only flash it in the taskbar, and the app would sit there not
// responding while the user looks for it.
const char* LaunchHelper(HWND window, const std::string& parameters) {
  const std::wstring path = HelperPath();
  if (path.empty() || !IsFile(path)) return kMissing;

  // A string that does not convert is not launched in some altered form.
  const std::wstring wide_parameters = Utf16FromUtf8(parameters);
  if (wide_parameters.empty() && !parameters.empty()) return kFailed;

  SHELLEXECUTEINFOW info{};
  info.cbSize = sizeof(info);
  // SEE_MASK_FLAG_NO_UI keeps Windows' own error box off a failed launch,
  // which the app reports itself; the consent prompt still shows.
  info.fMask = SEE_MASK_NOCLOSEPROCESS | SEE_MASK_NOASYNC | SEE_MASK_FLAG_NO_UI;
  info.hwnd = window;
  info.lpVerb = L"runas";
  info.lpFile = path.c_str();
  info.lpParameters = wide_parameters.c_str();
  info.nShow = SW_HIDE;
  if (!ShellExecuteExW(&info)) {
    return GetLastError() == ERROR_CANCELLED ? kDeclined : kFailed;
  }

  // The helper's life is tied to its lease, not to this handle.
  if (info.hProcess != nullptr) CloseHandle(info.hProcess);
  return kStarted;
}

}  // namespace

void RegisterTunnelHelperPlugin(flutter::BinaryMessenger* messenger,
                                HWND window) {
  const auto channel =
      std::make_shared<flutter::MethodChannel<flutter::EncodableValue>>(
          messenger, kChannelName,
          &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [channel, window](
          const flutter::MethodCall<flutter::EncodableValue>& call,
          std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
              result) {
        if (call.method_name() != kLaunchMethod) {
          result->NotImplemented();
          return;
        }
        const std::string* parameters = ParametersOf(call.arguments());
        const char* outcome = parameters == nullptr
                                  ? kFailed
                                  : LaunchHelper(window, *parameters);
        result->Success(flutter::EncodableValue(std::string(outcome)));
      });
}
