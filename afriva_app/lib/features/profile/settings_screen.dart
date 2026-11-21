import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/haptics.dart';
import '../../core/theme.dart';
import '../../l10n/l10n.dart';
import '../../state/auth_state.dart';
import '../../state/settings_state.dart';
import '../../widgets/afriva_logo.dart';
import '../../widgets/states.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsState>();
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    final loggedIn = context.watch<AuthState>().isLoggedIn;
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.paddingOf(context).bottom + 24),
        children: [
          _Group(title: l.settingsPlayback, children: [
            SwitchListTile(
              value: s.autoplayNext,
              onChanged: (v) {
                Haptics.tap();
                s.setAutoplayNext(v);
              },
              title: Text(l.settingsAutoplay, style: text.titleSmall),
              subtitle: Text(l.settingsAutoplaySubtitle, style: text.labelSmall),
            ),
          ]),
          if (loggedIn)
            _Group(title: l.settingsPayments, children: [
              // Play Store build pays through Google Play: no saved mobile money or cards.
              if (!AppConfig.isPlayStore)
              ListTile(
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: Text(l.paymentMethodsTitle, style: text.titleSmall),
                trailing: Icon(Icons.chevron_right_rounded, color: AppColors.textDim),
                onTap: () => context.push('/payment-methods'),
              ),
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: Text(l.paymentHistoryTitle, style: text.titleSmall),
                trailing: Icon(Icons.chevron_right_rounded, color: AppColors.textDim),
                onTap: () => context.push('/payments'),
              ),
            ]),
          _Group(title: l.settingsVideoQuality, children: [
            for (final q in const [0, 1080, 720, 480, 360, 240])
              ListTile(
                dense: true,
                title: Text(q == 0 ? l.qualityAuto : '${q}p', style: text.titleSmall),
                subtitle: q == 0 ? Text(l.qualityAutoSubtitle, style: text.labelSmall) : null,
                trailing: _Radio(selected: s.videoQuality == q),
                onTap: () {
                  Haptics.tap();
                  s.setVideoQuality(q);
                },
              ),
          ]),
          _Group(title: l.settingsAppearance, children: [
            for (final (mode, name, icon) in [
              (ThemeMode.dark, l.themeDark, Icons.dark_mode_outlined),
              (ThemeMode.light, l.themeLight, Icons.light_mode_outlined),
              (ThemeMode.system, l.themeSystem, Icons.brightness_auto_outlined),
            ])
              ListTile(
                leading: Icon(icon),
                title: Text(name, style: text.titleSmall),
                trailing: _Radio(selected: s.themeMode == mode),
                onTap: () {
                  Haptics.tap();
                  s.setThemeMode(mode);
                },
              ),
          ]),
          _Group(title: l.settingsLanguage, children: [
            // Language names are shown in their own language on purpose.
            for (final (code, name) in const [('en', 'English'), ('sw', 'Kiswahili')])
              ListTile(
                title: Text(name, style: text.titleSmall),
                trailing: _Radio(selected: s.languageCode == code),
                onTap: () {
                  Haptics.tap();
                  s.setLanguage(code);
                },
              ),
          ]),
          _Group(title: l.settingsStorage, children: [
            ListTile(
              leading: const Icon(Icons.cleaning_services_outlined),
              title: Text(l.settingsClearImageCache, style: text.titleSmall),
              subtitle: Text(l.settingsClearImageCacheSubtitle, style: text.labelSmall),
              onTap: () async {
                Haptics.tap();
                PaintingBinding.instance.imageCache.clear();
                try {
                  await CachedNetworkImage.evictFromCache('');
                } catch (_) {}
                if (context.mounted) showSnack(context, context.l10n.settingsImageCacheCleared);
              },
            ),
            ListTile(
              leading: const Icon(Icons.history_toggle_off_rounded),
              title: Text(l.settingsClearSearchHistory, style: text.titleSmall),
              onTap: () {
                Haptics.tap();
                s.clearRecentSearches();
                showSnack(context, l.settingsSearchHistoryCleared);
              },
            ),
          ]),
          _Group(title: l.settingsAbout, children: [
            ListTile(
              title: Text(l.termsTitle, style: text.titleSmall),
              trailing: Icon(Icons.chevron_right_rounded, color: AppColors.textDim),
              onTap: () => _info(context, l.termsTitle, l.termsBody),
            ),
            ListTile(
              title: Text(l.privacyTitle, style: text.titleSmall),
              trailing: Icon(Icons.chevron_right_rounded, color: AppColors.textDim),
              onTap: () => _info(context, l.privacyTitle, l.privacyBody),
            ),
            ListTile(
              title: Text(l.settingsServer, style: text.titleSmall),
              subtitle: Text(AppConfig.apiUrl, style: text.labelSmall),
            ),
          ]),
          if (loggedIn)
            _Group(title: l.settingsAccount, children: [
              ListTile(
                leading: const Icon(Icons.delete_forever_outlined, color: AppColors.danger),
                title: Text(l.deleteAccountTitle, style: text.titleSmall!.copyWith(color: AppColors.danger)),
                subtitle: Text(l.deleteAccountSubtitle, style: text.labelSmall),
                onTap: () => _deleteAccount(context),
              ),
            ]),
          const SizedBox(height: 24),
          const Center(child: AfrivaLogo(size: 18)),
          const SizedBox(height: 8),
          Center(child: Text(l.settingsFooter('1.0.0'), style: text.labelSmall)),
        ],
      ),
    );
  }

  /// Google Play requires account deletion inside the app.
  static Future<void> _deleteAccount(BuildContext context) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteAccountConfirmTitle),
        content: Text(l.deleteAccountConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.actionCancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.deleteAccountConfirm, style: const TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await context.read<AuthState>().deleteAccount();
      Haptics.success();
      if (!context.mounted) return;
      showSnack(context, l.deleteAccountDone);
      context.go('/home');
    } catch (e) {
      if (context.mounted) showSnack(context, errorMessage(e));
    }
  }

  static void _info(BuildContext context, String title, String body) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.l10n.actionClose))],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(title.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall!.copyWith(letterSpacing: 1.2)),
            ),
            // Material (not a decorated box) so the tiles' ink stays visible.
            Material(
              type: MaterialType.transparency,
              child: Column(children: children),
            ),
          ],
        ),
      );
}

class _Radio extends StatelessWidget {
  const _Radio({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) => selected
      ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
      : Icon(Icons.circle_outlined, color: AppColors.textDim);
}
