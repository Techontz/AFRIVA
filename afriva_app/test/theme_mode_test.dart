// Dark is the default appearance; Light / System are persisted choices.
import 'package:afriva_app/app.dart';
import 'package:afriva_app/core/theme.dart';
import 'package:afriva_app/features/profile/settings_screen.dart';
import 'package:afriva_app/services/token_storage.dart';
import 'package:afriva_app/state/settings_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('Theme mode defaults to dark and persists', () async {
    SharedPreferences.setMockInitialValues({});
    final s = SettingsState();
    await s.load();
    expect(s.themeMode, ThemeMode.dark);
    s.setThemeMode(ThemeMode.light);
    expect((await SharedPreferences.getInstance()).getString('theme_mode'), 'light');
    final again = SettingsState();
    await again.load();
    expect(again.themeMode, ThemeMode.light);
  });

  testWidgets('App starts in dark mode with dark tokens', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsState();
    await settings.load();
    await tester.pumpWidget(AfrivaApp(
      settings: settings,
      tokenStorage: MemoryTokenStorage(),
      useGoogleFonts: false,
      initialLocation: '/settings',
    ));
    await tester.pump();
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    expect(Theme.of(tester.element(find.byType(SettingsScreen))).brightness, Brightness.dark);
    expect(AppColors.isDark, isTrue);

    // Switching to Light rebuilds with the light palette.
    await tester.ensureVisible(find.text('Light'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.byType(SettingsScreen))).brightness, Brightness.light);
    expect(AppColors.bg, AppPalette.light.bg);
    AppColors.use(Brightness.dark);
  });
}
