#include "running_programs_plugin.h"

#include <windows.h>
#include <tlhelp32.h>

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>
#include <vector>

#include "utils.h"

namespace {

// These are the channel and method names that RunningProgramsDataSource uses on
// the Dart side, so each one changes on both sides or on neither.
constexpr char kChannelName[] = "cloud.begzar.begzar/running_programs";
constexpr char kListMethod[] = "list";

// Windows accepts paths of up to this many UTF-16 code units, terminator
// included.
constexpr DWORD kMaxImagePathLength = 32768;

// Returns the full path of the executable behind a process, or an empty string
// when Windows will not give it. Protected and system processes refuse to be
// opened, and those are not programs a user would pick.
std::wstring ImagePathOf(DWORD process_id, std::vector<wchar_t>& buffer) {
  HANDLE process =
      OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, process_id);
  if (process == nullptr) return std::wstring();

  // Holds the size of the buffer on input and the length written on output. The
  // query reads the same path the engine's own process lookup reads.
  DWORD length = static_cast<DWORD>(buffer.size());
  const BOOL queried =
      QueryFullProcessImageNameW(process, 0, buffer.data(), &length);
  CloseHandle(process);
  if (!queried) return std::wstring();
  return std::wstring(buffer.data(), length);
}

// Returns one path per running process, so a program with several instances is
// listed several times; the Dart side keeps one entry per file name.
flutter::EncodableList RunningProgramPaths() {
  flutter::EncodableList paths;

  const HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if (snapshot == INVALID_HANDLE_VALUE) return paths;

  std::vector<wchar_t> buffer(kMaxImagePathLength);
  PROCESSENTRY32W entry{};
  entry.dwSize = sizeof(PROCESSENTRY32W);
  for (BOOL found = Process32FirstW(snapshot, &entry); found;
       found = Process32NextW(snapshot, &entry)) {
    const std::wstring path = ImagePathOf(entry.th32ProcessID, buffer);
    if (path.empty()) continue;

    // A path that does not convert comes back empty and is left out.
    const std::string utf8_path = Utf8FromUtf16(path.c_str());
    if (utf8_path.empty()) continue;
    paths.push_back(flutter::EncodableValue(utf8_path));
  }

  CloseHandle(snapshot);
  return paths;
}

}  // namespace

void RegisterRunningProgramsPlugin(flutter::BinaryMessenger* messenger) {
  const auto channel =
      std::make_shared<flutter::MethodChannel<flutter::EncodableValue>>(
          messenger, kChannelName,
          &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [channel](const flutter::MethodCall<flutter::EncodableValue>& call,
                std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                    result) {
        if (call.method_name() == kListMethod) {
          result->Success(flutter::EncodableValue(RunningProgramPaths()));
        } else {
          result->NotImplemented();
        }
      });
}
