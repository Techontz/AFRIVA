import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../../core/payments.dart';
import '../../core/theme.dart';
import '../../l10n/l10n.dart';
import '../../models/commerce.dart';

/// Small brand badge: the Visa wordmark, the Mastercard circles, or a
/// monogram for a mobile money network. Drawn in code, no image assets.
class BrandMark extends StatelessWidget {
  const BrandMark.card(this.brand, {super.key, this.size = 40}) : network = null, phone = false;
  const BrandMark.network(this.network, {super.key, this.size = 40}) : brand = null, phone = true;

  final CardBrand? brand;
  final MobileNetwork? network;
  final bool phone;
  final double size;

  static Color networkColor(MobileNetwork? n) => switch (n?.code) {
        'mpesa' => const Color(0xFF00A651),
        'airtelmoney' => const Color(0xFFED1C24),
        'tigopesa' => const Color(0xFF1B4FD8),
        'halopesa' => const Color(0xFFF58220),
        'tpesa' => const Color(0xFF0072BC),
        _ => const Color(0xFF6B6B6B),
      };

  static String _monogram(MobileNetwork? n) => switch (n?.code) {
        'mpesa' => 'M',
        'airtelmoney' => 'A',
        'tigopesa' => 'Y',
        'halopesa' => 'H',
        'tpesa' => 'T',
        _ => '',
      };

  @override
  Widget build(BuildContext context) {
    final h = size * 0.68;
    final radius = BorderRadius.circular(size * 0.2);
    if (phone) {
      final c = networkColor(network);
      return Container(
        width: size,
        height: h,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: c, borderRadius: radius),
        child: network == null
            ? Icon(Icons.phone_iphone_rounded, size: h * 0.6, color: Colors.white)
            : Text(
                _monogram(network),
                style: TextStyle(color: Colors.white, fontSize: h * 0.52, fontWeight: FontWeight.w800, height: 1),
              ),
      );
    }
    return Container(
      width: size,
      height: h,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: radius,
        border: Border.all(color: const Color(0x1A000000)),
      ),
      child: switch (brand) {
        CardBrand.visa => Text(
            'VISA',
            style: TextStyle(
              color: const Color(0xFF1A1F71),
              fontSize: h * 0.42,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
              letterSpacing: 0.5,
              height: 1,
            ),
          ),
        CardBrand.mastercard => MastercardCircles(diameter: h * 0.56),
        null => Icon(Icons.credit_card_rounded, size: h * 0.6, color: const Color(0xFF555555)),
      },
    );
  }
}

/// The two overlapping Mastercard circles.
class MastercardCircles extends StatelessWidget {
  const MastercardCircles({super.key, required this.diameter});
  final double diameter;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: diameter * 1.6,
        height: diameter,
        child: Stack(
          children: [
            Positioned(left: 0, child: _dot(const Color(0xFFEB001B))),
            Positioned(right: 0, child: _dot(const Color(0xFFF79E1B).withValues(alpha: 0.92))),
          ],
        ),
      );

  Widget _dot(Color c) => Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(shape: BoxShape.circle, color: c),
      );
}

/// Title and subtitle for a saved method, shared by checkout and the
/// payment methods screen.
({String title, String subtitle}) describeSaved(BuildContext context, SavedMethod m) {
  final l = context.l10n;
  if (m.isCard) {
    final brand = CardBrand.fromCode(m.cardBrand ?? m.methodCode)?.label ?? (m.cardBrand ?? '');
    return (
      title: l.payCardEnding(brand, m.cardLast4 ?? ''),
      subtitle: m.isExpired ? l.payExpired : l.payExpires(m.expiryLabel),
    );
  }
  final network = m.network ?? MobileNetwork.byCode(m.methodCode)?.name ?? l.payMobileMoney;
  return (title: network, subtitle: TzPhone.pretty(m.phone));
}

Widget brandMarkFor(SavedMethod m, {double size = 40}) => m.isCard
    ? BrandMark.card(CardBrand.fromCode(m.cardBrand ?? m.methodCode), size: size)
    : BrandMark.network(MobileNetwork.byCode(m.methodCode) ?? TzPhone.detect(m.phone ?? ''), size: size);

