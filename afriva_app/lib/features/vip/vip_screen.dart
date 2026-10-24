import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/auth_guard.dart';
import '../../core/format.dart';
import '../../core/haptics.dart';
import '../../core/theme.dart';
import '../../models/commerce.dart';
import '../../services/commerce_service.dart';
import '../../state/auth_state.dart';
import '../../widgets/badges.dart';
import '../../widgets/buttons.dart';
import '../../widgets/skeletons.dart';
import '../../widgets/states.dart';
import 'checkout_screen.dart';

/// VIP store: subscriptions, episode packs and coin packs from `/plans`.
class VipScreen extends StatefulWidget {
  const VipScreen({super.key, this.initialSection});

  /// `vip` | `episodes` | `coins` — scrolls that group into view.
  final String? initialSection;

  @override
  State<VipScreen> createState() => _VipScreenState();
}

class _VipScreenState extends State<VipScreen> {
  List<Plan>? _plans;
  Object? _error;
  Plan? _selected;
  final _sectionKeys = {'vip': GlobalKey(), 'episodes': GlobalKey(), 'coins': GlobalKey()};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final plans = await context.read<CommerceService>().plans();
      if (!mounted) return;
      setState(() {
        _plans = plans;
        _selected = _defaultSelection(plans);
      });
      final key = _sectionKeys[widget.initialSection];
      if (key != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final ctx = key.currentContext;
          if (ctx != null) {
            Scrollable.ensureVisible(ctx, duration: AppMotion.slow, curve: AppMotion.curve);
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Plan? _defaultSelection(List<Plan> plans) {
    bool Function(Plan) match = switch (widget.initialSection) {
      'coins' => (p) => p.isCoins,
      'episodes' => (p) => p.isEpisodePack,
      _ => (p) => p.isSubscription,
    };
    final group = plans.where(match).toList();
    if (group.isEmpty) return plans.firstOrNull;
    return group.where((p) => p.isPopular).firstOrNull ?? group.first;
  }

  Future<void> _continue() async {
    final plan = _selected;
    if (plan == null) return;
    if (!await requireLogin(context)) return;
    if (!mounted) return;
    final paid = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(builder: (_) => CheckoutScreen(plan: plan)),
    );
    if (paid == true && mounted) {
      context.read<AuthState>().refresh();
      if (context.canPop()) context.pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plans = _plans;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      appBar: AppBar(title: const Text('Afriva VIP')),
      body: plans == null
          ? (_error != null ? ErrorState(error: _error!, onRetry: _load) : const ListSkeleton(count: 5))
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _load,
              child: ListView(
                padding: EdgeInsets.fromLTRB(16, 4, 16, bottom + 120),
                children: [
                  const _StatusHeader(),
                  ..._group('vip', 'VIP subscriptions', 'Unlimited access to every episode',
                      plans.where((p) => p.isSubscription).toList()),
                  ..._group('episodes', 'Episode packs', 'Unlock any episodes you choose',
                      plans.where((p) => p.isEpisodePack).toList()),
                  ..._group('coins', 'Coins', 'Unlock single episodes with coins',
                      plans.where((p) => p.isCoins).toList()),
                  if (plans.isEmpty)
                    const StateMessage(icon: Icons.storefront_outlined, title: 'No plans available right now'),
                  const SizedBox(height: 16),
                  Text(
                    'Payments are processed securely by your chosen provider. '
                    'VIP renews only when you pay again — no automatic charges.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
      bottomNavigationBar: _selected == null
          ? null
          : Container(
              padding: EdgeInsets.fromLTRB(16, 12, 16, bottom + 12),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_selected!.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelMedium!.copyWith(color: AppColors.textMuted)),
                        Text(Fmt.money(_selected!.price, _selected!.currency),
                            style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ),
                  ),
                  PillButton(
                    label: 'Continue',
                    icon: Icons.lock_rounded,
                    light: _selected!.isSubscription,
                    onPressed: _continue,
                  ),
                ],
              ),
            ),
    );
  }

