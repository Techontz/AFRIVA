import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../models/commerce.dart';
import '../../services/me_service.dart';
import '../../state/auth_state.dart';
import '../../widgets/badges.dart';
import '../../widgets/buttons.dart';
import '../../widgets/skeletons.dart';
import '../../widgets/states.dart';

/// Coin balance and every change to it (purchases, bonuses, unlocks, refunds).
class CoinHistoryScreen extends StatefulWidget {
  const CoinHistoryScreen({super.key});

  @override
  State<CoinHistoryScreen> createState() => _CoinHistoryScreenState();
}

class _CoinHistoryScreenState extends State<CoinHistoryScreen> {
  List<CoinTransaction>? _items;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final items = await context.read<MeService>().coins();
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  String _label(BuildContext context, CoinTransaction t) => switch (t.type) {
        'purchase' => context.tr('Coins purchased'),
        'bonus' => context.tr('Bonus coins'),
        'unlock' => t.dramaTitle != null
            ? context.tr('Unlocked {title} · EP {n}', {'title': t.dramaTitle!, 'n': t.episodeNumber ?? ''})
            : context.tr('Episode unlocked'),
        'refund' => context.tr('Refund'),
        'admin_adjust' => context.tr('Adjustment by AFRIVA'),
        _ => t.description ?? t.type,
      };

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final text = Theme.of(context).textTheme;
    final balance = context.watch<AuthState>().coins;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('My coins'))),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.paddingOf(context).bottom + 24),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(gradient: AppColors.vipCardGradient, borderRadius: BorderRadius.circular(AppRadii.card)),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.tr('Balance'), style: text.labelMedium),
                        const SizedBox(height: 4),
                        CoinAmount(balance, size: 22),
                      ],
                    ),
                  ),
                  PillButton(
                    label: context.tr('Get coins'),
                    icon: Icons.add_rounded,
                    height: 40,
                    onPressed: () => context.push('/vip?section=coins'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (items == null)
              _error != null
                  ? ErrorState(error: _error!, onRetry: _load, compact: true)
                  : const SizedBox(height: 300, child: ListSkeleton(count: 5, thumbWidth: 32))
            else if (items.isEmpty)
              StateMessage(icon: Icons.toll_outlined, title: context.tr('No coin activity yet'), compact: true)
            else
              for (final t in items)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    t.amount >= 0 ? Icons.add_circle_outline_rounded : Icons.remove_circle_outline_rounded,
                    color: t.amount >= 0 ? AppColors.success : AppColors.primary,
                  ),
                  title: Text(_label(context, t), maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text(Fmt.dateTime(t.createdAt)),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${t.amount > 0 ? '+' : ''}${t.amount}', style: text.titleSmall),
                      Text(context.tr('Balance {n}', {'n': t.balanceAfter}), style: text.labelSmall),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
