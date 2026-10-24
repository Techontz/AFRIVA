import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';

/// Top-left poster badge: Hot / New / VIP.
class DramaBadge extends StatelessWidget {
  const DramaBadge(this.badge, {super.key, this.small = false});
  final String badge;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final b = badge.toLowerCase();
    // Hot = red, New = white, VIP = black with red outline.
    final (label, gradient, bgColor, fg) = switch (b) {
      'vip' => ('VIP', null, Colors.black, Colors.white),
      'new' => ('New', null, Colors.white, Colors.black),
      _ => ('Hot', AppColors.brandGradient, null, Colors.white),
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 5 : 7, vertical: small ? 2 : 3),
      decoration: BoxDecoration(
        gradient: gradient,
        color: bgColor,
        border: b == 'vip' ? Border.all(color: AppColors.primary, width: 1) : null,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppRadii.poster),
          bottomRight: Radius.circular(8),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (b == 'vip') ...[
            Icon(Icons.workspace_premium_rounded, size: small ? 10 : 12, color: AppColors.primary),
            const SizedBox(width: 2),
          ],
          if (b == 'hot') ...[
            Icon(Icons.local_fire_department_rounded, size: small ? 10 : 12, color: fg),
            const SizedBox(width: 1),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: small ? 9 : 10.5,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Light rounded genre chip (#E4E4E4 / #555).
class TagChip extends StatelessWidget {
  const TagChip(this.label, {super.key, this.dense = false});
  final String label;
  final bool dense;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 12, vertical: dense ? 2 : 5),
        decoration: BoxDecoration(
          color: AppColors.surface2,
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

/// Red VIP pill.
class VipPill extends StatelessWidget {
  const VipPill({super.key, this.label = 'VIP'});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.workspace_premium_rounded, size: 13, color: Colors.white),
            const SizedBox(width: 3),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
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
