import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/haptics.dart';
import '../../core/theme.dart';
import '../../models/user.dart';
import '../../state/auth_state.dart';
import '../../state/favorites_state.dart';
import '../../widgets/badges.dart';
import '../../widgets/buttons.dart';
import '../../widgets/net_image.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final user = auth.user;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: 'Settings',
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
            const SizedBox(height: 22),
            _MenuGroup(items: [
              _MenuItem(Icons.history_rounded, 'Watch history', () => _gated(context, '/history')),
              _MenuItem(Icons.bookmark_border_rounded, 'My List', () => context.go('/mylist')),
              _MenuItem(Icons.receipt_long_outlined, 'Payment history', () => _gated(context, '/payments')),
            ]),
            const SizedBox(height: 14),
            _MenuGroup(items: [
              _MenuItem(Icons.workspace_premium_outlined, 'VIP & coins store', () => context.push('/vip')),
              _MenuItem(Icons.settings_outlined, 'Settings', () => context.push('/settings')),
              _MenuItem(Icons.help_outline_rounded, 'Help & support', () => _support(context)),
            ]),
            if (user != null) ...[
              const SizedBox(height: 14),
              _MenuGroup(items: [
                _MenuItem(Icons.logout_rounded, 'Log out', () => _logout(context), danger: true),
              ]),
            ],
            const SizedBox(height: 24),
            Center(child: Text('Afriva · v1.0.0', style: Theme.of(context).textTheme.labelSmall)),
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
        title: const Text('Help & support'),
        content: const Text(
          'Questions about VIP, coins or payments? Email support@afriva.com and our team will help '
          'within 24 hours. Include your payment reference if your question is about a payment.',
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Got it'))],
      ),
    );
  }

  static Future<void> _logout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('Your list, history and VIP stay safe in your account.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log out', style: TextStyle(color: AppColors.danger)),
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
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: user.isVip ? AppColors.brandGradient : AppColors.brandGradient,
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
                  'VIP until ${Fmt.date(user.activeSubscription!.endsAt)}',
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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.surface2),
                child: const Icon(Icons.person_rounded, color: AppColors.textDim, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Welcome to Afriva', style: text.titleMedium),
                    const SizedBox(height: 2),
                    Text('Log in to sync your list, history and VIP.', style: text.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: PillButton(label: 'Log in', height: 44, expand: true, onPressed: () => context.push('/login')),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PillButton(
                  label: 'Sign up',
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
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            onTap: () => context.push('/vip?section=coins'),
            title: 'Coins',
            value: CoinAmount(user?.coins ?? 0, size: 18),
            caption: 'Top up',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            onTap: () => context.push('/vip'),
            title: 'Membership',
            value: Text(
              user?.isVip == true ? 'VIP' : (sub != null && sub.episodesRemaining != null ? 'Pack' : 'Free'),
              style: text.titleMedium!.copyWith(color: user?.isVip == true ? AppColors.primary : AppColors.text),
            ),
            caption: sub != null && !sub.isTimeBased && sub.episodesRemaining != null
                ? '${sub.episodesRemaining} unlocks left'
                : user?.isVip == true
                    ? 'Manage'
                    : 'Upgrade',
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
                  const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.primary),
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
          gradient: AppColors.vipCardGradient,
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.workspace_premium_rounded, color: AppColors.primary, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Go VIP', style: text.titleMedium!.copyWith(color: AppColors.primary)),
                  Text('Unlock every episode from 3,000 TZS a week', style: text.bodySmall),
                ],
              ),
            ),
            PillButton(label: 'Join', height: 36, onPressed: () => context.push('/vip')),
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
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            ListTile(
              leading: Icon(items[i].icon, color: items[i].danger ? AppColors.danger : AppColors.textMuted),
              title: Text(
                items[i].label,
                style: Theme.of(context).textTheme.titleSmall!.copyWith(
                      color: items[i].danger ? AppColors.danger : AppColors.text,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              trailing: items[i].danger ? null : const Icon(Icons.chevron_right_rounded, color: AppColors.textDim),
              onTap: () {
                Haptics.tap();
                items[i].onTap();
              },
            ),
            if (i < items.length - 1) const Divider(indent: 56),
          ],
        ],
      ),
    );
  }
}
