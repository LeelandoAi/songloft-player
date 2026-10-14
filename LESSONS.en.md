# Flutter Client Development Lessons

## Scope and Sources

Record Flutter, providers, audio, Bundle mode, and native hosts in songloft-org/songloft-player. See the [local AI workflow](docs/en/ai-development.md) and parent host constraints. Existing AGENTS/business references remain authoritative; link evidence rather than duplicating incident histories.

## Recording and Promotion

Include rule, scope, full owner/repo#number, failure/fix commit SHAs, actual validation, and Done right examples (pending if unavailable). Seen counts independent events on distinct dates, not repeated reviews. Three dates make promotion candidates; mark the authoritative destination. Existing hard rules/serious failures apply immediately. Synchronize the [Chinese version](LESSONS.md), never invent counts/resolution/device acceptance, and redact sensitive information.

## Entries

### AUDIO-001: Check SDK conversion by Android version for notification Stop

- Scope: Flutter audio_service notifications and Android system media panels, songloft-org/songloft#520.
- Rule: Inspect the locked version's `createCustomAction`, notification-action list and platform conversion; a Dart customAction field does not prove rendering on every Android version.
- Evidence: On 2026-10-14, baseline `3860205b0d8cf8449d8cf31746c254ef597c55e3` used an explicit custom Stop, excluded from audio_service 0.18.19's ordinary notification list. This batch initially added standard STOP as well; API 34 showed two Stop actions. The library already converts standard STOP to a custom STOP on Android 13+, making dual registration redundant.
- Done right: Keep standard STOP alone, supplying the older notification action and one newer panel action. Removing it in an isolated copy fails four regressions, which pass with the fix. Final API 34/x86_64 playback reports one Stop; Account exit during playback removes PID, services and notification. Evidence: `/tmp/songloft-520-flutter-{single-stop,final-playing,playing-exit}.json`; working-tree object: [#520 record](docs/en/issue-520.md).
- Stop lifecycle: actual API 34 checks found late ready/completed events could republish active playback, and an Activity binding prevented upstream stopSelf() from destroying the service, retaining its foreground notification/wake lock. Dart's stop state rejects stale loads/completion callbacks; local audio_service 0.18.19 ends foreground mode and releases the wake lock in stop(). After stopping: zero notifications, inactive session, startRequested=false; selecting a song restores playback. This remains one incident.
- Not run: HarmonyOS 4.2 hardware notification layout; API 34 does not replace that acceptance.
- Seen 1× (2026-10-14). Status: lesson; fix remains uncommitted, emulator results do not imply release availability.

### WIN-001: Auxiliary window coordinate tests do not verify WebView2 desktop input

- Scope: Windows plugin WebView2, cross-monitor movement, and mouse input in abandoned screen regions.
- Rule: Check the fix commit, release version, and actual input separately. Simulated Win32 coordinate tests and Windows compilation cannot prove desktop context menus work in the old region. Cover fullscreen plugins, movement between monitors in both directions, different DPI settings, minimization, and tray restoration; record real window and input evidence.
- Failure: The position synchronization patch [f1ef7f2](https://github.com/songloft-org/songloft-player/commit/f1ef7f2d8aabf4ba9e9da12cac029f52e211e189) for songloft-org/songloft#499 landed on 2026-10-06 with simulated window and compilation checks, explicitly without a dual-monitor smoke test. On 2026-10-14, the reporter [said client 2.13.1 still blocked right-clicks](https://github.com/songloft-org/songloft/issues/499#issuecomment-6160069251). Both the standard v2.13.1 tag and the parent release's client gitlink resolve to f684da386c75bb8825713b1b14fdd2a3c24d7adb, which includes the patch; a missing release inclusion does not explain this report.
- Investigation: At baseline 1cb9b4947cdc1c641507e9486b0a0024fc274e97, all seven existing simulated scenarios passed on Linux/GCC 12.2. The tests contain no WebView2 controller or real mouse hit testing. Neither the baseline runner nor the locked flutter_inappwebview_windows 0.6.0 calls `NotifyParentWindowPositionChanged`. This is a confirmed integration gap, but not a proven cause of recurrence.
- Candidate fix: This candidate patch vendors the Windows platform package into `third_party/flutter_inappwebview_windows` and notifies the controller after default processing of the auxiliary HWND's `WM_WINDOWPOSCHANGED`. Exit and window destruction both detach the observer, with protection against reentrancy and HWND reuse. Windows packaging CI adds real HWND/comctl32 checks; ZIP packages include a read-only `webview_hit_test.exe` to identify the actual hit window if the bug persists. See the [patch notes](third_party/flutter_inappwebview_windows/README.en.md) and [platform acceptance steps](docs/en/platform-notes.md#windows-plugin-and-desktop-context-menu-acceptance).
- Done right: Linux/GCC 12.2 `cmake` and `ctest` passed (seven existing coordinate scenarios plus eight observer scenarios, in `/tmp/songloft-499-native-20261014-02`). Removing the notification or explicit detachment in isolated copies compiled successfully and made the target test fail; logs are `/tmp/songloft-499-no-notify-final-20261014/validation.log` and `/tmp/songloft-499-no-detach-final-20261014/validation.log`. These are mutation checks, not Windows reproduction using the old package. On Flutter 3.41.5, 13 plugin-related tests, `flutter analyze`, formatting, and diff checks passed. Not run: complete Windows compilation, real HWND checks, diagnostic tool execution, and dual-monitor/WebView2 input acceptance. The host runs Linux and the user has no Windows environment; CI builds and reporter testing remain pending.
- Seen 1× (2026-10-14). Status: lesson; #499 still lacks device acceptance.
