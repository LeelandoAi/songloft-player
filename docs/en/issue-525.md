# Issue #525: Large playback queue stalls

Related: [songloft-org/songloft#525](https://github.com/songloft-org/songloft/issues/525). Reported environment: Docker backend 2.13.3, Windows/mobile clients, approximately 30,000 songs.

## Behavior and implementation

Two sources of large-queue work were confirmed. The mobile sheet and desktop drawer calculated automatic positioning with a fixed height without providing an extent to `ReorderableListView.builder`. Distant jumps could lay out many intermediate rows, creating their cover and title widgets. Separately, `PlayQueue.add` scanned the entire queue for each incoming song, increasing synchronous work during background loading.

Both lists now use `itemExtent` to calculate visible indices directly, sharing their extent with automatic positioning and the mobile scrollbar. The extent grows with the actual font metrics and text scaling. Queue headers also constrain long English titles alongside large count badges. Appends deduplicate with an `(id, type)` set while retaining batch order, existing duplicates, and the current index.

## Tested object and environment

- Date: 2026-10-15. Parent baseline: `f9c17dc9ee6a98652a929c238be142e2b33fd817`. Flutter baseline: `00cbe94841acca3eaf561a339f61072914c9de31` plus this uncommitted worktree. File, diff, and build hashes: `/tmp/songloft-525/validation.json`.
- Linux amd64; Flutter **3.44.8** stable, Dart **3.12.2** (the installation directory is still named `3.41.5`; the tool output determines the version); Docker browserless Chrome.
- The backend is a `dev,lite` binary built from the parent baseline, using a temporary SQLite database initialized by real migrations and seeded with 30,000 synthetic songs. Audio is generated silent WAV, covers are generated PNG. No private music library was used.

## Automated checks

| Check | Result and evidence |
|---|---|
| `dart format lib/ test/`, `git diff --check` | Passed, no remaining format differences |
| `flutter test --no-pub` | 728 passed, `/tmp/songloft-525/all-tests.log` |
| `flutter analyze --no-pub` | Passed, `analyze-final.log` |
| From parent: `bash clients/player/scripts/build-frontend.sh web-embedded /tmp/songloft-525/build` | Passed, `build.log` |
| Old-source regressions | An isolated baseline project from `git archive` hit the 200-row guard when opening either list at song 15,001. Appending 100 songs read IDs 6,000,000 times, exceeding the 30,100 limit. Logs: `before-layout.log`, `before-mobile.log`, `before-add.log` |
| Fixed regressions | Opening at the beginning, middle, and end and following distant track changes each read fewer than 100 entries. Coverage includes Chinese/English, 2× text, drag reorder, play/remove callbacks. Real queue value-object tests cover duplicates within/across batches and ordering |

## Actual browser checks

- English desktop at 1200×900 and Chinese mobile layout at 390×900 each restore all 30,000 songs and open the queue while playing song 15,001 or 30,000. The current item is visible, the count is 30000, and the queue can be closed for further interaction. Cumulative cover requests: 39, 36, 24, and 22. No page exceptions.
- Actual `HTMLMediaElement` references, including detached elements, confirm playback remains unpaused and advances to approximately 4.9–5.7 seconds after opening/closing. Screenshots verify layout and covers only.
- Clicking library “Play all” loads all 30,000 songs through the existing initial batch of 10 and background batches of 100, then opens the desktop queue with a count of 30000. This synthetic local run took approximately 86.7 seconds to load in the background; this is not a device performance guarantee.
- Evidence: `/tmp/songloft-525/browser-results.json`, `browser-mobile.log`, `queue-{en,zh}-{15000,29999}.png`, `playall-fixed.log`, `playall-queue.json`, and `playall-queue.png`. The harness captured media-element references without adding product test interfaces.
- An exploratory full-load probe using an existing old Web artifact timed out after 120 seconds (`baseline-playall-4.log`). That artifact was not bound to the baseline SHA; it is neither a native freeze reproduction nor a same-SHA comparison. Isolated source tests provide the deterministic negative verification.

## Boundaries and delivery

Not run: native Windows/Android builds, the reporter's devices and private library; these target devices are unavailable locally. Full backend tests are not applicable: backend code and APIs are unchanged. Browser and Widget checks exercise shared Flutter list behavior and do not replace native acceptance.

Changes are confined to the Flutter repository, committed to local `main` with the user's authorization, followed by a parent gitlink commit. Git records provide the exact SHAs. No push, release, or Issue comment is authorized in this batch. Commit: `fix(player): 优化大播放队列定位与批量追加 songloft-org/songloft#525`.
