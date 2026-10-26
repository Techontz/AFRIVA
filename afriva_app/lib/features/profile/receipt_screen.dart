import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../models/commerce.dart';
import '../../services/commerce_service.dart';
import '../../widgets/afriva_logo.dart';
import '../../widgets/skeletons.dart';
import '../../widgets/states.dart';
import 'payment_history_screen.dart' show paymentStatusLabel;

/// Receipt for a confirmed payment (`GET /me/payments/{reference}/receipt`).
class ReceiptScreen extends StatefulWidget {
  const ReceiptScreen({super.key, required this.reference});
  final String reference;

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  Receipt? _receipt;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final r = await context.read<CommerceService>().receipt(widget.reference);
      if (mounted) setState(() => _receipt = r);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _receipt;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Receipt'))),
      body: r == null
          ? (_error != null ? ErrorState(error: _error!, onRetry: _load) : const ListSkeleton(count: 3))
          : ListView(
              padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.paddingOf(context).bottom + 24),
              children: [_ReceiptCard(receipt: r)],
            ),
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({required this.receipt});
  final Receipt receipt;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final r = receipt;
    final rows = <(String, String)>[
      (context.tr('Receipt no.'), r.receiptNumber ?? '-'),
      (context.tr('Date'), Fmt.dateTime(r.issuedAt)),
      (context.tr('Item'), r.itemName ?? '-'),
      if (r.itemDelivered != null) (context.tr('You received'), r.itemDelivered!),
      (context.tr('Payment method'), r.methodName),
      (context.tr('Reference'), r.reference),
      if (r.providerReference != null) (context.tr('Provider reference'), r.providerReference!),
      if (r.customerName != null) (context.tr('Customer'), r.customerName!),
      if (r.customerContact != null) (context.tr('Contact'), r.customerContact!),
      (context.tr('Status'), paymentStatusLabel(context, r.status)),
      if (r.refundedAmount > 0) (context.tr('Refunded'), Fmt.money(r.refundedAmount, r.currency)),
    ];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: AfrivaLogo(size: 22)),
          const SizedBox(height: 14),
          Center(child: Text(Fmt.money(r.amount, r.currency), style: text.headlineSmall)),
          const SizedBox(height: 4),
          Center(child: Text(context.tr('Paid to {seller}', {'seller': r.sellerName}), style: text.labelSmall)),
          const Divider(height: 28),
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 130, child: Text(label, style: text.labelMedium!.copyWith(color: AppColors.textMuted))),
                  Expanded(
                    child: GestureDetector(
                      onLongPress: () {
                        Clipboard.setData(ClipboardData(text: value));
                        showSnack(context, context.tr('Copied'));
                      },
                      child: Text(value, style: text.labelLarge, textAlign: TextAlign.right),
                    ),
                  ),
                ],
              ),
            ),
          if (r.sellerEmail != null) ...[
            const Divider(height: 28),
            Text(context.tr('Questions? Contact {email}', {'email': r.sellerEmail!}),
                style: text.labelSmall, textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}
