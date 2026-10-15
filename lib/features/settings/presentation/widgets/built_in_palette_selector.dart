import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/built_in_palette.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/built_in_palette_provider.dart';
import '../providers/theme_pack_provider.dart';

class BuiltInPaletteSelector extends ConsumerWidget {
  const BuiltInPaletteSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(builtInPaletteProvider).value;
    final themePack = ref.watch(activeThemePackProvider);
    final packActive = themePack.value != null;
    final enabled = selected != null && !themePack.isLoading && !packActive;
    final l10n = AppLocalizations.of(context);
    final labels = {
      BuiltInPalette.blue: l10n.themePaletteBlue,
      BuiltInPalette.teal: l10n.themePaletteTeal,
      BuiltInPalette.forest: l10n.themePaletteForest,
      BuiltInPalette.rose: l10n.themePaletteRose,
      BuiltInPalette.amber: l10n.themePaletteAmber,
      BuiltInPalette.violet: l10n.themePaletteViolet,
    };
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.themePaletteTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            packActive
                ? l10n.themePalettePackHint
                : l10n.themePaletteDescription,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final palette in BuiltInPalette.values)
                ChoiceChip(
                  label: Text(labels[palette]!),
                  avatar: CircleAvatar(
                    backgroundColor:
                        ColorScheme.fromSeed(
                          seedColor: palette.seedColor,
                          brightness: Theme.of(context).brightness,
                        ).primary,
                    radius: 8,
                  ),
                  selected: !packActive && selected == palette,
                  onSelected:
                      enabled
                          ? (_) => ref
                              .read(builtInPaletteProvider.notifier)
                              .setPalette(palette)
                          : null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
