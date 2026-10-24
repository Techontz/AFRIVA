import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/auth_guard.dart';
import '../../core/haptics.dart';
import '../../core/theme.dart';
import '../../models/drama.dart';
import '../../models/episode.dart';
import '../../models/json.dart';
import '../../services/player_service.dart';
import '../../state/auth_state.dart';
import '../../widgets/badges.dart';
import '../../widgets/buttons.dart';
import '../../widgets/sheet.dart';
import '../../widgets/states.dart';

enum PaywallResult {
  /// The episode was unlocked from the sheet.
  unlocked,

  /// The viewer's entitlements may have changed (login / VIP / top-up) — retry playback.
  retry,
}

/// Lock → paywall bottom sheet: VIP CTA + unlock with coins / episode pack.
Future<PaywallResult?> showPaywallSheet(
  BuildContext context, {
  required Drama drama,
  required Episode episode,
  required UnlockInfo info,
}) {
  return showAfrivaSheet<PaywallResult>(
    context,
    builder: (_) => _PaywallBody(drama: drama, episode: episode, info: info),
  );
}

class _PaywallBody extends StatefulWidget {
  const _PaywallBody({required this.drama, required this.episode, required this.info});
  final Drama drama;
  final Episode episode;
  final UnlockInfo info;

  @override
  State<_PaywallBody> createState() => _PaywallBodyState();
}

class _PaywallBodyState extends State<_PaywallBody> {
  String? _busy;

  int get _coinsRequired =>
      widget.info.coinsRequired > 0 ? widget.info.coinsRequired : widget.drama.coinsPerEpisode;

  Future<void> _unlock(String method) async {
    setState(() => _busy = method);
    final auth = context.read<AuthState>();
    try {
      final data = await context.read<PlayerService>().unlock(widget.episode.id, method);
      final coins = asIntOrNull(data['user_coins'] ?? data['coins'] ?? asMap(data['user'])['coins']);
      if (coins != null) auth.setCoins(coins);
      auth.refresh();
      Haptics.success();
      if (mounted) Navigator.of(context).pop(PaywallResult.unlocked);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = null);
        showSnack(context, errorMessage(e), error: true);
      }
    }
  }

  Future<void> _login() async {
    final nav = Navigator.of(context);
    final ok = await requireLogin(context);
    if (ok) nav.pop(PaywallResult.retry);
  }

  Future<void> _openStore({String? section}) async {
    final nav = Navigator.of(context);
    final router = GoRouter.of(context);
    await router.push(section == null ? '/vip' : '/vip?section=$section');
    nav.pop(PaywallResult.retry);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final auth = context.watch<AuthState>();
    final loggedIn = auth.isLoggedIn && !widget.info.requiresLogin;
    final balance = loggedIn ? (widget.info.userCoins > 0 ? widget.info.userCoins : auth.coins) : 0;
    final enough = balance >= _coinsRequired && _coinsRequired > 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.brandGradient),
              child: const Icon(Icons.lock_rounded, color: Colors.white, size: 28),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Unlock Episode ${widget.episode.number}',
            textAlign: TextAlign.center,
            style: text.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            'Keep watching "${widget.drama.title}" — the story is just getting good.',
            textAlign: TextAlign.center,
            style: text.bodyMedium,
          ),
          const SizedBox(height: 20),

          // VIP CTA
          _VipCard(onTap: _busy == null ? () => _openStore() : null),
          const SizedBox(height: 12),

          if (!loggedIn) ...[
            PillButton(
              label: 'Log in to unlock',
              icon: Icons.login_rounded,
              expand: true,
              onPressed: _login,
            ),
          ] else ...[
            // Coins option
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadii.card),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text('Unlock with coins', style: text.titleSmall),
                      const Spacer(),
                      Text('Balance ', style: text.labelSmall),
                      CoinAmount(balance, size: 13),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (enough)
                    PillButton(
                      label: 'Unlock for $_coinsRequired coins',
                      icon: Icons.lock_open_rounded,
                      expand: true,
                      height: 46,
                      loading: _busy == 'coins',
                      onPressed: _busy == null ? () => _unlock('coins') : null,
                    )
                  else ...[
                    Text(
                      'You need $_coinsRequired coins — top up ${_coinsRequired - balance} more.',
                      style: text.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    PillButton(
                      label: 'Get coins',
                      icon: Icons.add_circle_outline_rounded,
                      expand: true,
                      height: 46,
                      onPressed: _busy == null ? () => _openStore(section: 'coins') : null,
                    ),
                  ],
                ],
              ),
            ),
            if (widget.info.canUsePack) ...[
              const SizedBox(height: 10),
              PillButton(
                label: widget.info.episodesRemaining > 0
                    ? 'Use episode pack (${widget.info.episodesRemaining} left)'
                    : 'Use 1 episode from my pack',
                icon: Icons.confirmation_number_outlined,
                secondary: true,
                expand: true,
                height: 46,
                loading: _busy == 'episode_pack',
                onPressed: _busy == null ? () => _unlock('episode_pack') : null,
              ),
            ],
          ],
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Not now'),
          ),
        ],
      ),
    );
  }
}

class _VipCard extends StatelessWidget {
  const _VipCard({required this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.card),
        onTap: onTap == null
            ? null
            : () {
                Haptics.tap();
                onTap!();
              },
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.card),
            gradient: AppColors.vipCardGradient,
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              const Icon(Icons.workspace_premium_rounded, color: AppColors.primary, size: 34),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Join Afriva VIP', style: text.titleSmall!.copyWith(color: AppColors.primary)),
                    const SizedBox(height: 2),
                    Text('Every episode unlocked. No waiting.', style: text.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}
