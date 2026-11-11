import 'dart:ui';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../../core/theme.dart';
import '../../l10n/l10n.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  static const _icons = [
    (Icons.home_outlined, Icons.home_rounded),
    (Icons.play_circle_outline_rounded, Icons.play_circle_fill_rounded),
    (Icons.bookmark_border_rounded, Icons.bookmark_rounded),
    (Icons.person_outline_rounded, Icons.person_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final labels = [l.navHome, l.navForYou, l.navMyList, l.navProfile];
    final immersive = shell.currentIndex == 1;
    return Scaffold(
      backgroundColor: immersive ? Colors.black : AppColors.bg,
      extendBody: true,
      body: shell,
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: AnimatedContainer(
            duration: AppMotion.normal,
            decoration: BoxDecoration(
              color: immersive ? Colors.black.withValues(alpha: 0.55) : AppColors.bg.withValues(alpha: 0.8),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 56,
                child: Row(
                  children: [
                    for (var i = 0; i < _icons.length; i++)
                      Expanded(
                        child: _NavItem(
                          icon: _icons[i].$1,
                          activeIcon: _icons[i].$2,
                          label: labels[i],
                          selected: shell.currentIndex == i,
                          immersive: immersive,
                          onTap: () {
                            Haptics.tap();
                            shell.goBranch(i, initialLocation: i == shell.currentIndex);
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.immersive,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final bool immersive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? AppColors.primary
        : immersive
            ? Colors.white70
            : AppColors.textDim;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? activeIcon : icon, size: 22, color: color),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: AppMotion.normal,
              style: Theme.of(context).textTheme.labelSmall!.copyWith(
                    fontSize: 10.5,
                    letterSpacing: 0,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}
