import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/built_in_palette.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Device-local color choice; a server theme pack takes precedence when active.
final builtInPaletteProvider =
    AsyncNotifierProvider<BuiltInPaletteNotifier, BuiltInPalette>(
      BuiltInPaletteNotifier.new,
    );

class BuiltInPaletteNotifier extends AsyncNotifier<BuiltInPalette> {
  Future<void> _writes = Future.value();

  @override
  Future<BuiltInPalette> build() async {
    try {
      final preferences = await ref.read(appPreferencesProvider.future);
      return preferences.getBuiltInPalette();
    } catch (_) {
      return BuiltInPalette.blue;
    }
  }

  Future<void> setPalette(BuiltInPalette palette) async {
    if (state.value == null) await future;
    if (!ref.mounted) return;
    state = AsyncData(palette);
    final preferences = ref.read(appPreferencesProvider.future);
    _writes = _writes.then((_) async {
      try {
        final prefs = await preferences;
        await prefs.setBuiltInPalette(palette);
      } catch (error) {
        debugPrint('[Appearance] Failed to save built-in palette: $error');
      }
    });
    await _writes;
  }
}
