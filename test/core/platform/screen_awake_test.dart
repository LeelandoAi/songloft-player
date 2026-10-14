import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songloft_flutter/core/platform/screen_awake.dart';

void main() {
  test('releasing lyrics preserves a concurrent video request', () async {
    final calls = <bool>[];
    final controller = ScreenAwakeController((value) async => calls.add(value));
    final lyrics = Object();
    final video = Object();
    await controller.update(lyrics, true);
    await controller.update(video, true);
    await controller.update(lyrics, false);
    expect(calls.last, isTrue);
    await controller.update(video, false);
    expect(calls.last, isFalse);
  });

  test('late native acquisition cannot outlive a release', () async {
    final pending = Completer<void>();
    final calls = <bool>[];
    final controller = ScreenAwakeController((value) async {
      calls.add(value);
      if (calls.length == 1) await pending.future;
    });
    final owner = Object();
    final acquiring = controller.update(owner, true);
    await Future<void>.delayed(Duration.zero);
    final releasing = controller.update(owner, false);
    pending.complete();
    await Future.wait([acquiring, releasing]);
    expect(calls, [true, false]);
  });

  testWidgets(
    'foreground lyrics acquire; background, covered route and unmount release',
    (tester) async {
      final calls = <bool>[];
      final controller = ScreenAwakeController(
        (value) async => calls.add(value),
      );
      final navigator = GlobalKey<NavigatorState>();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            screenAwakeControllerProvider.overrideWithValue(controller),
          ],
          child: MaterialApp(
            navigatorKey: navigator,
            navigatorObservers: [screenAwakeRouteObserver],
            home: const ScreenAwakeScope(enabled: true, child: Text('lyrics')),
          ),
        ),
      );
      await tester.pump();
      expect(calls.last, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(calls.last, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(calls.last, isTrue);
      unawaited(
        navigator.currentState!.push(
          MaterialPageRoute<void>(builder: (_) => const Text('settings')),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls.last, isFalse);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(calls.last, isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(calls.last, isFalse);
    },
  );

  testWidgets('switching away from lyrics releases without unmounting', (
    tester,
  ) async {
    final calls = <bool>[];
    final controller = ScreenAwakeController((value) async => calls.add(value));
    Future<void> render(bool enabled) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            screenAwakeControllerProvider.overrideWithValue(controller),
          ],
          child: MaterialApp(
            home: ScreenAwakeScope(
              enabled: enabled,
              child: const Text('player'),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await render(true);
    expect(calls.last, isTrue);
    await render(false);
    expect(calls.last, isFalse);
  });
}
