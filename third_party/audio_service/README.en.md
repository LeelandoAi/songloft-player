# Local audio_service patch

Source: pub.dev `audio_service 0.18.19`. The MIT license and original runtime sources (`lib/`, `android/`, `darwin/`) are retained. `audio_service_web` and the platform interface remain upstream dependencies. See [README.md](README.md) for Chinese.

Related to [songloft-org/songloft#520](https://github.com/songloft-org/songloft/issues/520): with `androidStopForegroundOnPause=false`, a MediaBrowser client in the app keeps the service bound, so `stopSelf()` does not immediately trigger `onDestroy()`. Upstream `stop()` cancels a notification that is still in the foreground, leaving the notification and playback wake lock held.

Apart from removing a few upstream trailing spaces, only Android `AudioService.stop()` is changed: call `ServiceCompat.stopForeground(..., STOP_FOREGROUND_REMOVE)` and release the playback wake lock before the existing media-session deactivation and `stopSelf()`. Pause behavior is preserved; subsequent playback uses the existing foreground start path. The Dart handler also rejects late events and load results after stopping.

A complete APK is required: Dart hot updates cannot change the old shell's native service. When updating upstream, review `stop()`, `onDestroy()`, foreground and wake-lock lifecycles before removing this override. See the [Issue 520 validation record](../../docs/en/issue-520.md).
