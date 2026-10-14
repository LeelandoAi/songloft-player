#include <windows.h>

#include <chrono>
#include <fstream>
#include <iostream>
#include <string>
#include <thread>

namespace {

void WriteWindow(std::ostream& output, const char* role, HWND window) {
  DWORD process = 0;
  GetWindowThreadProcessId(window, &process);
  wchar_t class_name[256] = {};
  GetClassNameW(window, class_name, 256);
  char utf8_class[1024] = {};
  WideCharToMultiByte(CP_UTF8, 0, class_name, -1, utf8_class, 1024, nullptr, nullptr);
  RECT bounds = {};
  GetWindowRect(window, &bounds);
  // Do not read titles, URLs, process command lines, or other private content.
  output << role << " hwnd=" << window << " pid=" << process
         << " class=" << utf8_class << " rect=" << bounds.left << ','
         << bounds.top << ',' << bounds.right << ',' << bounds.bottom << '\n';
}

}  // namespace

int main() {
  const auto timestamp = std::chrono::duration_cast<std::chrono::milliseconds>(
      std::chrono::system_clock::now().time_since_epoch()).count();
  const std::string filename =
      "songloft-webview-hit-test-" + std::to_string(timestamp) + ".txt";
  std::ofstream log(filename);
  if (!log) {
    std::cerr << "Cannot write diagnostic log in this directory.\n";
    return 1;
  }
  std::cout << "Move the mouse to the old/blocked desktop region.\n"
            << "Sampling for 20 seconds; no clicks are sent.\n"
            << "Log: " << filename << '\n';
  for (int sample = 0; sample < 40; ++sample) {
    POINT cursor = {};
    if (GetCursorPos(&cursor)) {
      const HWND hit = WindowFromPoint(cursor);
      const HWND root = GetAncestor(hit, GA_ROOT);
      log << "sample=" << sample << " cursor=" << cursor.x << ',' << cursor.y
          << '\n';
      WriteWindow(log, "hit", hit);
      WriteWindow(log, "root", root);
      WriteWindow(log, "owner", GetWindow(root, GW_OWNER));
    }
    std::this_thread::sleep_for(std::chrono::milliseconds(500));
  }
  std::cout << "Saved " << filename << '\n';
  return 0;
}
