import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/auth_guard.dart';
import '../../core/config.dart';
import '../../core/format.dart';
import '../../core/haptics.dart';
import '../../core/theme.dart';
import '../../l10n/l10n.dart';
import '../../models/commerce.dart';
import '../../services/commerce_service.dart';
import '../../services/play_billing.dart';
import '../../state/auth_state.dart';
import '../../widgets/badges.dart';
import '../../widgets/buttons.dart';
import '../../widgets/skeletons.dart';
import '../../widgets/states.dart';
import 'checkout_screen.dart';

/// VIP store: subscriptions, episode packs and coin packs from `/plans`.
class VipScreen extends StatefulWidget {
  const VipScreen({super.key, this.initialSection});

  /// `vip` | `episodes` | `coins`: scrolls that group into view.
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
      var plans = await context.read<CommerceService>().plans();
      // Play Store build: only what is sold through Google Play.
      if (AppConfig.isPlayStore) plans = plans.where((p) => p.playProductId != null).toList();
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
    if (AppConfig.isPlayStore) return _buyOnPlay(plan);
    final paid = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(builder: (_) => CheckoutScreen(plan: plan)),
    );
    if (paid == true && mounted) {
      context.read<AuthState>().refresh();
      if (context.canPop()) context.pop(true);
    }
  }

  /// Google Play Billing: opens Play's payment sheet and waits for the verified result.
  Future<void> _buyOnPlay(Plan plan) async {
    final l = context.l10n;
    final billing = context.read<PlayBilling>();
    final id = plan.playProductId!;
    final nav = Navigator.of(context, rootNavigator: true);
    var dialogOpen = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(children: [
            const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.4)),
            const SizedBox(width: 16),
            Expanded(child: Text(l.playOpening)),
          ]),
        ),
      ),
    ).then((_) => dialogOpen = false);
    void closeDialog() {
      if (dialogOpen) nav.pop();
      dialogOpen = false;
    }

    try {
      final product = (await billing.products({id}))[id];
      if (product == null) {
        closeDialog();
        if (mounted) showSnack(context, l.playUnavailable);
        return;
      }
      final result = billing.events.firstWhere((e) => e.productId == id);
      if (!await billing.buy(product)) {
        closeDialog();
        return;
      }
      final event = await result.timeout(const Duration(minutes: 10));
      closeDialog();
      if (!mounted) return;
      switch (event.outcome) {
        case PlayPurchaseOutcome.success:
          Haptics.success();
          await showDialog<void>(
            context: context,
            builder: (c) => AlertDialog(
              icon: const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 40),
              content: Text(l.playSuccess, textAlign: TextAlign.center),
              actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text(l.actionContinue))],
            ),
          );
          if (mounted && context.canPop()) context.pop(true);
        case PlayPurchaseOutcome.pending:
          showSnack(context, l.playPending);
        case PlayPurchaseOutcome.cancelled:
          break;
        case PlayPurchaseOutcome.failed:
          showSnack(context, event.message?.isNotEmpty == true ? event.message! : l.playFailed);
      }
    } catch (_) {
      closeDialog();
      if (mounted) showSnack(context, l.playFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plans = _plans;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.paywallJoinVipTitle)),
      body: plans == null
          ? (_error != null ? ErrorState(error: _error!, onRetry: _load) : const ListSkeleton(count: 5))
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _load,
              child: ListView(
                padding: EdgeInsets.fromLTRB(16, 4, 16, bottom + 120),
                children: [
                  const _StatusHeader(),
                  ..._group('vip', l.vipSubscriptions, l.vipSubscriptionsSubtitle,
                      plans.where((p) => p.isSubscription).toList()),
                  ..._group('episodes', l.vipEpisodePacks, l.vipEpisodePacksSubtitle,
                      plans.where((p) => p.isEpisodePack).toList()),
                  ..._group('coins', l.coinsTitle, l.vipCoinsSubtitle,
                      plans.where((p) => p.isCoins).toList()),
                  if (plans.isEmpty)
                    StateMessage(icon: Icons.storefront_outlined, title: l.vipNoPlans),
                  const SizedBox(height: 16),
                  Text(
                    AppConfig.isPlayStore ? l.vipPlayNote : l.vipPaymentsNote,
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
              color: AppColors.bg,
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
                    label: l.actionContinue,
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
        padding: const EdgeInsets.only(top: 28, bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: text.titleLarge!.copyWith(fontSize: 19, fontWeight: FontWeight.w700)),
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
            child: _PlanCard(plan: p, savings: p.savingsAgainst(items), selected: _selected?.id == p.id, onTap: () => _select(p)),
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
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      child: Column(
        children: [
          Text(
            auth.isVip ? l.vipYoureVip : l.vipWatchEverything,
            textAlign: TextAlign.center,
            style: text.headlineSmall!.copyWith(fontSize: 28, height: 1.12),
          ),
          const SizedBox(height: 10),
          Text(
            auth.isVip && sub?.endsAt != null
                ? l.vipActiveUntil(sub!.label, Fmt.date(sub.endsAt))
                : l.vipPerks,
            textAlign: TextAlign.center,
            style: text.bodyMedium!.copyWith(fontSize: 15),
          ),
          if (sub != null && !sub.isTimeBased && sub.episodesRemaining != null) ...[
            const SizedBox(height: 6),
            Text(l.vipPackRemaining(sub.episodesRemaining!), style: text.labelSmall),
          ],
          if (auth.isLoggedIn) ...[
            const SizedBox(height: 12),
            CoinAmount(auth.coins, size: 15),
          ],
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.selected, required this.onTap, this.savings});
  final Plan plan;
  final int? savings;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    const accent = AppColors.primary;
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
          border: Border.all(color: selected ? accent : Colors.transparent, width: 1.2),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: Text(plan.name, style: text.titleSmall!.copyWith(fontSize: 15))),
                      if (plan.isPopular) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(l.vipMostPopular,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppColors.primary, fontSize: 11.5, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    plan.description.isNotEmpty
                        ? plan.description
                        : plan.isEpisodePack
                            ? l.vipPackDescription(plan.episodeQuota ?? 0)
                            : l.vipSubscriptionDescription(plan.durationDays ?? 0),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelSmall,
                  ),
                  if (savings != null) ...[
                    const SizedBox(height: 8),
                    _SaveBadge(l.vipSave(Fmt.grouped(savings!))),
                  ],
                  if (plan.features.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    for (final f in plan.features.take(3))
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            Icon(Icons.check_rounded, size: 14, color: AppColors.textDim),
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
                  Text(l.vipPerDay(Fmt.grouped(perDay)),
                      style: text.labelSmall!.copyWith(color: accent, fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Green "Save TZS 2,000" pill on subscriptions that beat the shorter plan.
class _SaveBadge extends StatelessWidget {
  const _SaveBadge(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.savings_outlined, size: 13, color: AppColors.success),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(color: AppColors.success, fontSize: 11.5, fontWeight: FontWeight.w800)),
          ],
        ),
      );
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
          border: Border.all(color: selected ? AppColors.primary : Colors.transparent, width: 1.2),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CoinAmount(plan.coins ?? 0, size: 20),
                if (bonus > 0)
                  Text(context.l10n.vipBonus(bonus), style: text.labelSmall!.copyWith(color: AppColors.success)),
                const Spacer(),
                Text(Fmt.money(plan.price, plan.currency), style: text.titleSmall),
              ],
            ),
            if (plan.isPopular)
              const Positioned(top: 0, right: 0, child: DotMarker()),
          ],
        ),
      ),
    );
  }
}

/// Small quiet marker for the most popular coin pack.
class DotMarker extends StatelessWidget {
  const DotMarker({super.key});

  @override
  Widget build(BuildContext context) => Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primary),
      );
}
