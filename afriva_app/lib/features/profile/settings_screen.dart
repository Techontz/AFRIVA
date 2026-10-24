import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/haptics.dart';
import '../../core/theme.dart';
import '../../state/settings_state.dart';
import '../../widgets/afriva_logo.dart';
import '../../widgets/states.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsState>();
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.paddingOf(context).bottom + 24),
        children: [
          _Group(title: 'Playback', children: [
            SwitchListTile(
              value: s.autoplayNext,
              onChanged: (v) {
                Haptics.tap();
                s.setAutoplayNext(v);
              },
              title: Text('Autoplay next episode', style: text.titleSmall),
              subtitle: Text('Continue to the next episode when one ends', style: text.labelSmall),
            ),
          ]),
          _Group(title: 'Language', children: [
            for (final lang in const ['English', 'Kiswahili'])
              ListTile(
                title: Text(lang, style: text.titleSmall),
                trailing: s.language == lang
                    ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
                    : const Icon(Icons.circle_outlined, color: AppColors.textDim),
                onTap: () {
                  Haptics.tap();
                  s.setLanguage(lang);
                },
              ),
          ]),
          _Group(title: 'Storage', children: [
            ListTile(
              leading: const Icon(Icons.cleaning_services_outlined),
              title: Text('Clear image cache', style: text.titleSmall),
              subtitle: Text('Free up space used by posters', style: text.labelSmall),
              onTap: () async {
                Haptics.tap();
                PaintingBinding.instance.imageCache.clear();
                try {
                  await CachedNetworkImage.evictFromCache('');
                } catch (_) {}
                if (context.mounted) showSnack(context, 'Image cache cleared');
              },
            ),
            ListTile(
              leading: const Icon(Icons.history_toggle_off_rounded),
              title: Text('Clear search history', style: text.titleSmall),
              onTap: () {
                Haptics.tap();
                s.clearRecentSearches();
                showSnack(context, 'Search history cleared');
              },
            ),
          ]),
          _Group(title: 'About', children: [
            ListTile(
              title: Text('Terms of Service', style: text.titleSmall),
              trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textDim),
              onTap: () => _info(context, 'Terms of Service',
                  'Afriva content is licensed for personal, non-commercial viewing. Subscriptions and coins are non-transferable.'),
            ),
            ListTile(
              title: Text('Privacy Policy', style: text.titleSmall),
              trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textDim),
              onTap: () => _info(context, 'Privacy Policy',
                  'We store only what we need to run your account: your profile, watch history, list and payments. We never sell your data.'),
            ),
            ListTile(
              title: Text('Server', style: text.titleSmall),
              subtitle: Text(AppConfig.apiUrl, style: text.labelSmall),
            ),
          ]),
          const SizedBox(height: 24),
          const Center(child: AfrivaLogo(size: 18)),
          const SizedBox(height: 8),
          Center(child: Text('Version 1.0.0 · Made for African storytellers', style: text.labelSmall)),
        ],
      ),
    );
  }

  static void _info(BuildContext context, String title, String body) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
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
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadii.card),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(children: children),
            ),
          ],
        ),
      );
}
