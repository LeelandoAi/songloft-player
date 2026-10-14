import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';

/// Device-local opt-in. Hydration must not overwrite a new user choice.
class LyricsKeepScreenOnNotifier extends Notifier<bool> {
  bool _userTouched = false;
  Future<void> _writes = Future<void>.value();

  @override
  bool build() {
    _userTouched = false;
    _load();
    return false;
  }

  Future<void> _load() async {
    try {
      final prefs = await ref.read(appPreferencesProvider.future);
      if (ref.mounted && !_userTouched) {
        state = prefs.getLyricsKeepScreenOn();
      }
    } catch (_) {}
  }

  Future<void> setEnabled(bool enabled) {
    _userTouched = true;
    state = enabled;
    final preferences = ref.read(appPreferencesProvider.future);
    _writes = _writes.then((_) async {
      try {
        final prefs = await preferences;
        await prefs.setLyricsKeepScreenOn(enabled);
      } catch (_) {}
    });
    return _writes;
  }
}

final lyricsKeepScreenOnProvider =
    NotifierProvider<LyricsKeepScreenOnNotifier, bool>(
      LyricsKeepScreenOnNotifier.new,
    );
