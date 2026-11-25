#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <stdlib.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

#ifndef _DEBUG
namespace {

// The Dart heap holds the session token, premium access key, and server
// configs as plaintext strings. A WER minidump of a crash would persist all
// of them to disk, so terminate before the default handler can invoke WER.
// This trades post-mortem crash dumps for not writing secrets to disk.
LONG WINAPI TerminateWithoutDump(EXCEPTION_POINTERS *info) {
  ::TerminateProcess(::GetCurrentProcess(),
                     info->ExceptionRecord->ExceptionCode);
  return EXCEPTION_CONTINUE_SEARCH;  // Unreachable.
}

}  // namespace
#endif

namespace {

// One Begzar per logon session.
//
// The engine's gRPC gateway binds a loopback port, and the close button only
// hides the window (see system_tray_plugin.cpp), so a user who closes to tray
// and then reopens from the shortcut starts a second copy. Two copies means two
// engines writing the same system-proxy registry values over each other, and
// the tray icon of the one nobody is looking at. Hand the click to the copy
// that is already running instead of starting another.
//
// `Local\` scopes the mutex to the session, so two users on one machine get one
// Begzar each and nothing reaches across a session boundary.
constexpr wchar_t kInstanceMutexName[] = L"Local\\BegzarSingleInstance";

// The window class is Flutter's own and every Flutter app on the machine shares
// it, so the title is what makes a match ours. Both must agree: raising some
// other app's window would be worse than doing nothing.
constexpr wchar_t kInstanceWindowClass[] = L"FLUTTER_RUNNER_WIN32_WINDOW";
constexpr wchar_t kInstanceWindowTitle[] = L"BegzarVPN";

// A second launch can land while the first copy is still starting and has no
// window to raise yet, so wait briefly rather than give up on the first look.
constexpr int kExistingWindowWaitMs = 3000;
constexpr int kExistingWindowPollMs = 100;

// Brings the running copy's window up. Silent if it never appears: that copy is
// wedged, and starting a second engine beside it is the failure this guard
// exists to prevent.
void RaiseExistingInstance() {
  for (int waited = 0; waited <= kExistingWindowWaitMs;
       waited += kExistingWindowPollMs) {
    HWND existing =
        ::FindWindowW(kInstanceWindowClass, kInstanceWindowTitle);
    if (existing != nullptr) {
      ::ShowWindow(existing, SW_SHOW);
      ::ShowWindow(existing, SW_RESTORE);
      ::SetForegroundWindow(existing);
      return;
    }
    ::Sleep(kExistingWindowPollMs);
  }
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Before anything that touches shared state — the proxy registry recovery
  // runs with the plugins, further down — decide whether this copy should run
  // at all. The handle is deliberately left open: the mutex must live as long
  // as the process, and closing it is what process exit is for.
  HANDLE instance_mutex = ::CreateMutexW(nullptr, TRUE, kInstanceMutexName);
  if (instance_mutex != nullptr && ::GetLastError() == ERROR_ALREADY_EXISTS) {
    RaiseExistingInstance();
    ::CloseHandle(instance_mutex);
    return EXIT_SUCCESS;
  }

#ifdef _DEBUG
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }
#else
  // Keep parent-console output for `flutter run --release`, but never spawn
  // a console for an attached debugger in shipped builds.
  ::AttachConsole(ATTACH_PARENT_PROCESS);
  // No fault dialog, no WER dump, no WER report on abort().
  ::SetErrorMode(SEM_FAILCRITICALERRORS | SEM_NOGPFAULTERRORBOX |
                 SEM_NOOPENFILEERRORBOX);
  ::SetUnhandledExceptionFilter(TerminateWithoutDump);
  _set_abort_behavior(0, _WRITE_ABORT_MSG | _CALL_REPORTFAULT);
#endif

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  // Start at a phone-ish frame (ScreenUtil designSize); window is resizable.
  Win32Window::Size size(393, 852);
  if (!window.Create(L"BegzarVPN", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
