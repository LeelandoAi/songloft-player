import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songloft_flutter/core/audio/audio_service.dart';

void main() {
  for (final playing in [true, false]) {
    for (final favoriteSupported in [true, false]) {
      test(
        'stop is available in both notification lists ($playing/$favoriteSupported)',
        () {
          final controls = SongloftAudioHandler.buildMediaControls(
            playing: playing,
            favoriteSupported: favoriteSupported,
            favorited: true,
          );
          // Android 12 and earlier build NotificationCompat actions from these.
          final notification =
              controls.where((c) => c.customAction == null).toList();
          expect(notification.map((c) => c.action), [
            MediaAction.skipToPrevious,
            playing ? MediaAction.pause : MediaAction.play,
            MediaAction.skipToNext,
            MediaAction.stop,
          ]);
          // audio_service automatically converts the standard STOP on Android
          // 13+. An explicit custom stop would disappear on older Android or
          // duplicate the system action on newer Android.
          final stops =
              controls.where((c) => c.action == MediaAction.stop).toList();
          expect(stops, hasLength(1));
          expect(stops.single.customAction, isNull);
        },
      );
    }
  }
}
