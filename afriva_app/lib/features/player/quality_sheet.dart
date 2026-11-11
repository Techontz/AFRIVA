import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/haptics.dart';
import '../../core/hls.dart';
import '../../core/theme.dart';
import '../../l10n/l10n.dart';
import '../../state/settings_state.dart';
import '../../widgets/sheet.dart';

/// Quality picker: Auto plus each rendition of the current episode. The
/// choice is saved as the preferred quality for the next episodes too.
Future<void> showQualitySheet(BuildContext context, {required List<HlsVariant> variants}) {
  final settings = context.read<SettingsState>();
  return showAfrivaSheet<void>(
    context,
    builder: (ctx) {
      final l = ctx.l10n;
      final text = Theme.of(ctx).textTheme;
      final current = settings.videoQuality;
      // A saved height this episode lacks still marks its closest rendition.
      final shown = pickVariant(variants, current)?.height ?? 0;
      Widget option(int height, String label, {String? subtitle}) => ListTile(
            title: Text(label, style: text.titleSmall),
            subtitle: subtitle == null ? null : Text(subtitle, style: text.labelSmall),
            trailing: shown == height
                ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
                : Icon(Icons.circle_outlined, color: AppColors.textDim),
            onTap: () {
              Haptics.tap();
              settings.setVideoQuality(height);
              Navigator.pop(ctx);
            },
          );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(l.playerQuality, style: text.titleMedium),
          ),
          option(0, l.qualityAuto, subtitle: l.qualityAutoSubtitle),
          for (final v in variants) option(v.height, v.label),
        ],
      );
    },
  );
}
