import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'core/api_client.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'services/auth_service.dart';
import 'services/catalog_service.dart';
import 'services/commerce_service.dart';
import 'services/me_service.dart';
import 'services/player_service.dart';
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
    this.useGoogleFonts = true,
    this.initialLocation = '/splash',
  });

  final ApiClient? api;
  final TokenStorage? tokenStorage;
  final bool useGoogleFonts;
  final String initialLocation;

  @override
  State<AfrivaApp> createState() => _AfrivaAppState();
}

class _AfrivaAppState extends State<AfrivaApp> {
  late final ApiClient _api = widget.api ?? ApiClient();
  late final GoRouter _router = buildRouter(initialLocation: widget.initialLocation);
  late final ThemeData _theme = () {
    AppTheme.init(useGoogleFonts: widget.useGoogleFonts);
    return AppTheme.light;
  }();

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
        ChangeNotifierProvider(
          create: (c) => AuthState(
            api: _api,
            service: c.read<AuthService>(),
            storage: widget.tokenStorage ?? SecureTokenStorage(),
          ),
        ),
        ChangeNotifierProvider(create: (c) => FavoritesState(c.read<MeService>())),
        ChangeNotifierProvider(create: (_) => SettingsState()..load()),
      ],
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: afrivaLightOverlayStyle,
        child: MaterialApp.router(
          title: 'Afriva',
          debugShowCheckedModeBanner: false,
          theme: _theme,
          darkTheme: _theme,
          themeMode: ThemeMode.light,
          routerConfig: _router,
        ),
      ),
    );
  }
}
