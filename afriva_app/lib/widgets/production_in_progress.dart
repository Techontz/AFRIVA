import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';

/// A small looping film-set scene: a camera operator filming an actor under a
/// spotlight while the clapperboard snaps. Used for episodes whose video has
/// not been uploaded yet ("Production in progress").
class ProductionScene extends StatefulWidget {
  const ProductionScene({super.key, this.width = 260});
  final double width;

  @override
  State<ProductionScene> createState() => _ProductionSceneState();
}

class _ProductionSceneState extends State<ProductionScene> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: widget.width,
        height: widget.width * 0.58,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) => CustomPaint(painter: _ScenePainter(_c.value)),
        ),
      ),
    );
  }
}

class _ScenePainter extends CustomPainter {
  _ScenePainter(this.t);

  /// 0..1, one loop.
  final double t;

  static const _ink = Color(0xE6FFFFFF);
  static const _dim = Color(0x59FFFFFF);
  static const _red = AppColors.primary;

  @override
  void paint(Canvas canvas, Size size) {
    // Draw on a 260 x 150 design grid, scaled to the widget.
    final s = size.width / 260;
    canvas.save();
    canvas.scale(s, s);

    final wave = math.sin(t * 2 * math.pi);
    final fill = Paint()..color = _ink;
    final stroke = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    // Floor.
    canvas.drawLine(const Offset(8, 140), const Offset(252, 140), Paint()
      ..color = _dim
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round);

    // Spotlight cone on the actor (pulses softly).
    final beam = Path()
      ..moveTo(226, 6)
      ..lineTo(232, 6)
      ..lineTo(232 - 22, 140)
      ..lineTo(232 - 78, 140)
      ..close();
    canvas.drawPath(
      beam,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.30 + 0.10 * wave),
            Colors.white.withValues(alpha: 0.02),
          ],
        ).createShader(const Rect.fromLTWH(150, 6, 90, 134)),
    );
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(218, 0, 22, 10), const Radius.circular(3)), fill);
    // Light pool on the floor.
    canvas.drawOval(
      const Rect.fromLTWH(150, 134, 86, 10),
      Paint()..color = Colors.white.withValues(alpha: 0.10 + 0.05 * wave),
    );

    // Actor, gesturing while delivering lines.
    const ax = 193.0;
    canvas.drawCircle(Offset(ax, 70 + wave * 0.8), 9, fill);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(ax - 9, 82, 18, 32), const Radius.circular(8)),
      fill,
    );
    canvas.drawLine(Offset(ax - 4, 114), Offset(ax - 6, 139), stroke);
    canvas.drawLine(Offset(ax + 4, 114), Offset(ax + 6, 139), stroke);
    final arm = -0.9 + 0.5 * math.sin(t * 4 * math.pi); // talks with the hands
    canvas.drawLine(Offset(ax - 8, 88), Offset(ax - 8 + 18 * math.cos(math.pi + arm), 88 + 18 * math.sin(math.pi + arm)), stroke);
    canvas.drawLine(Offset(ax + 8, 88), Offset(ax + 14, 108), stroke);

    // Camera on a tripod.
    const cx = 86.0;
    canvas.drawLine(const Offset(cx, 88), const Offset(cx - 16, 139), stroke);
    canvas.drawLine(const Offset(cx, 88), const Offset(cx + 16, 139), stroke);
    canvas.drawLine(const Offset(cx, 88), const Offset(cx, 139), stroke);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(cx - 22, 64, 44, 26), const Radius.circular(5)), fill);
    // Lens pointing at the actor.
    final lens = Path()
      ..moveTo(cx + 22, 70)
      ..lineTo(cx + 38, 63)
      ..lineTo(cx + 38, 91)
      ..lineTo(cx + 22, 84)
      ..close();
    canvas.drawPath(lens, fill);
    // Two spinning film reels.
    for (final r in const [Offset(cx - 11, 50), Offset(cx + 12, 50)]) {
      canvas.drawCircle(r, 11, fill);
      final spoke = Paint()
        ..color = Colors.black.withValues(alpha: 0.55)
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 3; i++) {
        final a = t * 2 * math.pi * 2 + i * 2 * math.pi / 3;
        canvas.drawLine(r, r + Offset(math.cos(a) * 7, math.sin(a) * 7), spoke);
      }
      canvas.drawCircle(r, 2.2, Paint()..color = Colors.black.withValues(alpha: 0.55));
    }
    // Blinking REC light.
    if ((t * 4).floor().isEven) {
      canvas.drawCircle(const Offset(cx - 14, 71), 3, Paint()..color = _red);
    }

    // Camera operator behind the camera.
    const ox = 40.0;
    final bob = math.sin(t * 2 * math.pi + 1) * 1.2;
    canvas.drawCircle(Offset(ox, 66 + bob), 9, fill);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(ox - 9, 78 + bob, 18, 34), const Radius.circular(8)),
      fill,
    );
    canvas.drawLine(Offset(ox + 6, 86 + bob), Offset(cx - 22, 76), stroke); // hand on the camera
    canvas.drawLine(Offset(ox - 4, 112 + bob), const Offset(ox - 7, 139), stroke);
    canvas.drawLine(Offset(ox + 4, 112 + bob), const Offset(ox + 7, 139), stroke);
    // Cap.
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(ox - 9, 56 + bob, 22, 5), const Radius.circular(2)),
      Paint()..color = _red,
    );

    // Clapperboard on the floor, snapping shut once per loop.
    const bx = 132.0, by = 118.0;
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(bx, by, 30, 21), const Radius.circular(2)), fill);
    canvas.drawLine(const Offset(bx + 4, by + 9), const Offset(bx + 26, by + 9), Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..strokeWidth = 1.5);
    canvas.drawLine(const Offset(bx + 4, by + 14), const Offset(bx + 20, by + 14), Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..strokeWidth = 1.5);
    // Opens slowly, snaps fast.
    final phase = t < 0.8 ? t / 0.8 : 1 - (t - 0.8) / 0.2;
    final angle = -0.55 * Curves.easeOut.transform(phase.clamp(0.0, 1.0));
    canvas.save();
    canvas.translate(bx, by - 1);
    canvas.rotate(angle);
    final stick = RRect.fromRectAndRadius(const Rect.fromLTWH(0, -6, 30, 6), const Radius.circular(1.5));
    canvas.drawRRect(stick, fill);
    canvas.clipRRect(stick);
    final stripe = Paint()..color = _red;
    for (var x = -4.0; x < 32; x += 8) {
      canvas.drawPath(
        Path()
          ..moveTo(x, 0)
          ..lineTo(x + 4, 0)
          ..lineTo(x + 8, -6)
          ..lineTo(x + 4, -6)
          ..close(),
        stripe,
      );
    }
    canvas.restore();

    canvas.restore();
  }

  @override
  bool shouldRepaint(_ScenePainter old) => old.t != t;
}

/// Three dots that pulse in turn, a quiet "working on it" loader.
class PulsingDots extends StatefulWidget {
  const PulsingDots({super.key, this.color = AppColors.primary});
  final Color color;

  @override
  State<PulsingDots> createState() => _PulsingDotsState();
}

class _PulsingDotsState extends State<PulsingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(
                    alpha: 0.25 + 0.75 * (0.5 + 0.5 * math.sin((_c.value - i / 3) * 2 * math.pi)),
                  ),
                ),
              ),
          ],
        ),
      );
}
