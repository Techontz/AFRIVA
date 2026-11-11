import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../../core/theme.dart';
import '../../l10n/l10n.dart';
import '../../widgets/buttons.dart';
import '../../widgets/states.dart';

/// Afriva Studio application page on the website, in the app's language.
String studioWebsiteUrl(BuildContext context) {
  final lang = Localizations.localeOf(context).languageCode == 'sw' ? 'sw' : 'en';
  return 'https://studio.afriva.co.tz/$lang/apply/status';
}

/// Human label for an application review status.
String studioStatusLabel(AppLocalizations l, String status) => switch (status) {
      'ready_for_review' => l.studioStatusReady,
      'approved' => l.studioStatusApproved,
      'rejected' => l.studioStatusRejected,
      _ => l.studioStatusPending,
    };

Color studioStatusColor(String status) => switch (status) {
      'approved' => AppColors.success,
      'rejected' => AppColors.danger,
      _ => AppColors.primary,
    };

/// Segmented choice styled like the register screen's email / phone switch.
ButtonStyle studioSegmentStyle() => ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? AppColors.primary : AppColors.surface,
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Colors.white : AppColors.textMuted,
      ),
      side: const WidgetStatePropertyAll(BorderSide.none),
    );

/// Uppercase section heading, matching the settings screen groups.
class StudioSectionLabel extends StatelessWidget {
  const StudioSectionLabel(this.title, {super.key});
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, top: 22, bottom: 10),
        child: Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall!.copyWith(letterSpacing: 1.2),
        ),
      );
}

/// Explains that samples are uploaded on the website and shows the link
/// (selectable, with a copy button, since the app has no URL launcher).
class StudioWebsiteCard extends StatelessWidget {
  const StudioWebsiteCard({super.key, this.showSamples = true});

  final bool showSamples;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    final url = studioWebsiteUrl(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(showSamples ? Icons.video_library_outlined : Icons.language_rounded,
                  color: AppColors.primary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(showSamples ? l.studioSamplesTitle : l.studioWebsiteTitle, style: text.titleSmall),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(showSamples ? l.studioSamplesBody : l.studioWebsiteBody, style: text.bodySmall),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(10),
            ),
            child: SelectableText(url, style: text.bodySmall!.copyWith(color: AppColors.text)),
          ),
          const SizedBox(height: 12),
          PillButton(
            label: l.studioCopyLink,
            icon: Icons.copy_rounded,
            height: 40,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: url));
              Haptics.success();
              if (context.mounted) showSnack(context, l.studioLinkCopied);
            },
          ),
        ],
      ),
    );
  }
}
