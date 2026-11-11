import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/payments.dart';
import '../../core/theme.dart';
import '../../l10n/l10n.dart';
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
      appBar: AppBar(title: Text(context.l10n.paymentHistoryTitle)),
      body: items == null
          ? (_error != null ? ErrorState(error: _error!, onRetry: _load) : const ListSkeleton(thumbWidth: 40))
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _load,
              child: items.isEmpty
                  ? ScrollableFill(
                      child: StateMessage(
                        icon: Icons.receipt_long_outlined,
                        title: context.l10n.paymentsEmptyTitle,
                        message: context.l10n.paymentsEmptyMessage,
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

  /// "M-Pesa +255 75• ••• 456" or "Visa" for the history row.
  static String? _methodLabel(Payment p) {
    final code = p.methodCode;
    if (code == null || code.isEmpty) return null;
    final network = MobileNetwork.byCode(code);
    if (network != null) {
      return p.phone != null && p.phone!.isNotEmpty ? '${network.name} ${TzPhone.masked(p.phone)}' : network.name;
    }
    return CardBrand.fromCode(code)?.label ?? code.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    final color = switch (payment.status) {
      'success' => AppColors.textMuted,
      'failed' || 'cancelled' => AppColors.danger,
      _ => AppColors.primary,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(payment.planName ?? l.paymentDefaultName, style: text.titleSmall),
                const SizedBox(height: 2),
                GestureDetector(
                  onLongPress: () {
                    Clipboard.setData(ClipboardData(text: payment.reference));
                    showSnack(context, l.referenceCopied);
                  },
                  child: Text(
                    [
                      ?_methodLabel(payment),
                      payment.reference,
                    ].join(' \u00b7 '),
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
              Text(
                l.paymentStatus(payment.status),
                style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
