import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/format.dart';
import '../../core/haptics.dart';
import '../../core/theme.dart';
import '../../l10n/l10n.dart';
import '../../models/studio_application.dart';
import '../../models/user.dart';
import '../../services/studio_service.dart';
import '../../state/auth_state.dart';
import '../../state/favorites_state.dart';
import '../../widgets/badges.dart';
import '../../widgets/buttons.dart';
import '../../widgets/net_image.dart';
import '../studio/studio_widgets.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final user = auth.user;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.navProfile),
        actions: [
          IconButton(
            tooltip: l.settingsTitle,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: auth.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16, 4, 16, bottom + 24),
          children: [
            if (user == null) const _GuestCard() else _UserCard(user: user),
            const SizedBox(height: 14),
            _WalletRow(user: user),
            const SizedBox(height: 14),
            _VipBanner(user: user),
            const SizedBox(height: 16),
            _MenuGroup(items: [
              _MenuItem(Icons.history_rounded, l.watchHistoryTitle, () => _gated(context, '/history')),
              _MenuItem(Icons.bookmark_border_rounded, l.navMyList, () => context.go('/mylist')),
              // Play Store build pays through Google Play: no saved mobile money or cards.
              if (!AppConfig.isPlayStore)
              _MenuItem(Icons.account_balance_wallet_outlined, l.paymentMethodsTitle, () => _gated(context, '/payment-methods')),
              _MenuItem(Icons.receipt_long_outlined, l.paymentHistoryTitle, () => _gated(context, '/payments')),
            ]),
            const SizedBox(height: 0),
            _MenuGroup(items: [
              _MenuItem(Icons.workspace_premium_outlined, l.vipStoreMenu, () => context.push('/vip')),
              _MenuItem(Icons.settings_outlined, l.settingsTitle, () => context.push('/settings')),
              _MenuItem(Icons.help_outline_rounded, l.helpSupport, () => _support(context)),
            ]),
            const _RequestToPostGroup(),
            if (user != null) ...[
              const SizedBox(height: 14),
              _MenuGroup(items: [
                _MenuItem(Icons.logout_rounded, l.actionLogOut, () => _logout(context), danger: true),
              ]),
            ],
            const SizedBox(height: 24),
            Center(child: Text(l.profileVersion('1.0.0'), style: Theme.of(context).textTheme.labelSmall)),
          ],
        ),
      ),
    );
  }

  static void _gated(BuildContext context, String path) {
    Haptics.tap();
    final auth = context.read<AuthState>();
    context.push(auth.isLoggedIn ? path : '/login');
  }

  static void _support(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.helpSupport),
        content: Text(ctx.l10n.supportBody),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.l10n.actionGotIt))],
      ),
    );
  }

  static Future<void> _logout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.logoutTitle),
        content: Text(ctx.l10n.logoutBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.l10n.actionCancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.l10n.actionLogOut, style: const TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    Haptics.medium();
    final favs = context.read<FavoritesState>();
    await context.read<AuthState>().logout();
    favs.clear();
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.user});
  final User user;
  static const double size = 68;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(user.isVip ? 2 : 0),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: user.isVip ? AppColors.primary : Colors.transparent,
      ),
      child: ClipOval(
        child: user.avatarUrl != null
            ? NetImage(user.avatarUrl)
            : Container(
                color: AppColors.surface2,
                alignment: Alignment.center,
                child: Text(
                  user.initials,
                  style: TextStyle(fontSize: size * 0.34, fontWeight: FontWeight.w800, color: AppColors.text),
                ),
              ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user});
  final User user;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        _Avatar(user: user),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(user.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleLarge),
                  ),
                  if (user.isVip) ...[const SizedBox(width: 8), const VipPill()],
                ],
              ),
              const SizedBox(height: 4),
              Text(user.contact, style: text.bodySmall),
              if (user.isVip && user.activeSubscription?.endsAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  context.l10n.vipUntil(Fmt.date(user.activeSubscription!.endsAt)),
                  style: text.labelSmall!.copyWith(color: AppColors.primary),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _GuestCard extends StatelessWidget {
  const _GuestCard();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.guestTitle, style: text.titleMedium),
                    const SizedBox(height: 2),
                    Text(l.guestMessage, style: text.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: PillButton(label: l.actionLogIn, height: 44, expand: true, onPressed: () => context.push('/login')),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PillButton(
                  label: l.actionSignUp,
                  height: 44,
                  expand: true,
                  secondary: true,
                  onPressed: () => context.push('/register'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WalletRow extends StatelessWidget {
  const _WalletRow({required this.user});
  final User? user;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final sub = user?.activeSubscription;
    final l = context.l10n;
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            onTap: () => context.push('/vip?section=coins'),
            title: l.coinsTitle,
            value: CoinAmount(user?.coins ?? 0, size: 18),
            caption: l.actionTopUp,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            onTap: () => context.push('/vip'),
            title: l.membershipTitle,
            value: Text(
              user?.isVip == true
                  ? 'VIP'
                  : (sub != null && sub.episodesRemaining != null ? l.membershipPack : l.membershipFree),
              style: text.titleMedium!.copyWith(color: user?.isVip == true ? AppColors.primary : AppColors.text),
            ),
            caption: sub != null && !sub.isTimeBased && sub.episodesRemaining != null
                ? l.unlocksLeft(sub.episodesRemaining!)
                : user?.isVip == true
                    ? l.actionManage
                    : l.actionUpgrade,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.title, required this.value, required this.caption, required this.onTap});
  final String title;
  final Widget value;
  final String caption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.card),
        onTap: () {
          Haptics.tap();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: text.labelSmall),
              const SizedBox(height: 6),
              value,
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(caption, style: text.labelSmall!.copyWith(color: AppColors.primary)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VipBanner extends StatelessWidget {
  const _VipBanner({required this.user});
  final User? user;

  @override
  Widget build(BuildContext context) {
    if (user?.isVip == true) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: () {
        Haptics.tap();
        context.push('/vip');
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.card),
          color: AppColors.surface,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.goVip, style: text.titleMedium),
                  Text(context.l10n.goVipPitch(Fmt.money(3000)), style: text.bodySmall),
                ],
              ),
            ),
            PillButton(label: context.l10n.actionJoin, height: 36, onPressed: () => context.push('/vip')),
          ],
        ),
      ),
    );
  }
}