/// A selectable surface row used for every payment choice.
class PayOptionTile extends StatelessWidget {
  const PayOptionTile({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.selected = false,
    this.enabled = true,
    this.badge,
    this.trailing,
    this.onTap,
    this.subtitleColor,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final bool selected;
  final bool enabled;
  final String? badge;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? subtitleColor;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: onTap != null,
      selected: selected,
      enabled: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled && onTap != null
            ? () {
                Haptics.tap();
                onTap!();
              }
            : null,
        child: AnimatedOpacity(
          duration: AppMotion.normal,
          opacity: enabled ? 1 : 0.5,
          child: AnimatedContainer(
            duration: AppMotion.normal,
            curve: AppMotion.curve,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary.withValues(alpha: 0.07) : AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.border.withValues(alpha: 0.6),
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Row(
              children: [
                leading,
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.titleSmall!.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (badge != null) ...[
                            const SizedBox(width: 8),
                            _Badge(badge!),
                          ],
                        ],
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.labelSmall!.copyWith(color: subtitleColor ?? AppColors.textMuted, fontSize: 12.5),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                trailing ?? RadioDot(selected: selected),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.text.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.2),
        ),
      );
}

/// Round selection indicator.
class RadioDot extends StatelessWidget {
  const RadioDot({super.key, required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: AppMotion.normal,
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? AppColors.primary : Colors.transparent,
          border: Border.all(color: selected ? AppColors.primary : AppColors.textDim, width: 1.6),
        ),
        child: selected ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null,
      );
}

/// Two-option segmented choice (mobile money / card). A disabled side shows
/// "Coming soon" instead of disappearing.
class PaySegmented extends StatelessWidget {
  const PaySegmented({
    super.key,
    required this.cardSelected,
    required this.onChanged,
    this.mobileEnabled = true,
    this.cardEnabled = true,
  });

  final bool cardSelected;
  final ValueChanged<bool> onChanged;
  final bool mobileEnabled;
  final bool cardEnabled;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Container(
      height: 56,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: LayoutBuilder(
        builder: (context, box) => Stack(
          children: [
            AnimatedAlign(
              duration: AppMotion.slow,
              curve: AppMotion.curve,
              alignment: cardSelected ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: box.maxWidth / 2,
                height: box.maxHeight,
                decoration: BoxDecoration(
                  color: AppColors.isDark ? AppColors.surface2 : Colors.white,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: AppColors.isDark ? 0.4 : 0.08), blurRadius: 10, offset: const Offset(0, 2)),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                _segment(context, Icons.phone_iphone_rounded, l.payMobileMoney, !cardSelected, mobileEnabled, () => onChanged(false)),
                _segment(context, Icons.credit_card_rounded, l.payCard, cardSelected, cardEnabled, () => onChanged(true)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _segment(BuildContext context, IconData icon, String label, bool selected, bool enabled, VoidCallback onTap) {
    final color = selected ? AppColors.text : AppColors.textMuted;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        enabled: enabled,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled && !selected
              ? () {
                  Haptics.tap();
                  onTap();
                }
              : null,
          child: Opacity(
            opacity: enabled ? 1 : 0.45,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 18, color: selected ? AppColors.primary : color),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color),
                      ),
                    ),
                  ],
                ),
                if (!enabled)
                  Text(
                    context.l10n.payComingSoon,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textDim),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Live "M-Pesa" pill shown inside the phone field once the prefix is known.
class NetworkPill extends StatelessWidget {
  const NetworkPill({super.key, required this.network});
  final MobileNetwork network;

  @override
  Widget build(BuildContext context) {
    final c = BrandMark.networkColor(network);
    return Container(
      padding: const EdgeInsets.fromLTRB(5, 4, 10, 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          BrandMark.network(network, size: 22),
          const SizedBox(width: 6),
          Text(network.name, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.text)),
        ],
      ),
    );
  }
}

/// Card option when cards are paid on the payment partner's secure hosted
/// page: brand marks and a reassuring line instead of card fields. [phone] is
/// the receipt phone field shown underneath.
class HostedCardPanel extends StatelessWidget {
  const HostedCardPanel({super.key, required this.brands, required this.phone});

  final List<CardBrand> brands;
  final Widget phone;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    final marks = brands.isEmpty ? CardBrand.values : brands;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const ValueKey('hosted-card-panel'),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: AppColors.vipCardGradient,
            borderRadius: BorderRadius.circular(AppRadii.card + 2),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.18),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.brandGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l.payHostedTitle,
                      style: text.titleSmall!.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  for (final b in marks) ...[
                    const SizedBox(width: 6),
                    BrandMark.card(b, size: 42),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(
                      Icons.verified_user_outlined,
                      size: 17,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l.payHostedBody,
                      style: text.bodySmall!.copyWith(
                        color: AppColors.text,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        phone,
      ],
    );
  }
}
