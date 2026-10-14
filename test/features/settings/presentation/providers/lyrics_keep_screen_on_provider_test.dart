import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songloft_flutter/core/storage/app_preferences.dart';
import 'package:songloft_flutter/features/auth/presentation/providers/auth_provider.dart';
import 'package:songloft_flutter/features/settings/presentation/providers/lyrics_keep_screen_on_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> load(ProviderContainer container) async {
    container.read(lyricsKeepScreenOnProvider);
    await container.read(appPreferencesProvider.future);
    await Future<void>.delayed(Duration.zero);
  }

  test('off by default; persists across containers', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await load(container);
    expect(container.read(lyricsKeepScreenOnProvider), isFalse);
    await container.read(lyricsKeepScreenOnProvider.notifier).setEnabled(true);
    final restored = ProviderContainer();
    addTearDown(restored.dispose);
    await load(restored);
    expect(restored.read(lyricsKeepScreenOnProvider), isTrue);
  });

  test(
    'late hydration and rapid writes preserve the final user choice',
    () async {
      final pending = Completer<AppPreferences>();
      final container = ProviderContainer(
        overrides: [
          appPreferencesProvider.overrideWith((ref) => pending.future),
        ],
      );
      addTearDown(container.dispose);
      container.read(lyricsKeepScreenOnProvider);
      final notifier = container.read(lyricsKeepScreenOnProvider.notifier);
      final writes = [
        notifier.setEnabled(true),
        notifier.setEnabled(false),
        notifier.setEnabled(true),
      ];
      pending.complete(await AppPreferences.create());
      await Future.wait(writes);
      expect(container.read(lyricsKeepScreenOnProvider), isTrue);
      expect((await AppPreferences.create()).getLyricsKeepScreenOn(), isTrue);
    },
  );
}
