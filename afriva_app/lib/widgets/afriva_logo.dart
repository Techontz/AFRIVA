import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';

/// Original Afriva logo: a red rounded-square play mark followed by the
/// "Afriva" wordmark (white on the dark top bar, near-black on light screens).
class AfrivaLogo extends StatelessWidget {
  const AfrivaLogo({super.key, this.size = 22, this.showMark = true, this.color});

  final double size;
  final bool showMark;

  /// Wordmark color; defaults to the theme's primary text color.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.titleLarge!.copyWith(
          fontSize: size,
          fontWeight: FontWeight.w800,
          letterSpacing: -size * 0.02,
          height: 1,
          color: color ?? Theme.of(context).textTheme.titleLarge!.color,
        );
    return Semantics(
      label: 'Afriva',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (showMark) ...[
              AfrivaMark(size: size * 1.05),
              SizedBox(width: size * 0.32),
            ],
            Text('Afriva', style: base),
          ],
        ),
      ),
    );
  }
}

/// The play-triangle brand mark, drawn with [CustomPaint].
class AfrivaMark extends StatelessWidget {
  const AfrivaMark({super.key, this.size = 24});
  final double size;

  @override
  Widget build(BuildContext context) =>
      SizedBox.square(dimension: size, child: CustomPaint(painter: _MarkPainter()));
}

class _MarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final rect = Offset.zero & size;
    final bg = RRect.fromRectAndRadius(rect, Radius.circular(s * 0.24));
    canvas.drawRRect(bg, Paint()..color = AppColors.primary);

    // Rounded play triangle.
    final path = Path()
      ..moveTo(s * 0.38, s * 0.27)
      ..quadraticBezierTo(s * 0.36, s * 0.26, s * 0.36, s * 0.30)
      ..lineTo(s * 0.36, s * 0.70)
      ..quadraticBezierTo(s * 0.36, s * 0.74, s * 0.39, s * 0.72)
      ..lineTo(s * 0.72, s * 0.52)
      ..quadraticBezierTo(s * 0.75, s * 0.50, s * 0.72, s * 0.48)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
