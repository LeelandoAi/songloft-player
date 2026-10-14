# Keep Screen On for Lyrics · songloft-org/songloft#520

2026-10-14. Scope: the client screen-awake preference. Exit/task-removal behavior is deferred at the user's request.

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
