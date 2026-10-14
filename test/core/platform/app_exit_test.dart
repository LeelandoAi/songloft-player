import 'package:flutter_test/flutter_test.dart';

import 'package:songloft_flutter/core/platform/app_exit.dart';

void main() {
  test(
    'duplicate exit requests clean each resource once, before finishing',
    () async {
      final calls = <String>[];
      final exit = AppExitController(
        stopPlayback: () async => calls.add('audio'),
        closeLyrics: () async => calls.add('lyrics'),
        stopBackend: () async => calls.add('backend'),
        finishApp: () async => calls.add('finish'),
      );
      await Future.wait([exit.exit(), exit.exit()]);
      expect(calls, ['audio', 'lyrics', 'backend', 'finish']);
    },
  );

  test('a failed player stop still closes overlays, backend and app', () async {
    final calls = <String>[];
    final exit = AppExitController(
      stopPlayback: () async => throw StateError('player stop failed'),
      closeLyrics: () async => calls.add('lyrics'),
      stopBackend: () async => calls.add('backend'),
      finishApp: () async => calls.add('finish'),
    );
    await exit.exit();
    expect(calls, ['lyrics', 'backend', 'finish']);
  });
}
