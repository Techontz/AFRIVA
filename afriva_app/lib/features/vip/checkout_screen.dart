import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/haptics.dart';
import '../../core/payments.dart';
import '../../core/theme.dart';
import '../../core/url_opener.dart';
import '../../l10n/l10n.dart';
import '../../models/commerce.dart';
import '../../services/commerce_service.dart';
import '../../state/auth_state.dart';
import '../../widgets/buttons.dart';
import '../../widgets/skeletons.dart';
import '../../widgets/states.dart';
import 'card_form.dart';
import 'payment_prompt_sheet.dart';
import 'payment_widgets.dart';
import 'phone_field.dart';

/// Checkout: saved methods first (default preselected, one tap), then a new
/// mobile money number or card. Pops with `true` once the payment succeeds.
///
/// When cards are hosted (`card.hosted` from `/checkout/options`) the card is
/// typed on the payment partner's secure page: the app only asks for a phone,
/// opens `redirect_url` with [openUrl] and polls the payment.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key, required this.plan, this.openUrl = openSecureWebPage});
  final Plan plan;

  /// Opens the hosted card page. Injectable for tests.
  final UrlOpener openUrl;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  CheckoutOptions? _options;
  List<SavedMethod> _saved = const [];
  Object? _loadError;

  /// Selected saved method, or null for "add new".
  int? _savedId;
  bool _card = false;
  bool _save = true;

  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();

  /// Receipt phone for a hosted card payment.
  final _cardPhone = TextEditingController();
  final _cardForm = CardFormController();

  bool _busy = false;
  String? _error;
  String? _phoneError;
  String? _cardError;

  // Success
  Payment? _paid;
  String? _paidWith;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _phone.dispose();
    _cardPhone.dispose();
    _cardForm.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    final commerce = context.read<CommerceService>();
    try {
      final results = await Future.wait<Object>([
        commerce.checkoutOptions(),
        // Saved methods are a convenience: checkout still works without them.
        commerce.savedMethods().catchError((_) => <SavedMethod>[]),
      ]);
      if (!mounted) return;
      final options = results[0] as CheckoutOptions;
      final saved = (results[1] as List<SavedMethod>).where((m) => _channelOpen(options, m)).toList();
      final pick = saved.where((m) => m.isDefault && m.canPay).firstOrNull ?? saved.where((m) => m.canPay).firstOrNull;
      setState(() {
        _options = options;
        _saved = saved;
        _savedId = pick?.id;
        _card = !options.mobileMoney.available && options.card.available;
      });
      final phone = context.read<AuthState>().user?.phone;
      final validPhone = phone != null && TzPhone.normalize(phone) != null;
      if (pick == null && _phone.text.isEmpty && validPhone) _phone.text = TzPhoneFormatter.format(phone);
      if (_cardPhone.text.isEmpty && validPhone) _cardPhone.text = TzPhoneFormatter.format(phone);
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  /// Saved cards cannot be charged with one tap when cards are hosted, so
  /// they are left out of checkout then.
  bool _channelOpen(CheckoutOptions o, SavedMethod m) =>
      m.isCard ? o.card.available && !o.card.hosted : o.mobileMoney.available;

  bool get _hosted => _options?.hostedCards ?? false;

  SavedMethod? get _selectedSaved => _saved.where((m) => m.id == _savedId).firstOrNull;

  void _clearErrors() {
    _error = null;
    _phoneError = null;
    _cardError = null;
  }

  Future<void> _pay() async {
    FocusScope.of(context).unfocus();
    final saved = _selectedSaved;
    if (saved == null && !(_formKey.currentState?.validate() ?? false)) {
      Haptics.medium();
      return;
    }
    setState(() {
      _busy = true;
      _clearErrors();
    });
    final commerce = context.read<CommerceService>();
    final plan = widget.plan;
    String? phone;
    MobileNetwork? network;
    String? networkName;
    var mobile = true;
    var hosted = false;
    String paidWith;
    try {
      final CheckoutResult res;
      if (saved != null) {
        mobile = saved.isMobileMoney;
        phone = saved.phone;
        network = MobileNetwork.byCode(saved.methodCode);
        networkName = saved.network;
        paidWith = describeSaved(context, saved).title;
        res = await commerce.payWithSaved(planId: plan.id, savedMethodId: saved.id);
      } else if (!_card) {
        phone = TzPhone.normalize(_phone.text)!;
        network = TzPhone.detect(phone);
        paidWith = '${network?.name ?? ''} ${TzPhone.pretty(phone)}'.trim();
        res = await commerce.payWithMobileMoney(planId: plan.id, phone: phone, save: _save);
      } else if (_hosted) {
        // No card details in the app at all: they go on the partner's page.
        mobile = false;
        hosted = true;
        phone = TzPhone.normalize(_cardPhone.text)!;
        paidWith = context.l10n.payCard;
        res = await commerce.payWithHostedCard(planId: plan.id, phone: phone);
      } else {
        mobile = false;
        final card = _cardForm.payload();
        // The full number and CVC stop here; only the safe payload goes on.
        _cardForm.cvc.clear();
        if (card == null) {
          setState(() => _busy = false);
          return;
        }
        paidWith = context.l10n.payCardEnding(card.brand.label, card.last4);
        res = await commerce.payWithCard(planId: plan.id, card: card, save: _save);
      }
      if (!mounted) return;
      setState(() => _busy = false);

      if (res.payment.isSuccess) {
        _succeed(res.payment, paidWith, res.userCoins);
        return;
      }
      if (res.payment.isFailed) {
        Haptics.medium();
        setState(() => _error = res.message.isNotEmpty ? res.message : context.l10n.promptFailedBody);
        return;
      }
      Haptics.light();
      final redirect = res.nextAction == 'redirect' ? res.redirectUrl : null;
      final hostedPage = hosted && redirect != null;
      var opened = true;
      if (hostedPage) opened = await widget.openUrl(Uri.parse(redirect));
      if (!mounted) return;
      final (outcome, payment) = await showPaymentPrompt(
        context,
        payment: res.payment,
        phone: phone,
        network: network,
        networkName: networkName,
        mobileMoney: mobile,
        redirectUrl: redirect,
        hostedCard: hostedPage,
        openFailed: !opened,
        openUrl: widget.openUrl,
      );
      if (!mounted) return;
      switch (outcome) {
        case PromptOutcome.success:
          _succeed(payment ?? res.payment, paidWith, null);
        case PromptOutcome.closed:
          showSnack(context, context.l10n.checkoutTrackHint);
        case PromptOutcome.failed || PromptOutcome.retry:
          break;
      }
    } catch (e) {
      if (!mounted) return;
      Haptics.medium();
      setState(() {
        _busy = false;
        if (e is ApiException && e.isValidation) {
          _phoneError = e.fieldError('phone');
          _cardError = e.fieldError('card') ??
              e.fieldError('card.exp_month') ??
              e.fieldError('card.exp_year') ??
              e.fieldError('card.brand') ??
              e.fieldError('card.last4');
          final savedErr = e.fieldError('saved_method_id');
          if (_phoneError == null && _cardError == null) _error = savedErr ?? e.message;
          if (_selectedSaved != null && (_phoneError != null || _cardError != null)) {
            _error = _phoneError ?? _cardError;
          }
        } else {
          _error = errorMessage(e);
        }
      });
    }
  }

  void _succeed(Payment payment, String paidWith, int? coins) {
    Haptics.success();
    final auth = context.read<AuthState>();
    if (coins != null) auth.setCoins(coins);
    auth.refresh();
    _cardForm.clear();
    setState(() {
      _paid = payment;
      _paidWith = paidWith;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final done = _paid != null;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(done ? l.checkoutTitleSuccess : l.checkoutTitle),
          leading: IconButton(
            icon: Icon(done ? Icons.close_rounded : Icons.arrow_back_rounded),
            onPressed: _busy ? null : () => Navigator.of(context).pop(done),
          ),
        ),
        body: AnimatedSwitcher(
          duration: AppMotion.slow,
          switchInCurve: AppMotion.curve,
          child: done ? _buildSuccess() : _buildBody(),
        ),
        bottomNavigationBar: done || _options == null ? null : _payBar(),
      ),
    );
  }

  Widget _buildBody() {
    final options = _options;
    if (options == null) {
      return _loadError != null
          ? ErrorState(key: const ValueKey('err'), error: _loadError!, onRetry: _load)
          : const ListSkeleton(key: ValueKey('skel'), count: 4);
    }
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    final nothing = !options.mobileMoney.available && !options.card.available;
    final addingNew = _savedId == null;
    return Form(
      key: _formKey,
      child: ListView(
        key: const ValueKey('form'),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _OrderSummary(plan: widget.plan),
          if (options.demo) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.science_outlined, size: 15, color: AppColors.textDim),
                const SizedBox(width: 6),
                Expanded(child: Text(l.payDemoNote, style: text.labelSmall)),
              ],
            ),
          ],
          const SizedBox(height: 26),
          Text(l.payPayWith, style: text.titleMedium!.copyWith(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (nothing)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(l.payNothingAvailable, style: text.bodySmall),
            ),
          for (final m in _saved) ...[
            _savedTile(m),
            const SizedBox(height: 10),
          ],
          if (_saved.isNotEmpty)
            PayOptionTile(
              key: const ValueKey('add-new'),
              leading: Container(
                width: 40,
                height: 27,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.textDim, width: 1.2),
                ),
                child: Icon(Icons.add_rounded, size: 18, color: AppColors.text),
              ),
              title: l.payAddNew,
              subtitle: l.payAddNewSub,
              selected: addingNew,
              enabled: !nothing,
              onTap: () => setState(() {
                _savedId = null;
                _clearErrors();
              }),
            ),
          AnimatedSize(
            duration: AppMotion.slow,
            curve: AppMotion.curve,
            alignment: Alignment.topCenter,
            child: addingNew && !nothing ? _newMethod(options) : const SizedBox(width: double.infinity),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            _ErrorBanner(message: _error!),
          ],
        ],
      ),
    );
  }

  Widget _savedTile(SavedMethod m) {
    final l = context.l10n;
    final d = describeSaved(context, m);
    final needsDetails = !m.oneTap && !m.isExpired;
    return PayOptionTile(
      key: ValueKey('saved-${m.id}'),
      leading: brandMarkFor(m),
      title: d.title,
      subtitle: needsDetails ? l.payNeedsDetails : d.subtitle,
      subtitleColor: m.isExpired ? AppColors.danger : null,
      badge: m.isDefault ? l.payDefault : null,
      selected: _savedId == m.id,
      enabled: m.canPay || needsDetails,
      onTap: () => setState(() {
        _clearErrors();
        if (needsDetails) {
          // No provider token yet: collect the card again.
          _savedId = null;
          _card = true;
        } else {
          _savedId = m.id;
        }
      }),
    );
  }

  Widget _newMethod(CheckoutOptions o) {
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(top: _saved.isEmpty ? 0 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PaySegmented(
            cardSelected: _card,
            mobileEnabled: o.mobileMoney.available,
            cardEnabled: o.card.available,
            onChanged: (card) => setState(() {
              _card = card;
              _clearErrors();
            }),
          ),
          const SizedBox(height: 18),
          AnimatedSwitcher(
            duration: AppMotion.slow,
            switchInCurve: AppMotion.curve,
            transitionBuilder: (child, a) => FadeTransition(
              opacity: a,
              child: SlideTransition(position: Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(a), child: child),
            ),
            child: _card && o.hostedCards
                ? HostedCardPanel(
                    key: const ValueKey('hosted-card'),
                    brands: [
                      for (final b in CardBrand.values)
                        if (o.card.isAvailable(b.code)) b,
                    ],
                    phone: MobileMoneyField(
                      controller: _cardPhone,
                      fieldKey: const ValueKey('card-phone'),
                      labelText: l.payHostedPhoneLabel,
                      helperText: l.payHostedPhoneHelper,
                      requireKnownNetwork: false,
                      serverError: _phoneError,
                      onChanged: (_) {
                        if (_phoneError != null) setState(() => _phoneError = null);
                      },
                    ),
                  )
                : _card
                ? CardForm(
                    key: const ValueKey('card'),
                    controller: _cardForm,
                    serverError: _cardError,
                    isBrandAvailable: (b) => o.card.isAvailable(b.code),
                  )
                : MobileMoneyField(
                    key: const ValueKey('mm'),
                    controller: _phone,
                    serverError: _phoneError,
                    isNetworkAvailable: (n) => o.mobileMoney.isAvailable(n.code),
                    onChanged: (_) {
                      if (_phoneError != null) setState(() => _phoneError = null);
                    },
                  ),
          ),
          // Hosted cards cannot be saved for one tap.
          if (!(_card && o.hostedCards)) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.bolt_rounded, size: 20, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.paySave, style: text.titleSmall!.copyWith(fontSize: 14)),
                        Text(l.paySaveSub, style: text.labelSmall),
                      ],
                    ),
                  ),
                  Switch(
                    key: const ValueKey('save-switch'),
                    value: _save,
                    onChanged: (v) {
                      Haptics.tap();
                      setState(() => _save = v);
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _payBar() {
    final l = context.l10n;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final o = _options!;
    final canPay = _selectedSaved != null || (o.card.available && _card) || (o.mobileMoney.available && !_card);
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottom + 12),
      decoration: BoxDecoration(
        color: AppColors.bg,
        border: Border(top: BorderSide(color: AppColors.border.withValues(alpha: 0.6))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PillButton(
            key: const ValueKey('pay'),
            label: _selectedSaved == null && _card && o.hostedCards
                ? l.payHostedContinue(Fmt.money(widget.plan.price, widget.plan.currency))
                : l.checkoutPay(Fmt.money(widget.plan.price, widget.plan.currency)),
            icon: Icons.lock_rounded,
            expand: true,
            height: 54,
            loading: _busy,
            onPressed: canPay ? _pay : null,
          ),
          const SizedBox(height: 10),
          Text(
            l.paySecureNote,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall!.copyWith(fontSize: 11.5),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    final p = widget.plan;
    final paid = _paid!;
    final headline = p.isCoins
        ? l.successCoinsTitle
        : p.isEpisodePack
            ? l.successPackTitle
            : l.successVipTitle;
    final sub = p.isCoins
        ? l.successCoinsMessage((p.coins ?? 0) + (p.bonusCoins ?? 0))
        : p.isEpisodePack
            ? l.successPackMessage(p.episodeQuota ?? 0)
            : l.successVipMessage;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return ListView(
      key: const ValueKey('success'),
      padding: EdgeInsets.fromLTRB(24, 36, 24, bottom + 24),
      children: [
        Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 650),
            curve: Curves.elasticOut,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.brandGradient,
                boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.45), blurRadius: 34)],
              ),
              child: const Icon(Icons.check_rounded, size: 48, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text(headline, style: text.headlineSmall!.copyWith(fontSize: 26), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(sub, style: text.bodyMedium, textAlign: TextAlign.center),
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.card),
          ),
          child: Column(
            children: [
              _row(l.receiptPlan, p.name),
              _row(l.receiptAmount, Fmt.money(paid.amount > 0 ? paid.amount : p.price, paid.currency)),
              if (_paidWith != null && _paidWith!.isNotEmpty) _row(l.receiptMethod, _paidWith!),
              _row(l.receiptReference, paid.reference, last: true),
            ],
          ),
        ),
        const SizedBox(height: 30),
        PillButton(
          label: l.successStartWatching,
          icon: Icons.play_arrow_rounded,
          expand: true,
          height: 54,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }

  Widget _row(String k, String v, {bool last = false}) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.6))),
      ),
      child: Row(
        children: [
          Text(k, style: text.bodySmall),
          const SizedBox(width: 16),
          Expanded(
            child: SelectableText(
              v,
              textAlign: TextAlign.end,
              maxLines: 1,
              style: text.labelLarge!.copyWith(color: AppColors.text),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderSummary extends StatelessWidget {
  const _OrderSummary({required this.plan});
  final Plan plan;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    final p = plan;
    final detail = p.isCoins
        ? ((p.bonusCoins ?? 0) > 0 ? l.checkoutCoinsWithBonus(p.coins ?? 0, p.bonusCoins!) : l.checkoutCoins(p.coins ?? 0))
        : p.isEpisodePack
            ? l.checkoutEpisodeUnlocks(p.episodeQuota ?? 0)
            : l.checkoutVipDays(p.durationDays ?? 0);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.vipCardGradient,
        borderRadius: BorderRadius.circular(AppRadii.card + 2),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: AppColors.brandGradient),
            child: Icon(
              p.isCoins ? Icons.toll_rounded : (p.isEpisodePack ? Icons.video_library_rounded : Icons.workspace_premium_rounded),
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, style: text.titleSmall!.copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(detail, style: text.labelSmall),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(l.payTotal, style: text.labelSmall),
              Text(Fmt.money(p.price, p.currency), style: text.titleMedium!.copyWith(fontSize: 18, fontWeight: FontWeight.w800)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        key: const ValueKey('pay-error'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline_rounded, size: 18, color: AppColors.danger),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: TextStyle(fontSize: 13, color: AppColors.text))),
          ],
        ),
      );
}
