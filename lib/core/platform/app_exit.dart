import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appExitControllerProvider = Provider<AppExitController?>((ref) => null);

/// One exit transaction shared by Settings and Android task removal.
/// Cleanup failures must not leave the other services running.
class AppExitController {
  AppExitController({
    required this.stopPlayback,
    required this.closeLyrics,
    required this.stopBackend,
    required this.finishApp,
  });

  final Future<void> Function() stopPlayback;
  final Future<void> Function() closeLyrics;
  final Future<void> Function() stopBackend;
  final Future<void> Function() finishApp;
  Future<void>? _pending;

  Future<void> exit() => _pending ??= _exit();

  Future<void> _exit() async {
    for (final cleanup in [stopPlayback, closeLyrics, stopBackend, finishApp]) {
      try {
        await cleanup().timeout(const Duration(seconds: 5));
      } catch (error, stack) {
        debugPrint('[AppExit] $error\n$stack');
      }
    }
  }
}