  List<Widget> _group(String key, String title, String subtitle, List<Plan> items) {
    if (items.isEmpty) return const [];
    final text = Theme.of(context).textTheme;
    return [
      Padding(
        key: _sectionKeys[key],
        padding: const EdgeInsets.only(top: 24, bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: text.titleMedium!.copyWith(fontSize: 18)),
            const SizedBox(height: 2),
            Text(subtitle, style: text.labelSmall),
          ],
        ),
      ),
      if (key == 'coins')
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.35,
          children: [for (final p in items) _CoinPlanCard(plan: p, selected: _selected?.id == p.id, onTap: () => _select(p))],
        )
      else
        for (final p in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _PlanCard(plan: p, selected: _selected?.id == p.id, onTap: () => _select(p)),
          ),
    ];
  }

  void _select(Plan p) {
    Haptics.tap();
    setState(() => _selected = p);
  }
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final text = Theme.of(context).textTheme;
    final sub = auth.user?.activeSubscription;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: AppColors.vipCardGradient,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (r) => AppColors.brandGradient.createShader(r),
                child: const Icon(Icons.workspace_premium_rounded, size: 34, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  auth.isVip ? "You're VIP" : 'Watch everything with VIP',
                  style: text.titleLarge!.copyWith(color: AppColors.primary),
                ),
              ),
              if (auth.isLoggedIn) CoinAmount(auth.coins, size: 15),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            auth.isVip && sub?.endsAt != null
                ? '${sub!.label} · active until ${Fmt.date(sub.endsAt)}'
                : 'Unlimited episodes · New dramas every week · HD streaming',
            style: text.bodySmall!.copyWith(color: AppColors.chipText),
          ),
          if (sub != null && !sub.isTimeBased && sub.episodesRemaining != null) ...[
            const SizedBox(height: 6),
            Text('${sub.episodesRemaining} pack episodes remaining', style: text.labelSmall),
          ],
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.selected, required this.onTap});
  final Plan plan;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final accent = plan.isSubscription ? AppColors.primary : AppColors.primary;
    final perDay = plan.pricePerDay;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.normal,
        curve: AppMotion.curve,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.08) : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: selected ? accent : AppColors.border, width: selected ? 1.6 : 1),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: AppMotion.normal,
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: selected ? accent : AppColors.textDim, width: 2),
              ),
              alignment: Alignment.center,
              child: AnimatedScale(
                duration: AppMotion.normal,
                scale: selected ? 1 : 0,
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: accent),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: Text(plan.name, style: text.titleSmall!.copyWith(fontSize: 15))),
                      if (plan.isPopular) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: AppColors.brandGradient,
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                          ),
                          child: const Text('Most popular',
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    plan.description.isNotEmpty
                        ? plan.description
                        : plan.isEpisodePack
                            ? 'Unlock ${plan.episodeQuota ?? ''} episodes of any drama'
                            : 'All episodes unlocked for ${plan.durationDays ?? ''} days',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelSmall,
                  ),
                  if (plan.features.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    for (final f in plan.features.take(3))
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            Icon(Icons.check_rounded, size: 14, color: accent),
                            const SizedBox(width: 4),
                            Expanded(child: Text(f, style: text.labelSmall)),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(Fmt.grouped(plan.price), style: text.titleMedium!.copyWith(fontSize: 18)),
                Text('${plan.currency} ${plan.periodLabel}'.trim(), style: text.labelSmall),
                if (perDay != null && plan.isSubscription)
                  Text('≈ ${Fmt.grouped(perDay)}/day',
                      style: text.labelSmall!.copyWith(color: accent, fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CoinPlanCard extends StatelessWidget {
  const _CoinPlanCard({required this.plan, required this.selected, required this.onTap});
  final Plan plan;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final bonus = plan.bonusCoins ?? 0;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.normal,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.08) : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 1.6 : 1),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CoinAmount(plan.coins ?? 0, size: 20),
                if (bonus > 0)
                  Text('+$bonus bonus', style: text.labelSmall!.copyWith(color: AppColors.success)),
                const Spacer(),
                Text(Fmt.money(plan.price, plan.currency), style: text.titleSmall),
              ],
            ),
            if (plan.isPopular)
              const Positioned(top: 0, right: 0, child: Icon(Icons.star_rounded, color: AppColors.primary, size: 18)),
          ],
        ),
      ),
    );
  }
}
