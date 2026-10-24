import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/commerce.dart';
import '../../services/me_service.dart';
import '../../widgets/skeletons.dart';
import '../../widgets/states.dart';

class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  List<Payment>? _items;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final items = await context.read<MeService>().payments();
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      appBar: AppBar(title: const Text('Payment history')),
      body: items == null
          ? (_error != null ? ErrorState(error: _error!, onRetry: _load) : const ListSkeleton(thumbWidth: 40))
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _load,
              child: items.isEmpty
                  ? const ScrollableFill(
                      child: StateMessage(
                        icon: Icons.receipt_long_outlined,
                        title: 'No payments yet',
                        message: 'Your VIP, episode pack and coin purchases will appear here.',
                      ),
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.paddingOf(context).bottom + 24),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _PaymentTile(payment: items[i]),
                    ),
            ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.payment});
  final Payment payment;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final (color, icon) = switch (payment.status) {
      'success' => (AppColors.success, Icons.check_circle_rounded),
      'failed' || 'cancelled' => (AppColors.danger, Icons.cancel_rounded),
      _ => (AppColors.primary, Icons.schedule_rounded),
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(payment.planName ?? 'Afriva purchase', style: text.titleSmall),
                const SizedBox(height: 2),
                GestureDetector(
                  onLongPress: () {
                    Clipboard.setData(ClipboardData(text: payment.reference));
                    showSnack(context, 'Reference copied');
                  },
                  child: Text(
                    '${payment.reference}${payment.methodCode != null ? ' · ${payment.methodCode!.toUpperCase()}' : ''}',
                    style: text.labelSmall,
                  ),
                ),
                const SizedBox(height: 2),
                Text(Fmt.dateTime(payment.paidAt ?? payment.createdAt), style: text.labelSmall),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(Fmt.money(payment.amount, payment.currency), style: text.titleSmall),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Text(
                  payment.status.isEmpty
                      ? 'Pending'
                      : payment.status[0].toUpperCase() + payment.status.substring(1),
                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
