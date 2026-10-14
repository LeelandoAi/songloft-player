import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songloft_flutter/features/playlist/presentation/widgets/playlist_song_tile.dart';
import 'package:songloft_flutter/l10n/app_localizations.dart';
import 'package:songloft_flutter/shared/models/song.dart';

void main() {
  final now = DateTime.utc(2026, 10, 14);
  final song = Song(
    id: 101,
    type: 'local',
    title: '夜曲',
    duration: 200,
    addedAt: now,
    updatedAt: now,
  );

  Future<void> pumpTile(
    WidgetTester tester, {
    bool selection = false,
    String? initial,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: PlaylistSongTile(
              song: song,
              index: 101,
              titleInitial: initial,
              onTap: () {},
              onRemove: () {},
              showCheckbox: selection,
              showTrailing: false,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('首字母提示与序号共存，后续同组行只显示序号', (tester) async {
    await pumpTile(tester, initial: 'Y');
    expect(find.text('Y'), findsOneWidget);
    expect(find.text('101'), findsOneWidget);
    await pumpTile(tester);
    expect(find.text('Y'), findsNothing);
    expect(find.text('101'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('多选时仍使用复选框', (tester) async {
    await pumpTile(tester, initial: 'Y', selection: true);
    expect(find.byType(Checkbox), findsOneWidget);
    expect(find.text('Y'), findsNothing);
    expect(find.text('101'), findsNothing);
  });
}
