import 'package:material_ui/material_ui.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../models/studio.dart';

/// Review status chip: Rasimu · Imetumwa · Inakaguliwa · Marekebisho · Imeidhinishwa · Imekataliwa.
class ReviewStatusChip extends StatelessWidget {
  const ReviewStatusChip(this.status, {super.key, this.live = false});

  final String? status;

  /// Approved and published: shown as "Live".
  final bool live;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (status) {
      ReviewStatus.submitted => (const Color(0xFFE8F0FE), const Color(0xFF1A56DB)),
      ReviewStatus.inReview => (const Color(0xFFFFF4D6), const Color(0xFF8A5A00)),
      ReviewStatus.changesRequested => (const Color(0xFFFFE8D6), const Color(0xFFB54708)),
      ReviewStatus.approved => (const Color(0xFFE3F6EA), const Color(0xFF16794A)),
      ReviewStatus.rejected => (const Color(0xFFFDE7EA), AppColors.primary),
      _ => (AppColors.surface2, AppColors.chipText),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadii.pill)),
      child: Text(
        live ? '${ReviewStatus.label(status)} · Live' : ReviewStatus.label(status),
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }
}

/// The four steps of scope §04, shown to creators so they know upload ≠ published.
class SubmissionSteps extends StatelessWidget {
  const SubmissionSteps({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final steps = [
      ('1', ReviewStatus.label(ReviewStatus.submitted), context.tr('Send your series, episodes, cover, trailer and description.')),
      ('2', ReviewStatus.label(ReviewStatus.inReview), context.tr('AFRIVA checks quality, rights and playback.')),
      ('3', ReviewStatus.label(ReviewStatus.changesRequested), context.tr('If something needs fixing you get notes and send a new version.')),
      ('4', ReviewStatus.label(ReviewStatus.approved), context.tr('AFRIVA sets the date, price and free episodes, then publishes.')),
    ];
    return Column(
      children: [
        for (final (n, title, body) in steps)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(radius: 13, backgroundColor: AppColors.primary, child: Text(n, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800))),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: text.titleSmall),
                      Text(body, style: text.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
