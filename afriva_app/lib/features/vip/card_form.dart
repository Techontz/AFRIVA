import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/payments.dart';
import '../../core/theme.dart';
import '../../l10n/l10n.dart';
import 'payment_widgets.dart';

/// Card fields held only in memory. The number and CVC are validated on the
/// device, reduced to a [CardPayload] (brand, last 4, expiry) and cleared;
/// they are never persisted, logged or sent to the Afriva API.
class CardFormController {
  final number = TextEditingController();
  final month = TextEditingController();
  final year = TextEditingController();
  final cvc = TextEditingController();

  /// Builds the safe payload, or null when the fields are not valid.
  CardPayload? payload({DateTime? now}) => CardPayload.fromInput(
        number: number.text,
        month: month.text,
        year: year.text,
        cvc: cvc.text,
        now: now,
      );

  /// Wipes the sensitive fields.
  void clearSensitive() {
    number.clear();
    cvc.clear();
  }

  void clear() {
    clearSensitive();
    month.clear();
    year.clear();
  }

  void dispose() {
    number.dispose();
    month.dispose();
    year.dispose();
    cvc.dispose();
  }
}

/// Card number, month, year and CVC with a live card preview.
class CardForm extends StatefulWidget {
  const CardForm({super.key, required this.controller, this.serverError, this.isBrandAvailable});
  final CardFormController controller;
  final String? serverError;

  /// Whether payments with a brand are open right now (from checkout options).
  final bool Function(CardBrand brand)? isBrandAvailable;

  @override
  State<CardForm> createState() => _CardFormState();
}

class _CardFormState extends State<CardForm> {
  CardFormController get c => widget.controller;
  final _monthFocus = FocusNode();
  final _yearFocus = FocusNode();
  final _cvcFocus = FocusNode();
  final _cvcFocusWatch = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _cvcFocus.addListener(() => _cvcFocusWatch.value = _cvcFocus.hasFocus);
  }

  @override
  void dispose() {
    _monthFocus.dispose();
    _yearFocus.dispose();
    _cvcFocus.dispose();
    _cvcFocusWatch.dispose();
    super.dispose();
  }

  String? _numberError(String? v) {
    final l = context.l10n;
    final e = CardValidator.number(v ?? '');
    if (e == CardError.brand) return l.payCardBrandUnsupported;
    if (e != null) return l.cardNumberInvalid;
    final brand = CardValidator.brandOf(v ?? '');
    if (brand != null && widget.isBrandAvailable != null && !widget.isBrandAvailable!(brand)) {
      return l.payNetworkUnavailable(brand.label);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final brand = CardValidator.brandOf(c.number.text);
    final unsupported = !CardValidator.couldBeSupported(c.number.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ValueListenableBuilder(
          valueListenable: _cvcFocusWatch,
          builder: (_, cvcFocused, _) => CardPreview(controller: c, brand: brand, cvcFocused: cvcFocused),
        ),
        const SizedBox(height: 18),
        TextFormField(
          key: const ValueKey('card-number'),
          controller: c.number,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.creditCardNumber],
          enableSuggestions: false,
          autocorrect: false,
          inputFormatters: [_CardNumberFormatter()],
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 1.2),
          decoration: InputDecoration(
            labelText: l.cardNumber,
            hintText: '0000 0000 0000 0000',
            helperText: unsupported ? null : l.payCardNumberHint,
            errorText: unsupported ? l.payCardBrandUnsupported : null,
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: AnimatedSwitcher(
                duration: AppMotion.normal,
                child: brand == null
                    ? Icon(Icons.credit_card_rounded, key: const ValueKey('none'), color: AppColors.textDim)
                    : BrandMark.card(brand, key: ValueKey(brand), size: 38),
              ),
            ),
            suffixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 26),
          ),
          onChanged: (v) {
            setState(() {});
            final d = CardValidator.digits(v);
            if (d.length == 16 && CardValidator.number(d) == null) _monthFocus.requestFocus();
          },
          validator: _numberError,
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                key: const ValueKey('card-month'),
                controller: c.month,
                focusNode: _monthFocus,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                textAlign: TextAlign.center,
                autofillHints: const [AutofillHints.creditCardExpirationMonth],
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
                decoration: InputDecoration(labelText: l.payCardMonth, hintText: 'MM'),
                onChanged: (v) {
                  setState(() {});
                  if (v.length == 2) _yearFocus.requestFocus();
                },
                validator: (v) {
                  final e = CardValidator.expiry(v ?? '', c.year.text);
                  return e == CardError.month ? l.cardInvalidMonth : null;
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                key: const ValueKey('card-year'),
                controller: c.year,
                focusNode: _yearFocus,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                textAlign: TextAlign.center,
                autofillHints: const [AutofillHints.creditCardExpirationYear],
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
                decoration: InputDecoration(labelText: l.payCardYear, hintText: 'YY'),
                onChanged: (v) {
                  setState(() {});
                  if (v.length == 2) _cvcFocus.requestFocus();
                },
                validator: (v) => switch (CardValidator.expiry(c.month.text, v ?? '')) {
                  CardError.year => l.payCardInvalidYear,
                  CardError.expired => l.cardExpired,
                  _ => null,
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                key: const ValueKey('card-cvc'),
                controller: c.cvc,
                focusNode: _cvcFocus,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                textAlign: TextAlign.center,
                obscureText: true,
                obscuringCharacter: '•',
                enableSuggestions: false,
                autocorrect: false,
                autofillHints: const [AutofillHints.creditCardSecurityCode],
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
                decoration: InputDecoration(labelText: l.payCardCvc, hintText: '123'),
                validator: (v) => CardValidator.cvc(v ?? '') != null ? l.payCardInvalidCvc : null,
              ),
            ),
          ],
        ),
        if (widget.serverError != null) ...[
          const SizedBox(height: 10),
          Text(widget.serverError!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5)),
        ],
      ],
    );
  }
}

