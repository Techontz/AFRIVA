import 'package:material_ui/material_ui.dart';

import '../core/haptics.dart';
import '../core/theme.dart';

/// Pill button. Primary is solid red with white text; [light] is a white
/// pill with black text; secondary uses the theme's surface.
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.secondary = false,
    this.light = false,
    this.loading = false,
    this.expand = false,
    this.height = 50,
    this.fontSize,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool secondary;
  final bool light;
  final bool loading;
  final bool expand;
  final double height;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final scheme = Theme.of(context).colorScheme;
    final fg = light
        ? Colors.black
        : secondary
            ? scheme.onSurface
            : Colors.white;
    final style = Theme.of(context).textTheme.labelLarge!.copyWith(
          color: fg,
          fontSize: fontSize ?? (height < 44 ? 13 : 15),
          fontWeight: FontWeight.w800,
          letterSpacing: 0.1,
        );
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2.2, color: fg),
          )
        else if (icon != null)
          Icon(icon, color: fg, size: height < 44 ? 18 : 20),
        if (loading || icon != null) const SizedBox(width: 8),
        Flexible(
          child: Text(label, style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );

    return AnimatedOpacity(
      duration: AppMotion.fast,
      opacity: enabled || loading ? 1 : 0.5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: secondary
              ? scheme.surface
              : light
                  ? Colors.white
                  : AppColors.primary,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: light ? Border.all(color: AppColors.border) : null,
          boxShadow: secondary || light || !enabled
              ? null
              : [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.22),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            onTap: enabled
                ? () {
                    Haptics.tap();
                    onPressed!();
                  }
                : null,
            child: SizedBox(
              height: height,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: height < 44 ? 16 : 22),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Circular translucent icon button used over video / imagery.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 40,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final double size;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final btn = Material(
      color: Colors.black.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          Haptics.tap();
          onPressed();
        },
        child: SizedBox.square(
          dimension: size,
          child: Icon(icon, color: Colors.white, size: size * 0.5),
        ),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}