class _MenuItem {
  const _MenuItem(this.icon, this.label, this.onTap, {this.danger = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
}

class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.items});
  final List<_MenuItem> items;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: Icon(items[i].icon, size: 22, color: items[i].danger ? AppColors.danger : AppColors.textMuted),
              title: Text(
                items[i].label,
                style: Theme.of(context).textTheme.titleSmall!.copyWith(
                      color: items[i].danger ? AppColors.danger : AppColors.text,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              trailing: items[i].danger ? null : Icon(Icons.chevron_right_rounded, color: AppColors.textDim),
              onTap: () {
                Haptics.tap();
                items[i].onTap();
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// "Request to post" tile, styled like [_MenuGroup]. Signed-in users with a
/// request see its status and open the status view; others open the form.
class _RequestToPostGroup extends StatefulWidget {
  const _RequestToPostGroup();

  @override
  State<_RequestToPostGroup> createState() => _RequestToPostGroupState();
}

class _RequestToPostGroupState extends State<_RequestToPostGroup> {
  User? _loadedFor;
  StudioApplication? _app;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = context.watch<AuthState>().user;
    // Reload whenever the profile is refreshed or the account changes.
    if (!identical(user, _loadedFor)) {
      _loadedFor = user;
      _load();
    }
  }

  Future<void> _load() async {
    final user = _loadedFor;
    if (user == null) {
      if (_app != null) setState(() => _app = null);
      return;
    }
    try {
      final app = await context.read<StudioService>().myApplication();
      if (mounted && identical(user, _loadedFor)) setState(() => _app = app);
    } catch (_) {
      // Keep the plain tile when offline.
    }
  }

  Future<void> _open() async {
    Haptics.tap();
    await context.push(_loadedFor != null && _app != null ? '/studio/status' : '/studio/apply');
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    final app = _loadedFor == null ? null : _app;
    String? subtitle;
    Color? subtitleColor;
    if (app != null) {
      final status = app.effectiveStatus;
      subtitleColor = studioStatusColor(status);
      final parts = [
        studioStatusLabel(l, status),
        if (status == 'rejected' && (app.rejectionReason ?? '').isNotEmpty) app.rejectionReason!,
        if (status != 'approved') l.studioSamplesCount(app.summary.valid, app.summary.required),
      ];
      subtitle = parts.join('  ·  ');
    }
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        leading: Icon(Icons.video_call_outlined, size: 22, color: AppColors.textMuted),
        title: Text(
          l.requestToPost,
          style: text.titleSmall!.copyWith(color: AppColors.text, fontWeight: FontWeight.w600),
        ),
        subtitle: subtitle == null
            ? null
            : Text(subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: text.labelSmall!.copyWith(color: subtitleColor)),
        trailing: Icon(Icons.chevron_right_rounded, color: AppColors.textDim),
        onTap: _open,
      ),
    );
  }
}