/// A premium card face that fills in as the viewer types.
class CardPreview extends StatelessWidget {
  const CardPreview({super.key, required this.controller, required this.brand, this.cvcFocused = false});
  final CardFormController controller;
  final CardBrand? brand;
  final bool cvcFocused;

  @override
  Widget build(BuildContext context) {
    final d = CardValidator.digits(controller.number.text);
    final shown = d.padRight(16, '•');
    final groups = [for (var i = 0; i < 16; i += 4) shown.substring(i, i + 4)].join('  ');
    final mm = controller.month.text.isEmpty ? 'MM' : controller.month.text.padLeft(2, '0');
    final yy = controller.year.text.isEmpty ? 'YY' : controller.year.text;
    final glow = switch (brand) {
      CardBrand.visa => const Color(0xFF2B4BD8),
      CardBrand.mastercard => const Color(0xFFF79E1B),
      null => AppColors.primary,
    };
    return AspectRatio(
      aspectRatio: 1.586,
      child: AnimatedContainer(
        duration: AppMotion.slow,
        curve: AppMotion.curve,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF26262A), Color(0xFF0B0B0C)],
          ),
          boxShadow: [
            BoxShadow(color: glow.withValues(alpha: 0.28), blurRadius: 28, offset: const Offset(0, 12)),
          ],
        ),
        child: Stack(
          children: [
            // Soft brand-tinted light in the corner.
            Positioned(
              right: -60,
              top: -70,
              child: AnimatedContainer(
                duration: AppMotion.slow,
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [glow.withValues(alpha: 0.45), glow.withValues(alpha: 0)]),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
              child: DefaultTextStyle(
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 28,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            gradient: const LinearGradient(colors: [Color(0xFFE6C78A), Color(0xFFB8955A)]),
                          ),
                        ),
                        const Spacer(),
                        AnimatedSwitcher(
                          duration: AppMotion.slow,
                          child: switch (brand) {
                            CardBrand.visa => const Text(
                                'VISA',
                                key: ValueKey('v'),
                                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, letterSpacing: 1),
                              ),
                            CardBrand.mastercard => const MastercardCircles(key: ValueKey('m'), diameter: 28),
                            null => const SizedBox(key: ValueKey('n'), height: 28),
                          },
                        ),
                      ],
                    ),
                    const Spacer(),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        groups,
                        style: const TextStyle(fontSize: 21, letterSpacing: 1.6, fontFeatures: [FontFeature.tabularFigures()]),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _label(context.l10n.cardExpiry.toUpperCase(), '$mm/$yy'),
                        const Spacer(),
                        _label('CVC', cvcFocused ? '•••' : '   '),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String k, String v) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k, style: const TextStyle(fontSize: 9, color: Color(0x99FFFFFF), letterSpacing: 1.2)),
          const SizedBox(height: 2),
          Text(v, style: const TextStyle(fontSize: 14, letterSpacing: 1)),
        ],
      );
}

/// Groups digits in fours and caps the number at 19 digits.
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 19) digits = digits.substring(0, 19);
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      buf.write(digits[i]);
    }
    final s = buf.toString();
    return TextEditingValue(text: s, selection: TextSelection.collapsed(offset: s.length));
  }
}
