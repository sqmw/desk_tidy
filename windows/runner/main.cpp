#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <cwchar>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

namespace {
constexpr wchar_t kMainWindowTitle[] = L"desk_tidy";
constexpr wchar_t kMainWindowClass[] = L"DESK_TIDY_WIN32_WINDOW";

struct FindWindowByClassState {
  const wchar_t* class_name;
  HWND hwnd;
};

BOOL CALLBACK EnumWindowsFindByClass(HWND hwnd, LPARAM l_param) {
  auto* state = reinterpret_cast<FindWindowByClassState*>(l_param);
  wchar_t class_name[256]{};
  const int len = GetClassNameW(hwnd, class_name, 256);
  if (len <= 0) {
    return TRUE;
  }
  if (wcscmp(class_name, state->class_name) != 0) {
    return TRUE;
  }
  state->hwnd = hwnd;
  return FALSE;
}

HWND FindExistingMainWindow() {
  FindWindowByClassState state{kMainWindowClass, nullptr};
  EnumWindows(EnumWindowsFindByClass, reinterpret_cast<LPARAM>(&state));
  return state.hwnd;
}

void ActivateExistingInstance(HWND hwnd) {
  if (IsIconic(hwnd)) {
    ShowWindow(hwnd, SW_RESTORE);
  } else {
    ShowWindow(hwnd, SW_SHOW);
  }
  SetForegroundWindow(hwnd);
}
}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Native single-instance guard: if another instance already has a window,
  // activate it and exit.
  const HWND existing = FindExistingMainWindow();
  if (existing != nullptr) {
    ActivateExistingInstance(existing);
    return EXIT_SUCCESS;
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(kMainWindowTitle, origin, size)) {
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
