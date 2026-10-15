import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/color_extraction.dart';

/// Opaque, surface-based cover tints keep the whole player readable in both modes.
/// No image blur/saveLayer is needed (including on Windows).
class PlayerBackdrop extends StatelessWidget {
  final CoverPalette? palette;
  final Widget child;

  const PlayerBackdrop({super.key, this.palette, required this.child});

  static PlayerBackdropColors colorsOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_BackdropScope>()?.colors ??
      PlayerBackdropColors.fromTheme(Theme.of(context));

  @override
  Widget build(BuildContext context) {
    final colors = PlayerBackdropColors.fromTheme(Theme.of(context), palette);
    return _BackdropScope(
      colors: colors,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors.background,
          ),
        ),
        child: child,
      ),
    );
  }
}

class PlayerBackdropColors {
  final List<Color> background;
  final Color active;
  final Color secondary;

  const PlayerBackdropColors({
    required this.background,
    required this.active,
    required this.secondary,
  });

  factory PlayerBackdropColors.fromTheme(
    ThemeData theme, [
    CoverPalette? palette,
  ]) {
    final scheme = theme.colorScheme;
    final extension = theme.extension<SongloftThemeExtension>();
    final highContrast = extension?.increaseContrast ?? false;
    final gradient = extension?.playerGradientColors;
    // Missing/loading/failed covers all use the theme, never metadata hash colors.
    final top =
        palette?.dominantColor ?? gradient?.firstOrNull ?? scheme.primary;
    final bottom =
        palette?.mutedColor ?? gradient?.lastOrNull ?? scheme.tertiary;
    final dark = theme.brightness == Brightness.dark;
    Color tint(Color color, double opacity) =>
        Color.alphaBlend(color.withValues(alpha: opacity), scheme.surface);
    final background =
        highContrast
            ? [scheme.surface, scheme.surface]
            : [tint(top, dark ? .18 : .12), tint(bottom, dark ? .08 : .04)];
    return PlayerBackdropColors(
      background: background,
      // Keep an accent hue where possible, strengthening it toward onSurface.
      active: _readable(scheme.primary, scheme.onSurface, background, 7),
      secondary: _readable(
        Color.lerp(background.first, scheme.onSurface, .68)!,
        scheme.onSurface,
        background,
        highContrast ? 7 : 4.5,
      ),
    );
  }

  static double _contrast(Color a, Color b) {
    final values = [a.computeLuminance(), b.computeLuminance()]..sort();
    return (values.last + .05) / (values.first + .05);
  }

  static Color _readable(
    Color preferred,
    Color foreground,
    List<Color> backgrounds,
    double minimum,
  ) {
    for (var step = 0; step <= 20; step++) {
      final candidate = Color.lerp(preferred, foreground, step / 20)!;
      if (backgrounds.every((bg) => _contrast(candidate, bg) >= minimum)) {
        return candidate;
      }
    }
    return foreground;
  }
}

class _BackdropScope extends InheritedWidget {
  final PlayerBackdropColors colors;

  const _BackdropScope({required this.colors, required super.child});

  @override
  bool updateShouldNotify(_BackdropScope oldWidget) =>
      colors != oldWidget.colors;
}
