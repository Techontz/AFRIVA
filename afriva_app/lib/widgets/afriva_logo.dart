import 'package:material_ui/material_ui.dart';

/// Afriva logo: the red AFRIVA wordmark block (assets/brand/logo.webp).
/// [size] sets its visual weight like a font size.
class AfrivaLogo extends StatelessWidget {
  const AfrivaLogo({super.key, this.size = 22, this.showMark = true, this.color});

  static const _ratio = 1388 / 482;

  final double size;

  /// Kept for call-site compatibility; the brand block has no separate mark.
  final bool showMark;

  /// Kept for call-site compatibility; the logo artwork has fixed colors.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final height = size * 1.25;
    return Semantics(
      label: 'Afriva',
      image: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height * 0.08),
        child: Image.asset(
          'assets/brand/logo.webp',
          height: height,
          width: height * _ratio,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}

/// Square brand icon: the wordmark centered on a red rounded square.
class AfrivaMark extends StatelessWidget {
  const AfrivaMark({super.key, this.size = 24});
  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22),
        child: Image.asset(
          'assets/brand/icon-512.webp',
          width: size,
          height: size,
          filterQuality: FilterQuality.medium,
          excludeFromSemantics: true,
        ),
      );
}
