import 'package:material_ui/material_ui.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../models/commerce.dart';
import '../../widgets/net_image.dart';

/// Brand colour + short wordmark per payment method code (text only, no logos).
({Color color, String mark, Color fg}) methodBrand(PaymentMethod m) {
  final parsed = _parseHex(m.color);
  final fallback = switch (m.code) {
    'mpesa' => (const Color(0xFFE60000), 'M-PESA', Colors.white),
    'tigopesa' => (const Color(0xFFFFD400), 'Mixx', const Color(0xFF0B2A6B)),
    'airtelmoney' => (const Color(0xFFE40000), 'airtel', Colors.white),
    'halopesa' => (const Color(0xFFF47920), 'Halo', Colors.white),
    'tpesa' => (const Color(0xFF0072BC), 'T-Pesa', Colors.white),
    'visa' => (const Color(0xFF1A1F71), 'VISA', Colors.white),
    'mastercard' => (const Color(0xFF252525), 'MC', Colors.white),
    'crdb' => (const Color(0xFF00853F), 'CRDB', Colors.white),
    'nmb' => (const Color(0xFF005BAA), 'NMB', Colors.white),
    'nbc' => (const Color(0xFF002B5C), 'NBC', Colors.white),
    _ => (AppColors.surface2, _initials(m.name), AppColors.chipText),
  };
  final color = parsed ?? fallback.$1;
  final fg = parsed == null
      ? fallback.$3
      : (ThemeData.estimateBrightnessForColor(color) == Brightness.dark ? Colors.white : const Color(0xFF111111));
  return (color: color, mark: fallback.$2, fg: fg);
}

String _initials(String name) {
  final parts = name.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  return parts.take(2).map((s) => s[0].toUpperCase()).join();
}

Color? _parseHex(String? hex) {
  if (hex == null) return null;
  var h = hex.trim().replaceFirst('#', '');
  if (h.length == 3) h = h.split('').map((c) => '$c$c').join();
  if (h.length == 6) h = 'FF$h';
  final v = int.tryParse(h, radix: 16);
  return v == null ? null : Color(v);
}

class MethodTile extends StatelessWidget {
  const MethodTile({super.key, required this.method, required this.selected, required this.onTap});

  final PaymentMethod method;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = methodBrand(method);
    final text = Theme.of(context).textTheme;
    // Not connected to a tested provider yet: visible but not selectable (scope §07).
    final available = method.isAvailable;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: available ? 1 : 0.45,
        child: AnimatedContainer(
        duration: AppMotion.normal,
        curve: AppMotion.curve,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected ? brand.color.withValues(alpha: 0.12) : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 38,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: brand.color,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: [
                      BoxShadow(color: brand.color.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 3)),
                    ],
                  ),
                  alignment: Alignment.center,
                  clipBehavior: Clip.antiAlias,
                  child: method.logoUrl != null
                      ? Padding(
                          padding: const EdgeInsets.all(6),
                          child: NetImage(method.logoUrl, fit: BoxFit.contain),
                        )
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(
                              brand.mark,
                              style: TextStyle(
                                color: brand.fg,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                letterSpacing: brand.mark == 'VISA' ? 1.5 : 0,
                                fontStyle: brand.mark == 'VISA' ? FontStyle.italic : FontStyle.normal,
                              ),
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 8),
                Text(
                  available ? method.name : context.tr('Coming soon'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: text.labelSmall!.copyWith(
                    color: selected ? AppColors.text : AppColors.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (selected)
              const Positioned(
                top: 0,
                right: 0,
                child: Icon(Icons.check_circle_rounded, size: 16, color: AppColors.primary),
              ),
          ],
        ),
      ),
      ),
    );
  }
}
