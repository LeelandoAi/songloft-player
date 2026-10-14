cmake_minimum_required(VERSION 3.14)
project(webview_window_sync_test LANGUAGES CXX)

# Exercise the runner's movement logic on any host. This Win32 stub models HWND
# ownership and geometry; it does not replace a Windows/WebView2 smoke test.
add_executable(webview_window_sync_test
  webview_window_sync_test.cpp
  ../../../windows/runner/webview_window_sync.cpp
)
target_compile_features(webview_window_sync_test PRIVATE cxx_std_17)
target_include_directories(webview_window_sync_test PRIVATE
  win32_stub
  ../../../windows/runner
)
if(MSVC)
  target_compile_options(webview_window_sync_test PRIVATE /W4 /WX)
else()
  target_compile_options(webview_window_sync_test PRIVATE -Wall -Wextra -Werror)
endif()
enable_testing()
add_test(NAME webview_window_sync COMMAND webview_window_sync_test)

set(OBSERVER_INCLUDE_DIR
  ../../../third_party/flutter_inappwebview_windows/windows/custom_platform_view)
add_executable(parent_window_position_observer_test
  parent_window_position_observer_test.cpp)
target_compile_features(parent_window_position_observer_test PRIVATE cxx_std_17)
target_include_directories(parent_window_position_observer_test PRIVATE
  win32_stub ${OBSERVER_INCLUDE_DIR})
if(MSVC)
  target_compile_options(parent_window_position_observer_test PRIVATE /W4 /WX)
else()
  target_compile_options(parent_window_position_observer_test PRIVATE
    -Wall -Wextra -Werror)
endif()
add_test(NAME parent_window_position_observer
  COMMAND parent_window_position_observer_test)

# Real HWND delivery and comctl32 subclass teardown, without Flutter or a mock
# Windows message dispatcher. This still does not replace WebView2 device tests.
if(WIN32)
  # Ship this optional read-only probe beside the portable client so a reporter
  # can identify the actual HWND receiving input if desktop clicks still fail.
  add_executable(webview_hit_test webview_hit_test.cpp)
  target_compile_features(webview_hit_test PRIVATE cxx_std_17)
  add_executable(parent_window_position_observer_win32_test
    parent_window_position_observer_win32_test.cpp)
  target_compile_features(parent_window_position_observer_win32_test
    PRIVATE cxx_std_17)
  target_include_directories(parent_window_position_observer_win32_test
    PRIVATE ${OBSERVER_INCLUDE_DIR})
  target_link_libraries(parent_window_position_observer_win32_test
    PRIVATE comctl32)
  if(MSVC)
    target_compile_options(parent_window_position_observer_win32_test
      PRIVATE /W4 /WX)
  endif()
  add_test(NAME parent_window_position_observer_win32
    COMMAND parent_window_position_observer_win32_test)
endif()
