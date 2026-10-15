import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songloft_flutter/features/player/domain/playback_context.dart';
import 'package:songloft_flutter/features/player/domain/player_state.dart';
import 'package:songloft_flutter/features/player/presentation/providers/player_provider.dart';
import 'package:songloft_flutter/features/player/presentation/queue_page.dart';
import 'package:songloft_flutter/features/player/presentation/widgets/playlist_drawer.dart';
import 'package:songloft_flutter/features/settings/presentation/providers/song_title_scrolling_provider.dart';
import 'package:songloft_flutter/l10n/app_localizations.dart';
import 'package:songloft_flutter/shared/models/song.dart';

// Count accesses instead of wall time: a distant jump must not build every
// intervening row. The guard bounds the regression's cost on the old layout.
class _Songs extends ListBase<Song> {
  final List<Song> values = List.generate(
    30000,
    (i) => Song(
      id: i,
      type: 'local',
      title: 'Song $i',
      artist: 'Artist $i',
      duration: 180,
      addedAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  );
  int reads = 0;
  @override
  int get length => values.length;
  @override
  set length(int value) => throw UnsupportedError('read only');
  @override
  Song operator [](int index) {
    reads++;
    if (reads > 200) throw StateError('Queue built over 200 rows');
    return values[index];
  }

  @override
  void operator []=(int index, Song value) =>
      throw UnsupportedError('read only');
}

class _Player extends PlayerNotifier {
  _Player(this.initial);
  final PlayerState initial;
  final moves = <(int, int)>[];
  int? removed;
  int? played;
  @override
  PlayerState build() => initial;
  void select(int index) =>
      state = state.copyWith(
        currentIndex: index,
        currentSong: state.playlist[index],
      );

  @override
  void moveInPlaylist(int oldIndex, int insertIndex) =>
      moves.add((oldIndex, insertIndex));

  @override
  Future<void> removeFromPlaylist(int index) async => removed = index;

  @override
  Future<void> playPlaylist(
    List<Song> songs, {
    int startIndex = 0,
    int? sourcePlaylistId,
    PlaybackContext? context,
    bool keepContext = false,
  }) async => played = startIndex;
}

class _StaticTitles extends SongTitleScrollingNotifier {
  @override
  bool build() => false;
}

void main() {
  for (final drawer in [true, false]) {
    final name = drawer ? 'desktop drawer' : 'mobile sheet';
    for (final (index, scale, language) in [
      (0, 1.0, 'zh'),
      (15000, 1.0, 'zh'),
      (29999, 1.0, 'zh'),
      (29999, 1.0, 'en'),
      (15000, 2.0, 'en'),
    ]) {
      testWidgets(
        '$name opens 30k queue at $index ($language, scale $scale) with bounded row builds',
        (tester) async {
          tester.view.physicalSize =
              drawer ? const Size(1200, 900) : const Size(390, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final songs = _Songs();
          final player = _Player(
            PlayerState(
              playlist: songs,
              currentIndex: index,
              currentSong: songs.values[index],
            ),
          );
          final container = ProviderContainer(
            overrides: [
              playerStateProvider.overrideWith(() => player),
              songTitleScrollingProvider.overrideWith(_StaticTitles.new),
            ],
          );
          addTearDown(container.dispose);
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                locale: Locale(language),
                builder:
                    (context, child) => MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(textScaler: TextScaler.linear(scale)),
                      child: child!,
                    ),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body:
                      drawer
                          ? const Align(
                            alignment: Alignment.centerRight,
                            child: PlaylistDrawer(),
                          )
                          : const QueueBottomSheet(),
                ),
              ),
            ),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
          expect(songs.reads, lessThan(100));
          expect(find.text('Song $index'), findsOneWidget);
          final rect = tester.getRect(find.text('Song $index'));
          expect(rect.top, greaterThanOrEqualTo(0));
          expect(rect.bottom, lessThanOrEqualTo(900));
          if (index == 15000 && scale == 1) {
            await tester.tap(find.text('Song $index'));
            expect(player.played, index);
            final row = find.ancestor(
              of: find.text('Song $index'),
              matching: find.byType(Dismissible),
            );
            final handle = find.descendant(
              of: row,
              matching: find.byType(ReorderableDragStartListener),
            );
            final gesture = await tester.startGesture(tester.getCenter(handle));
            await gesture.moveBy(const Offset(0, 140));
            await tester.pump(const Duration(milliseconds: 100));
            await gesture.up();
            await tester.pump(const Duration(milliseconds: 350));
            expect(player.moves.single.$1, index);
            expect(player.moves.single.$2, greaterThan(index));
            await tester.tap(
              find.descendant(
                of: row,
                matching: find.byIcon(Icons.close_rounded),
              ),
            );
            expect(player.removed, index);
            expect(tester.takeException(), isNull);
          }
          songs.reads = 0;
          final next = index == 0 ? 29999 : 0;
          player.select(next);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));
          await tester.pump();
          expect(tester.takeException(), isNull);
          expect(songs.reads, lessThan(100));
          expect(find.text('Song $next'), findsOneWidget);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
