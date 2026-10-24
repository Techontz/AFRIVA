import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/format.dart';
import '../../core/haptics.dart';
import '../../core/theme.dart';
import '../../models/commerce.dart';
import '../../services/commerce_service.dart';
import '../../state/auth_state.dart';
import '../../widgets/buttons.dart';
import '../../widgets/skeletons.dart';
import '../../widgets/states.dart';
import 'card_form.dart';
import 'method_tile.dart';

/// Payment-method picker + details form + pending/success states.
/// Pops with `true` once the payment succeeds.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key, required this.plan});
  final Plan plan;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

enum _Stage { form, processing, pending, success, failed }

class _CheckoutScreenState extends State<CheckoutScreen> {
  List<PaymentMethod>? _methods;
  Object? _loadError;
  PaymentMethod? _method;
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _card = CardFormController();
  _Stage _stage = _Stage.form;
  String? _submitError;
  CheckoutResult? _result;
  Payment? _payment;
  Timer? _poll;
  DateTime? _pollStarted;

  @override
  void initState() {
    super.initState();
    final phone = context.read<AuthState>().user?.phone;
    if (phone != null) _phone.text = phone;
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _phone.dispose();
    _card.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    try {
      final methods = await context.read<CommerceService>().paymentMethods();
      if (!mounted) return;
      setState(() {
        _methods = methods;
        _method ??= methods.firstOrNull;
      });
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  /// Normalises Tanzanian numbers to 255XXXXXXXXX.
  String _normalizePhone(String raw) {
    var d = raw.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('0')) d = '255${d.substring(1)}';
    if (d.length == 9) d = '255$d';
    return d;
  }

  Future<void> _pay() async {
    final m = _method;
    if (m == null) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? true)) return;
    setState(() {
      _stage = _Stage.processing;
      _submitError = null;
    });
    try {
      final res = await context.read<CommerceService>().checkout(
            planId: widget.plan.id,
            paymentMethod: m.code,
            phone: m.isMobileMoney ? _normalizePhone(_phone.text) : null,
            // Card data never leaves the device in full; the API ignores it for now.
            card: m.isCard ? _card.safeSummary(m.code) : null,
          );
      if (!mounted) return;
      _result = res;
      _payment = res.payment;
      if (res.payment.isSuccess) {
        _onSuccess();
      } else if (res.payment.isFailed) {
        setState(() => _stage = _Stage.failed);
      } else {
        Haptics.light();
        setState(() => _stage = _Stage.pending);
        _startPolling();
      }
    } catch (e) {
      if (!mounted) return;
      Haptics.medium();
      setState(() {
        _stage = _Stage.form;
        _submitError = errorMessage(e);
      });
    }
  }

  void _startPolling() {
    _poll?.cancel();
    _pollStarted = DateTime.now();
    _poll = Timer.periodic(AppConfig.paymentPollInterval, (_) => _check());
  }

  Future<void> _check({bool manual = false}) async {
    final ref = _payment?.reference;
    if (ref == null || ref.isEmpty) return;
    if (!manual &&
        _pollStarted != null &&
        DateTime.now().difference(_pollStarted!) > AppConfig.paymentPollTimeout) {
      _poll?.cancel();
      return;
    }
    try {
      final p = await context.read<CommerceService>().payment(ref);
      if (!mounted) return;
      setState(() => _payment = p);
      if (p.isSuccess) {
        _onSuccess();
      } else if (p.isFailed) {
        _poll?.cancel();
        Haptics.medium();
        setState(() => _stage = _Stage.failed);
      } else if (manual) {
        showSnack(context, 'Still waiting for confirmation from ${_method?.name ?? 'the provider'}.');
      }
    } on ApiException catch (e) {
      if (manual && mounted) showSnack(context, e.message, error: true);
    }
  }

  void _onSuccess() {
    _poll?.cancel();
    Haptics.success();
    context.read<AuthState>().refresh();
    setState(() => _stage = _Stage.success);
  }

  @override
  Widget build(BuildContext context) {
    final busy = _stage == _Stage.processing;
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(switch (_stage) {
            _Stage.success => 'Payment complete',
            _Stage.pending => 'Confirm payment',
            _Stage.failed => 'Payment failed',
            _ => 'Checkout',
          }),
          leading: IconButton(
            icon: Icon(_stage == _Stage.success ? Icons.close_rounded : Icons.arrow_back_rounded),
            onPressed: busy ? null : () => Navigator.of(context).pop(_stage == _Stage.success),
          ),
        ),
        body: AnimatedSwitcher(
          duration: AppMotion.slow,
          switchInCurve: AppMotion.curve,
          child: switch (_stage) {
            _Stage.form || _Stage.processing => _buildForm(),
            _Stage.pending => _buildPending(),
            _Stage.success => _buildSuccess(),
            _Stage.failed => _buildFailed(),
          },
        ),
      ),
    );
  }

  Widget _summary() {
    final text = Theme.of(context).textTheme;
    final p = widget.plan;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: p.isSubscription ? AppColors.brandGradient : AppColors.brandGradient,
            ),
            child: Icon(
              p.isCoins
                  ? Icons.toll_rounded
                  : p.isEpisodePack
                      ? Icons.confirmation_number_rounded
                      : Icons.workspace_premium_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, style: text.titleSmall),
                Text(
                  p.isCoins
                      ? '${p.coins ?? 0} coins${(p.bonusCoins ?? 0) > 0 ? ' + ${p.bonusCoins} bonus' : ''}'
                      : p.isEpisodePack
                          ? '${p.episodeQuota ?? 0} episode unlocks'
                          : '${p.durationDays ?? 0} days of VIP',
                  style: text.labelSmall,
                ),
              ],
            ),
          ),
          Text(Fmt.money(p.price, p.currency), style: text.titleMedium),
        ],
      ),
    );
  }

  Widget _buildForm() {
    final methods = _methods;
    final bottom = MediaQuery.paddingOf(context).bottom;
    if (methods == null) {
      return _loadError != null
          ? ErrorState(error: _loadError!, onRetry: _load)
          : const ListSkeleton(count: 4);
    }
    if (methods.isEmpty) {
      return const StateMessage(
        icon: Icons.credit_card_off_rounded,
        title: 'No payment methods available',
        message: 'Please try again later.',
      );
    }
    final groups = [
      ('Mobile Money', Icons.phone_android_rounded, methods.where((m) => m.isMobileMoney).toList()),
      ('Cards', Icons.credit_card_rounded, methods.where((m) => m.isCard).toList()),
      ('Bank', Icons.account_balance_rounded, methods.where((m) => m.isBank).toList()),
    ];
    final m = _method;
    final text = Theme.of(context).textTheme;
    return Form(
      key: _formKey,
      child: ListView(
        key: const ValueKey('form'),
        padding: EdgeInsets.fromLTRB(16, 8, 16, bottom + 24),
        children: [
          _summary(),
          for (final (label, icon, items) in groups)
            if (items.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(top: 22, bottom: 10),
                child: Row(
                  children: [
                    Icon(icon, size: 18, color: AppColors.textMuted),
                    const SizedBox(width: 8),
                    Text(label, style: text.titleSmall),
                  ],
                ),
              ),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.15,
                children: [
                  for (final x in items)
                    MethodTile(
                      method: x,
                      selected: m?.id == x.id,
                      onTap: () {
                        Haptics.tap();
                        setState(() {
                          _method = x;
                          _submitError = null;
                        });
                      },
                    ),
                ],
              ),
            ],
          const SizedBox(height: 22),
          if (m != null)
            AnimatedSize(
              duration: AppMotion.slow,
              curve: AppMotion.curve,
              alignment: Alignment.topCenter,
              child: _detailsFor(m),
            ),
          if (_submitError != null) ...[
            const SizedBox(height: 12),
            Text(_submitError!, style: text.bodySmall!.copyWith(color: AppColors.danger)),
          ],
          const SizedBox(height: 22),
          PillButton(
            label: 'Pay ${Fmt.money(widget.plan.price, widget.plan.currency)}',
            icon: Icons.lock_rounded,
            expand: true,
            loading: _stage == _Stage.processing,
            onPressed: m == null ? null : _pay,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.verified_user_outlined, size: 14, color: AppColors.textDim),
              const SizedBox(width: 6),
              Text('Secure checkout · Afriva never stores card details', style: text.labelSmall),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailsFor(PaymentMethod m) {
    final text = Theme.of(context).textTheme;
    if (m.isMobileMoney) {
      return Column(
        key: ValueKey('mm-${m.code}'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${m.name} number', style: text.titleSmall),
          const SizedBox(height: 10),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')), LengthLimitingTextInputFormatter(16)],
            decoration: InputDecoration(
              hintText: '0712 345 678',
              prefixIcon: const Icon(Icons.phone_iphone_rounded),
              prefixText: _phone.text.startsWith('0') || _phone.text.startsWith('+') ? null : '+255 ',
            ),
            onChanged: (_) => setState(() {}),
            validator: (v) {
              final d = _normalizePhone(v ?? '');
              if (d.length != 12 || !d.startsWith('255')) return 'Enter a valid mobile number';
              return null;
            },
          ),
          const SizedBox(height: 8),
          Text(
            "You'll receive a prompt on your phone from ${m.name}. Enter your PIN to approve.",
            style: text.labelSmall,
          ),
        ],
      );
    }
    if (m.isCard) {
      return CardForm(key: ValueKey('card-${m.code}'), controller: _card, brandCode: m.code);
    }
    return Container(
      key: ValueKey('bank-${m.code}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.textMuted, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "After you continue we'll show ${m.name} payment instructions and your reference number. "
              'Your plan activates as soon as the bank confirms.',
              style: text.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPending() {
    final text = Theme.of(context).textTheme;
    final p = _payment;
    final message = (_result?.message.isNotEmpty ?? false)
        ? _result!.message
        : 'Waiting for confirmation from ${_method?.name ?? 'your provider'}.';
    final timedOut = _poll == null || !_poll!.isActive;
    return ListView(
      key: const ValueKey('pending'),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      children: [
        const Center(child: _PulsingRing()),
        const SizedBox(height: 26),
        Text('Payment pending', style: text.headlineSmall, textAlign: TextAlign.center),
        const SizedBox(height: 10),
        Text(message, style: text.bodyMedium, textAlign: TextAlign.center),
        if (_result?.nextAction == 'await_ussd') ...[
          const SizedBox(height: 10),
          Text(
            'Check your phone for the ${_method?.name ?? ''} prompt and enter your PIN.',
            style: text.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
        if (_result?.nextAction == 'redirect' && _result?.redirectUrl != null) ...[
          const SizedBox(height: 10),
          SelectableText(
            'Complete payment at: ${_result!.redirectUrl}',
            style: text.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 24),
        _ReceiptRows(rows: [
          ('Plan', widget.plan.name),
          ('Amount', Fmt.money(p?.amount ?? widget.plan.price, p?.currency ?? widget.plan.currency)),
          ('Method', _method?.name ?? '—'),
          ('Reference', p?.reference ?? '—'),
          ('Status', (p?.status ?? 'pending').toUpperCase()),
        ]),
        const SizedBox(height: 24),
        PillButton(
          label: timedOut ? 'Check status' : 'I have paid — check now',
          icon: Icons.refresh_rounded,
          secondary: true,
          expand: true,
          onPressed: () => _check(manual: true),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Close — I’ll finish later'),
        ),
        const SizedBox(height: 6),
        Text(
          'You can track this payment anytime in Profile › Payment history.',
          style: text.labelSmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSuccess() {
    final text = Theme.of(context).textTheme;
    final p = widget.plan;
    final headline = p.isCoins
        ? 'Coins added!'
        : p.isEpisodePack
            ? 'Episode pack ready!'
            : 'Welcome to VIP!';
    final sub = p.isCoins
        ? '${(p.coins ?? 0) + (p.bonusCoins ?? 0)} coins are now in your wallet.'
        : p.isEpisodePack
            ? 'Use your ${p.episodeQuota ?? ''} unlocks on any locked episode.'
            : 'Every episode is unlocked. Enjoy the binge.';
    return Padding(
      key: const ValueKey('success'),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: p.isSubscription ? AppColors.brandGradient : AppColors.brandGradient,
                boxShadow: [
                  BoxShadow(
                    color: (p.isSubscription ? AppColors.primary : AppColors.primary).withValues(alpha: 0.45),
                    blurRadius: 30,
                  ),
                ],
              ),
              child: const Icon(Icons.check_rounded, size: 54, color: Colors.white),
            ),
          ),
          const SizedBox(height: 26),
          Text(headline, style: text.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(sub, style: text.bodyMedium, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('Ref ${_payment?.reference ?? ''}', style: text.labelSmall),
          const SizedBox(height: 30),
          PillButton(
            label: 'Start watching',
            icon: Icons.play_arrow_rounded,
            expand: true,
            light: p.isSubscription,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
  }

  Widget _buildFailed() {
    return Center(
      key: const ValueKey('failed'),
      child: StateMessage(
        icon: Icons.error_outline_rounded,
        title: 'Payment ${_payment?.status == 'cancelled' ? 'cancelled' : 'failed'}',
        message: 'No money was taken. You can try again or choose another method.',
        actionLabel: 'Try again',
        onAction: () => setState(() {
          _stage = _Stage.form;
          _payment = null;
          _result = null;
        }),
      ),
    );
  }
}

class _ReceiptRows extends StatelessWidget {
  const _ReceiptRows({required this.rows});
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Text(rows[i].$1, style: text.bodySmall),
                  const Spacer(),
                  Flexible(
                    child: SelectableText(
                      rows[i].$2,
                      textAlign: TextAlign.end,
                      style: text.labelLarge!.copyWith(color: AppColors.text),
                    ),
                  ),
                ],
              ),
            ),
            if (i < rows.length - 1) const Divider(),
          ],
        ],
      ),
    );
  }
}

class _PulsingRing extends StatefulWidget {
  const _PulsingRing();

  @override
  State<_PulsingRing> createState() => _PulsingRingState();
}

class _PulsingRingState extends State<_PulsingRing> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: 120,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) => Stack(
            alignment: Alignment.center,
            children: [
              for (final phase in const [0.0, 0.5])
                Opacity(
                  opacity: (1 - ((_c.value + phase) % 1)).clamp(0.0, 1.0),
                  child: Container(
                    width: 60 + 60 * ((_c.value + phase) % 1),
                    height: 60 + 60 * ((_c.value + phase) % 1),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.6), width: 2),
                    ),
                  ),
                ),
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.brandGradient),
                child: const Icon(Icons.hourglass_top_rounded, color: Colors.white, size: 30),
              ),
            ],
          ),
        ),
      );
}
