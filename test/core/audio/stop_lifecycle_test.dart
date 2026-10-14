import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:songloft_flutter/core/audio/audio_service.dart';
import 'package:songloft_flutter/shared/models/song.dart';

class _Player implements ja.AudioPlayer {
  final events = StreamController<ja.PlaybackEvent>.broadcast(sync: true);
  final states = StreamController<ja.ProcessingState>.broadcast(sync: true);
  final playingEvents = StreamController<bool>.broadcast(sync: true);
  @override
  bool playing = true;
  @override
  ja.ProcessingState processingState = ja.ProcessingState.ready;
  int playCalls = 0;
  final sourceStarted = Completer<void>();
  final sourceLoaded = Completer<Duration?>();
  @override
  Future<Duration?> setAudioSource(
    ja.AudioSource source, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
  }) {
    sourceStarted.complete();
    return sourceLoaded.future;
  }

  bool failStop = false;
  @override
  Stream<ja.PlaybackEvent> get playbackEventStream => events.stream;
  @override
  Stream<ja.ProcessingState> get processingStateStream => states.stream;
  @override
  Stream<bool> get playingStream => playingEvents.stream;
  @override
  Duration get position => Duration.zero;
  @override
  Duration get bufferedPosition => Duration.zero;
  @override
  double get speed => 1;
  @override
  Future<void> stop() async {
    if (failStop) throw StateError('stop failed');
    playing = false;
  }

  @override
  Future<void> play() async {
    playCalls++;
    playing = true;
    playingEvents.add(true);
  }

  void emit(ja.ProcessingState state) {
    processingState = state;
    states.add(state);
    events.add(ja.PlaybackEvent(processingState: state));
  }

  @override
  Future<void> dispose() async {
    await events.close();
    await states.close();
    await playingEvents.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final failStop in [false, true]) {
    test(
      'late events cannot resurrect stopped session (failure=$failStop)',
      () async {
        final player = _Player()..failStop = failStop;
        final handler = SongloftAudioHandler(player: player);
        addTearDown(handler.dispose);
        var completed = 0;
        handler.onSongCompleted = () => completed++;
        if (failStop) {
          await expectLater(handler.stop(), throwsStateError);
        } else {
          await handler.stop();
        }
        for (final state in [
          ja.ProcessingState.ready,
          ja.ProcessingState.completed,
        ]) {
          player.emit(state);
          player.playingEvents.add(true);
          expect(
            handler.playbackState.value.processingState,
            AudioProcessingState.idle,
          );
          expect(handler.playbackState.value.playing, false);
        }
        expect(completed, 0);
        await handler.play();
        player.emit(ja.ProcessingState.ready);
        expect(player.playCalls, 1);
        expect(handler.playbackState.value.playing, true);
        expect(
          handler.playbackState.value.processingState,
          AudioProcessingState.ready,
        );
      },
    );
  }

  test(
    'stop invalidates song load waiting for session initialization',
    () async {
      final player = _Player();
      final handler = SongloftAudioHandler(player: player);
      addTearDown(handler.dispose);
      final song = Song(
        id: 1,
        type: 'local',
        title: 'test',
        duration: 10,
        url: '/api/v1/songs/1/play',
        addedAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      final loading = handler.playSong(song);
      await handler.stop();
      await loading;
      expect(player.playCalls, 0);
      expect(
        handler.playbackState.value.processingState,
        AudioProcessingState.idle,
      );
    },
  );
  test('a pending source finishing after stop cannot auto-play', () async {
    final player = _Player();
    final handler = SongloftAudioHandler(player: player);
    addTearDown(handler.dispose);
    await handler.ensureInitialized();
    final song = Song(
      id: 99,
      type: 'local',
      title: 'pending',
      duration: 10,
      url: '/api/v1/songs/99/play',
      addedAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final loading = handler.playSong(song);
    await player.sourceStarted.future.timeout(const Duration(seconds: 5));
    await handler.stop();
    player.emit(ja.ProcessingState.ready);
    player.sourceLoaded.complete(const Duration(seconds: 10));
    await loading;
    expect(player.playCalls, 0);
    expect(
      handler.playbackState.value.processingState,
      AudioProcessingState.idle,
    );
  });
}
