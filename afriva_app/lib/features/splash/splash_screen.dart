import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../state/auth_state.dart';
import '../../state/favorites_state.dart';
import '../../widgets/afriva_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final auth = context.read<AuthState>();
    final favs = context.read<FavoritesState>();
    await Future.wait([
      auth.bootstrap().then((_) async {
        if (auth.isLoggedIn) {
          try {
            await favs.load();
          } catch (_) {}
        }
      }).timeout(const Duration(seconds: 6), onTimeout: () {}),
      Future<void>.delayed(const Duration(milliseconds: 1500)),
    ]);
    if (mounted) context.go('/home');
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logo = CurvedAnimation(parent: _c, curve: const Interval(0, 0.7, curve: Curves.easeOutBack));
    final tag = CurvedAnimation(parent: _c, curve: const Interval(0.45, 1, curve: Curves.easeOut));
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: Tween(begin: 0.7, end: 1.0).animate(logo),
                  child: FadeTransition(opacity: logo, child: const AfrivaLogo(size: 38)),
                ),
                const SizedBox(height: 14),
                FadeTransition(
                  opacity: tag,
                  child: Text(
                    context.tr('Short dramas. Big African stories.'),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 48 + MediaQuery.paddingOf(context).bottom,
            child: FadeTransition(
              opacity: tag,
              child: const Center(
                child: SizedBox(
                  width: 120,
                  child: ClipRRect(
                    borderRadius: BorderRadius.all(Radius.circular(4)),
                    child: LinearProgressIndicator(
                      minHeight: 3,
                      backgroundColor: AppColors.surface,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
