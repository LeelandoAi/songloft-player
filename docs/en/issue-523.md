# Lyric Readability and Built-in Palettes · songloft-org/songloft#523

2026-10-15, related to [songloft-org/songloft#523](https://github.com/songloft-org/songloft/issues/523). This batch updates the Flutter mobile and desktop full players and appearance settings.

## 2026-10-16 · Solid Background Feedback

Delivery authorization: on 2026-10-16 the user authorized this batch's commits, pushes and a reply to songloft-org/songloft#523. Uncommitted/unposted states below are validation snapshots; Git/GitHub records for the same SHA determine final commits, CI and the comment. No stable tag or Issue closure.

For the [follow-up comment](https://github.com/songloft-org/songloft/issues/523#issuecomment-6210432894), checked current `bb03a5c49eb6701d90a73b924ed12ec388c6560c`: increased contrast deliberately uses a solid surface in the player. App and system high contrast combine with OR; disabling the app toggle cannot override the system. Flutter's Reduce Transparency affects glass materials and does not independently disable this cover-tinted gradient.

A temporary Flutter test runs the actual `AppTheme` and `PlayerBackdropColors`, confirming a cover tint in normal mode and a solid background with increased contrast. The screenshots are consistent with the accessibility path, but the reporter's settings, installed versions and native Flutter behavior remain unconfirmed; this does not establish their device's cause or a functional fix.

This change only clarifies the contrast description in Chinese, English and Spanish, including generated localizations, while preserving the existing policy. Evidence: `/tmp/songloft-523-followup/`, with final validation objects, commands and results in `validation.json`. Copy changes add no regression tests; old-implementation failure checks are inapplicable. Not run: native devices, outdoor use and the reporter's library. No commit, push, release or Issue reply.

Validation: Linux amd64 / Flutter 3.44.8 / Dart 3.12.2; formatting, analysis, 19 relevant tests, embedded Web and Go embedding builds pass. Docker Chrome displays both Chinese and English switch descriptions without page exceptions. The first test command named two nonexistent files; the corrected command passes all 19 tests, and the original failure is retained in the evidence directory.

## Behavior and Cause

- The original full-player background combined cover art, darkMutedColor, theme gradients, and a black top overlay, while lyrics directly used the theme primary. Light-mode backgrounds became dark without coordinated foreground colors. Translations and romaji further reduced contrast with extra opacity.
- Mobile and desktop share `PlayerBackdrop`: cover colors blend into the theme surface as a soft gradient, without full-screen image blur or a black top overlay. Windows uses the same gradient, avoiding the historical saveLayer issue.
- Missing, loading, and failed covers use the theme gradient, without metadata-generated fallback colors. Theme-pack playerGradient endpoints provide the default; available cover colors take precedence. Increased contrast uses a solid surface.
- Active lines, translations, romaji, and karaoke share a strengthened theme accent targeting 7:1 contrast; other lyrics target 4.5:1. Top text and buttons use onSurface.
- Appearance offers Blue, Teal, Forest, Rose, Amber, and Violet for light/dark/system modes. Device preference `built_in_palette` is outside server synchronization. Server theme packs take precedence; restoring the default resumes the saved device palette. Chinese, English, and Spanish localization outputs are generated.

## Validation Object

- `songloft-org/songloft-player` baseline `b80e03b47eefb1aaedf07d611b1d9d3c3d48257b` plus uncommitted worktree, source identifier `1eac2d6a16e45e318fe1325d5f29db00e965279c3429a99d1c7c0b3385bc8185`. Algorithm: SHA-256 of `git diff --binary -- lib test`, followed by sorted untracked lib/test paths, NUL, contents, NUL. Documentation excluded.
- Parent baseline `9d008b8026abb56a2ee3aae29f71017460bcc1af`; this batch only updates related bilingual documentation there. The submodule remains dirty, without a new committed gitlink.
- Linux amd64, Flutter 3.41.5, Web embedded, Docker browserless/Chrome 121. Temporary database and synthetic WAV, covers, and lyrics; no user library changes.

## Validation Results

- `dart format lib/ test/` and `flutter analyze --no-pub` passed; all 716 tests passed with `flutter test --no-pub`. The expanded two new test files passed 8 tests, covering six palettes, both brightness modes, extreme covers, gradient samples, increased contrast, translated/karaoke highlights, initialization, rapid writes, restoration, theme-pack precedence, and actual App switching.
- An isolated copy using only the baseline `lyrics_view.dart` failed both brightness-mode rendering regressions as expected: the active line at 5.17:1 and translation at 5.82:1 missed the 7:1 target. These were assertion failures, not compilation failures. The original worktree was not reverted.
- `make build-frontend-web-embedded` and `go build -tags dev -o /tmp/songloft-523/server .` passed.
- Full browser results: `/tmp/songloft-523/browser-results.json`; background pixel comparisons: `background-pixels.json`. Chinese mobile/light and English desktop/dark navigate from the home screen into the player, switch coral/ocean/missing/failed covers, and inspect lyrics, fallback backgrounds, and toolbars. Selecting Rose is checked in localStorage, then restored selection is checked after reloading the root and navigating back in-app. Screenshots: `zh-light-*.png`, `en-dark-*.png`, and `*-settings-rose.png` in the same directory.
- Logs and worktree identity: `/tmp/songloft-523/{validation.json,analyze-final.log,all-tests.log,expanded-tests.log,before-lyrics.log,web-build.log,browser.log}`.
- Not run: Android/iOS/Windows/macOS/Linux native builds and outdoor device acceptance. No native bridge, audio, or backend API changes. Web checks do not replace native device acceptance.

## Screenshots and Delivery

Representative originals: [mobile light lyrics](../assets/issue-523/light.png) · [desktop dark lyrics](../assets/issue-523/dark.png) · [Rose appearance settings](../assets/issue-523/palette.png). All 59 cross-client screenshots and validation records remain in `/home/hanxi/work/songloft-review/issue-523-lynx-20261015/`.

On 2026-10-15, the user authorized commits, pushes and a reply to songloft-org/songloft#523. Commit both clients before updating parent gitlinks. Working-tree states above are validation snapshots; Git and CI for the same SHA determine final commits/development packages. No stable tag or Issue closure in this batch.
