import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/haptics.dart';
import '../../core/payments.dart';
import '../../core/theme.dart';
import '../../l10n/l10n.dart';
import '../../models/commerce.dart';
import '../../services/commerce_service.dart';
import '../../widgets/buttons.dart';
import '../../widgets/sheet.dart';
import '../../widgets/skeletons.dart';
import '../../widgets/states.dart';
import '../vip/payment_widgets.dart';
import '../vip/phone_field.dart';

/// Saved numbers and cards: set the default, remove, add a number.
class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  List<SavedMethod>? _items;
  Object? _error;

  /// Cards are typed on the payment partner's secure page, so none get saved.
  bool _hostedCards = false;

  @override
  void initState() {
    super.initState();
    _load();
    context.read<CommerceService>().checkoutOptions().then((o) {
      if (mounted && o.hostedCards != _hostedCards) setState(() => _hostedCards = o.hostedCards);
    }).catchError((_) {});
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final items = await context.read<CommerceService>().savedMethods();
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _actions(SavedMethod m) async {
    final l = context.l10n;
    final d = describeSaved(context, m);
    final action = await showAfrivaSheet<String>(
      context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                brandMarkFor(m, size: 44),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.title, style: Theme.of(ctx).textTheme.titleMedium),
                      Text(d.subtitle, style: Theme.of(ctx).textTheme.labelSmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (!m.isDefault && !m.isExpired)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: const Icon(Icons.star_outline_rounded),
                title: Text(l.paymentMethodsMakeDefault),
                onTap: () => Navigator.pop(ctx, 'default'),
              ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
              title: Text(l.paymentMethodsRemove, style: const TextStyle(color: AppColors.danger)),
              onTap: () => Navigator.pop(ctx, 'remove'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    final commerce = context.read<CommerceService>();
    try {
      if (action == 'default') {
        await commerce.makeDefault(m.id);
        if (mounted) showSnack(context, l.paymentMethodsDefaultSet);
      } else {
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l.paymentMethodsRemoveTitle),
            content: Text(l.paymentMethodsRemoveBody),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.actionCancel)),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l.paymentMethodsRemove, style: const TextStyle(color: AppColors.danger)),
              ),
            ],
          ),
        );
        if (ok != true) return;
        await commerce.removeMethod(m.id);
        Haptics.medium();
        if (mounted) showSnack(context, l.paymentMethodsRemoved);
      }
      await _load();
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  Future<void> _addNumber() async {
    final added = await showAfrivaSheet<bool>(context, builder: (_) => const _AddNumberSheet());
    if (added == true && mounted) {
      showSnack(context, context.l10n.paymentMethodsAdded);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final items = _items;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.paymentMethodsTitle),
        actions: [
          IconButton(
            tooltip: l.paymentHistoryTitle,
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => context.push('/payments'),
          ),
        ],
      ),
      body: items == null
          ? (_error != null ? ErrorState(error: _error!, onRetry: _load) : const ListSkeleton(thumbWidth: 44, count: 3))
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16, 8, 16, bottom + 24),
                children: [
                  if (items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36),
                      child: StateMessage(
                        icon: Icons.account_balance_wallet_outlined,
                        title: l.paymentMethodsEmptyTitle,
                        message: l.paymentMethodsEmptyBody,
                      ),
                    ),
                  for (final m in items) ...[
                    Builder(builder: (context) {
                      final d = describeSaved(context, m);
                      return PayOptionTile(
                        key: ValueKey('pm-${m.id}'),
                        leading: brandMarkFor(m),
                        title: d.title,
                        subtitle: d.subtitle,
                        subtitleColor: m.isExpired ? AppColors.danger : null,
                        badge: m.isDefault ? l.payDefault : null,
                        trailing: Icon(Icons.more_horiz_rounded, color: AppColors.textMuted),
                        onTap: () => _actions(m),
                      );
                    }),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 8),
                  PillButton(
                    key: const ValueKey('add-number'),
                    label: l.paymentMethodsAddNumber,
                    icon: Icons.add_rounded,
                    secondary: true,
                    expand: true,
                    onPressed: _addNumber,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.credit_card_rounded, size: 15, color: AppColors.textDim),
                      const SizedBox(width: 6),
                      Flexible(child: Text(_hostedCards ? l.paymentMethodsCardHostedNote : l.paymentMethodsCardNote, style: text.labelSmall, textAlign: TextAlign.center)),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(l.paySecureNote, style: text.labelSmall, textAlign: TextAlign.center),
                ],
              ),
            ),
    );
  }
}

class _AddNumberSheet extends StatefulWidget {
  const _AddNumberSheet();

  @override
  State<_AddNumberSheet> createState() => _AddNumberSheetState();
}

class _AddNumberSheetState extends State<_AddNumberSheet> {
  final _form = GlobalKey<FormState>();
  final _phone = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<CommerceService>().addNumber(TzPhone.normalize(_phone.text)!);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e is ApiException ? (e.fieldError('phone') ?? e.message) : errorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.paymentMethodsAddNumber, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 18),
            MobileMoneyField(
              controller: _phone,
              autofocus: true,
              serverError: _error,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 20),
            PillButton(
              label: l.paymentMethodsSaveNumber,
              expand: true,
              loading: _busy,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
