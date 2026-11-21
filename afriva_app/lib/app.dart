import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'core/api_client.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'l10n/l10n.dart';
import 'services/auth_service.dart';
import 'services/catalog_service.dart';
import 'services/commerce_service.dart';
import 'services/google_auth.dart';
import 'services/me_service.dart';
import 'services/player_service.dart';
import 'services/studio_service.dart';
import 'services/token_storage.dart';
import 'state/auth_state.dart';
import 'state/favorites_state.dart';
import 'state/settings_state.dart';

/// Root widget: wires services/state with Provider and hosts the router.
class AfrivaApp extends StatefulWidget {
  const AfrivaApp({
    super.key,
    this.api,
    this.tokenStorage,
    this.settings,
    this.useGoogleFonts = true,
    this.initialLocation = '/splash',
    this.googleAuth,
  });

  final ApiClient? api;
  final TokenStorage? tokenStorage;
  final SettingsState? settings;
  final bool useGoogleFonts;
  final String initialLocation;

  /// Google ID token source; tests inject a fake.
  final GoogleAuth? googleAuth;

  @override
  State<AfrivaApp> createState() => _AfrivaAppState();
}

class _AfrivaAppState extends State<AfrivaApp> {
  late final ApiClient _api = widget.api ?? ApiClient();
  late final GoogleAuth _google = widget.googleAuth ?? PluginGoogleAuth();
  late final GoRouter _router = buildRouter(initialLocation: widget.initialLocation);
  late final ThemeData _light = () {
    AppTheme.init(useGoogleFonts: widget.useGoogleFonts);
    return AppTheme.light;
  }();
  late final ThemeData _dark = AppTheme.dark;

  /// Neutral [AppColors] tokens are read at build time, so a brightness
  /// switch rebuilds every element once on the next frame.
  static void _rebuildAll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      void mark(Element e) {
        e.markNeedsBuild();
        e.visitChildren(mark);
      }

      WidgetsBinding.instance.rootElement?.visitChildren(mark);
    });
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: _api),
        Provider(create: (_) => AuthService(_api)),
        Provider(create: (_) => CatalogService(_api)),
        Provider(create: (_) => PlayerService(_api)),
        Provider(create: (_) => CommerceService(_api)),
        Provider(create: (_) => MeService(_api)),
        Provider(create: (_) => StudioService(_api)),
        Provider<GoogleAuth>.value(value: _google),
        ChangeNotifierProvider(
          create: (c) => AuthState(
            api: _api,
            service: c.read<AuthService>(),
            storage: widget.tokenStorage ?? SecureTokenStorage(),
          ),
        ),
        ChangeNotifierProvider(create: (c) => FavoritesState(c.read<MeService>())),
        ChangeNotifierProvider(create: (_) => widget.settings ?? (SettingsState()..load())),
      ],
      child: Selector<SettingsState, (String, ThemeMode)>(
        selector: (_, s) => (s.languageCode, s.themeMode),
        builder: (_, sel, _) => MaterialApp.router(
          onGenerateTitle: (c) => c.l10n.appName,
          debugShowCheckedModeBanner: false,
          theme: _light,
          darkTheme: _dark,
          themeMode: sel.$2,
          locale: Locale(sel.$1),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          routerConfig: _router,
          builder: (context, child) {
            if (AppColors.use(Theme.of(context).brightness)) _rebuildAll();
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: afrivaLightOverlayStyle,
              child: child ?? const SizedBox.shrink(),
            );
          },
        ),
      ),
    );
  }
}
