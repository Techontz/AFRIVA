import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';
import '../l10n/l10n.dart';

/// Localized label for a drama badge: Hot / New / VIP.
String badgeLabel(BuildContext context, String badge) => switch (badge.toLowerCase()) {
      'vip' => 'VIP',
      'new' => context.l10n.badgeNew,
      _ => context.l10n.badgeHot,
    };

/// Quiet red badge text, shown in captions and never over the artwork.
class DramaBadge extends StatelessWidget {
  const DramaBadge(this.badge, {super.key, this.small = false});
  final String badge;
  final bool small;

  @override
  Widget build(BuildContext context) => Text(
        badgeLabel(context, badge),
        style: TextStyle(
          color: AppColors.primary,
          fontSize: small ? 12 : 13,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
      );
}

/// Quiet rounded genre chip.
class TagChip extends StatelessWidget {
  const TagChip(this.label, {super.key, this.dense = false});
  final String label;
  final bool dense;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 12, vertical: dense ? 2 : 5),
        decoration: BoxDecoration(
          color: AppColors.text.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall!.copyWith(
                fontSize: dense ? 10.5 : 12,
                color: AppColors.chipText,
              ),
        ),
      );
}

/// Quiet VIP pill.
class VipPill extends StatelessWidget {
  const VipPill({super.key, this.label = 'VIP'});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
}

/// Coin amount with a drawn coin glyph.
class CoinAmount extends StatelessWidget {
  const CoinAmount(this.amount, {super.key, this.size = 14, this.style});
  final int amount;
  final double size;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CoinIcon(size: size + 2),
          SizedBox(width: size * 0.3),
          Text(
            '$amount',
            style: style ??
                TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: size,
                ),
          ),
        ],
      );
}

class CoinIcon extends StatelessWidget {
  const CoinIcon({super.key, this.size = 16});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.brandGradient,
          border: Border.all(color: Colors.white54, width: size * 0.06),
        ),
        alignment: Alignment.center,
        child: Text(
          'A',
          style: TextStyle(
            fontSize: size * 0.55,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            height: 1,
          ),
        ),
      );
}
