#ifndef TEST_WIN32_STUB_COMMCTRL_H_
#define TEST_WIN32_STUB_COMMCTRL_H_

#include <windows.h>

using SUBCLASSPROC = LRESULT(CALLBACK*)(HWND, UINT, WPARAM, LPARAM, UINT_PTR,
                                      DWORD_PTR);
BOOL SetWindowSubclass(HWND window, SUBCLASSPROC callback, UINT_PTR id,
                       DWORD_PTR data);
BOOL RemoveWindowSubclass(HWND window, SUBCLASSPROC callback, UINT_PTR id);
BOOL GetWindowSubclass(HWND window, SUBCLASSPROC callback, UINT_PTR id,
                      DWORD_PTR* data);
LRESULT DefSubclassProc(HWND window, UINT message, WPARAM wparam, LPARAM lparam);

#endif  // TEST_WIN32_STUB_COMMCTRL_H_
