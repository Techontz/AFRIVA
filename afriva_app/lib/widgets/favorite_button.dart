import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/auth_guard.dart';
import '../core/haptics.dart';
import '../core/theme.dart';
import '../l10n/l10n.dart';
import '../models/drama.dart';
import '../state/favorites_state.dart';
import 'states.dart';

/// Toggles a drama in My List (requires login). Shared by detail, player & feed.
Future<void> toggleFavorite(BuildContext context, Drama drama) async {
  if (!await requireLogin(context)) return;
  if (!context.mounted) return;
  final favs = context.read<FavoritesState>();
  Haptics.medium();
  try {
    final added = await favs.toggle(drama);
    if (context.mounted) {
      showSnack(context, added ? context.l10n.addedToMyList : context.l10n.removedFromMyList);
    }
  } catch (e) {
    if (context.mounted) showSnack(context, errorMessage(e), error: true);
  }
}

/// Vertical icon+label action used on the player / feed right rail.
class RailAction extends StatelessWidget {
  const RailAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: AppMotion.normal,
                transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                child: active
                    ? ShaderMask(
                        key: const ValueKey('on'),
                        blendMode: BlendMode.srcIn,
                        shaderCallback: (r) => AppColors.brandGradient.createShader(r),
                        child: Icon(icon, size: 30, color: Colors.white),
                      )
                    : Icon(icon,
                        key: const ValueKey('off'),
                        size: 30,
                        color: Colors.white,
                        shadows: const [Shadow(color: Colors.black45, blurRadius: 8)]),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                ),
              ),
            ],
          ),
        ),
      );
}

/// Favorite rail action wired to [FavoritesState].
class FavoriteRailAction extends StatelessWidget {
  const FavoriteRailAction({super.key, required this.drama});
  final Drama drama;

  @override
  Widget build(BuildContext context) {
    final fav = context.watch<FavoritesState>().contains(drama);
    return RailAction(
      icon: fav ? Icons.bookmark_rounded : Icons.bookmark_add_outlined,
      label: fav ? context.l10n.inMyList : context.l10n.navMyList,
      active: fav,
      onTap: () => toggleFavorite(context, drama),
    );
  }
}
