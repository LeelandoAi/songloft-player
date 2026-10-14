# Keep Screen On for Lyrics and Exit App · songloft-org/songloft#520

2026-10-14. The first batch implemented only the screen-awake preference. The follow-up exit changes are recorded below; earlier validation objects remain preserved.

## Follow-up: Android Exit and Notification Stop

Final delivery checks completed on 2026-10-15; investigation/implementation span October 14–15.

Baseline `3860205b0d8cf8449d8cf31746c254ef597c55e3` plus the uncommitted working tree. Source SHA-256 `a4096442900eb8a067cad0ca8305056737b1400e3124f7164fcb59514c95b2bb` (algorithm/scope in the validation JSON). The reporter confirmed lyrics stay awake after enabling the development build preference; this batch addresses their follow-up exit report.

- Settings → Account → Exit app stops audio, hides floating lyrics, stops the Bundle backend, and closes the Android task/process while retaining sign-in and local preferences. Repeated requests share one cleanup; errors/timeouts do not prevent subsequent steps. Removing the task uses the same flow. Home/ordinary backgrounding still continues playback.
- In audio_service 0.18.19, standard media STOP becomes a notification action on Android 12 and earlier and automatically becomes a system custom STOP on Android 13+. An explicit custom control loses the older notification button; registering both duplicates the newer action. Notification Stop stops playback and removes the notification while keeping the browsing UI.
- Native task termination uses the existing floating-lyrics `exec` method with subcommand `exitApp`, without adding MethodChannel names or plugins. Older APKs fall back to stopping resources, SystemNavigator.pop and process termination; complete task removal requires the new APK. The new entry is Android-only.
- Explicit stop state rejects late ready/completed events and stale asynchronous loads, preventing notification revival/auto-advance. The local [audio_service 0.18.19 patch](../../third_party/audio_service/README.en.md) removes foreground mode and releases the wake lock during stop: an Activity binding means cleanup cannot wait for onDestroy. This native fix requires a complete APK.
- Linux / Flutter 3.44.8 / Dart 3.12.2: formatting, analysis, all 708 tests and Debug APK compilation pass. Stop regressions cover late events, completion callbacks, initialization waits and pending sources. Removing stop state fails 2 target regressions; removing standard STOP fails 4. Logs: `/tmp/songloft-520-exit-flutter-{analyze-final,tests-final,apk4}.log`, `/tmp/songloft-520-stop-lifecycle-{final,negative}.log`. Working-tree identity, APK hashes and acceptance checklist: `/tmp/songloft-520-exit-validation.json`.
- Android API 34 emulator, explicitly installed as x86_64, 1080×1920/density 440, isolated server and synthetic audio: one notification STOP. Clicking it during playback yields playing=false, inactive media, zero active notifications and startRequested=false. The UI's binding may remain; selecting another song restores playback. Account exit during playback and swiping the recent task remove PID, active services and notification; relaunch preserves login. Evidence: `/tmp/songloft-520-flutter-{stop-before,stop-after,replay,exit-before,exit-after,task-before,task-after}-final.json`.
- Not run: HarmonyOS 4.2 hardware, actual Android 12-or-earlier notification layout, Bundle Android backend shutdown, exit with floating lyrics actually enabled, iOS/desktop native builds. Standard APK/emulator checks do not replace these. On 2026-10-15 the user authorized commits, pushes and an Issue reply. Final SHAs, development packages and CI status are determined by Git and workflows for the same SHA; no stable tag is created.

## Behavior

Settings → Playback → Keep screen on for lyrics follows the open-lyrics-on-launch option. It defaults to off; `player_lyrics_keep_screen_on` is device-local. Mobile applies it only while the lyrics page is visible; wide layouts show lyrics beside the cover. It remains active while paused. Returning to the cover, covering the player route, leaving the page or backgrounding the app releases it; returning to visible lyrics in the foreground reacquires it.

Reuse `wakelock_plus 1.5.2`, already imported and registered through `media_kit_video`, as a direct dependency. No new native plugin or Kotlin method. Lyrics and native video share an owner-set controller with serialized native writes, so releasing lyrics cannot cancel a video's request. Unsupported or denied browser requests do not interrupt playback.

## Validation Object and Results

- Repository: `songloft-org/songloft-player`, baseline `57db9766ac36b58f136b4e7ae41a2d1c51a079ce` plus uncommitted worktree. Source SHA-256: `4ee8dddc9c095b05e25cd891e1ff7e66b245dfe902c9bd97d9d02c6ec1be863d`. Algorithm/path scope: `/tmp/songloft-520-validation.json` (`git diff --binary` plus in-scope untracked paths/content; documentation excluded).
- Environment: Linux, Flutter 3.41.5, embedded Web; Docker `browserless/chrome:latest`. UI used an isolated backend/temporary database without modifying existing user data.
- `dart format lib/ test/`, `flutter analyze --no-pub`, and `flutter test --no-pub --reporter expanded` passed, with 696 full-suite tests. New cases cover defaults/restoration, hydration races, rapid writes, foreground/background, covered routes, unmounting, concurrent lyrics/video ownership and late native completion.
- `flutter build web --no-pub --no-web-resources-cdn --dart-define=DEPLOY_MODE=embedded --output /tmp/songloft-520-flutter-web` passed. Real UI login/playback-settings/toggle saved `flutter.player_lyrics_keep_screen_on` as `true`, with no page errors. Screenshot: `/tmp/songloft-520-flutter-toggle.png`; result: `/tmp/songloft-520-flutter-settings-ui.json`.
- Logs: `/tmp/songloft-520-flutter-{focused,analyze,build,tests-final}.log`. Formatting, diff and UTF-8 checks passed.
- Not run: real Android/iOS/desktop screen-sleep and video handoff acceptance, with no connected devices. Physical Web screen sleep and OS power policy were not validated; screenshots/persistence do not prove these behaviors.

The validation above ran before committing; the user subsequently authorized commits, pushes and an Issue reply. Git records the final commits, and workflows for the same SHA determine subsequent CI/development-package status. This batch does not tag a stable release. Existing v2.13.1 packages do not contain this feature. The reporter's HarmonyOS 4.2 screenshot matches Flutter Android; the actual installation method remains unconfirmed. Lynx HAP targets HarmonyOS NEXT and should not be presented as a direct alternative package for 4.2.
