import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/platform/screen_awake.dart';
import '../../../settings/presentation/providers/lyrics_keep_screen_on_provider.dart';

class LyricsScreenAwake extends ConsumerWidget {
  const LyricsScreenAwake({
    super.key,
    required this.visible,
    required this.child,
  });

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ScreenAwakeScope(
    enabled: visible && ref.watch(lyricsKeepScreenOnProvider),
    child: child,
  );
}
