import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme.dart';

/// Holds card form fields. Only a non-sensitive summary is ever sent.
class CardFormController {
  final number = TextEditingController();
  final expiry = TextEditingController();
  final cvc = TextEditingController();
  final name = TextEditingController();

  String get digits => number.text.replaceAll(RegExp(r'\D'), '');

  Map<String, dynamic> safeSummary(String brand) => {
        'brand': brand,
        'last4': digits.length >= 4 ? digits.substring(digits.length - 4) : '',
        'holder': name.text.trim(),
      };

  void dispose() {
    number.dispose();
    expiry.dispose();
    cvc.dispose();
    name.dispose();
  }
}

/// Card details UI (Visa / Mastercard) with a live card preview.
class CardForm extends StatefulWidget {
  const CardForm({super.key, required this.controller, required this.brandCode});
  final CardFormController controller;
  final String brandCode;

  @override
  State<CardForm> createState() => _CardFormState();
}

class _CardFormState extends State<CardForm> {
  CardFormController get c => widget.controller;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CardPreview(controller: c, brandCode: widget.brandCode),
        const SizedBox(height: 16),
        Text('Card details', style: text.titleSmall),
        const SizedBox(height: 10),
        TextFormField(
          controller: c.number,
          keyboardType: TextInputType.number,
          autofillHints: const [AutofillHints.creditCardNumber],
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(19), _CardNumberFormatter()],
          decoration: const InputDecoration(
            labelText: 'Card number',
            hintText: '1234 5678 9012 3456',
            prefixIcon: Icon(Icons.credit_card_rounded),
          ),
          onChanged: (_) => setState(() {}),
          validator: (v) {
            final d = (v ?? '').replaceAll(RegExp(r'\D'), '');
            if (d.length < 13 || !_luhn(d)) return 'Enter a valid card number';
            return null;
          },
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: c.expiry,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.creditCardExpirationDate],
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4), _ExpiryFormatter()],
                decoration: const InputDecoration(labelText: 'Expiry', hintText: 'MM/YY'),
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  final parts = (v ?? '').split('/');
                  if (parts.length != 2) return 'MM/YY';
                  final mm = int.tryParse(parts[0]) ?? 0;
                  final yy = int.tryParse(parts[1]) ?? 0;
                  if (mm < 1 || mm > 12) return 'Invalid month';
                  final now = DateTime.now();
                  final exp = DateTime(2000 + yy, mm + 1);
                  if (exp.isBefore(now)) return 'Card expired';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: c.cvc,
                keyboardType: TextInputType.number,
                obscureText: true,
                autofillHints: const [AutofillHints.creditCardSecurityCode],
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                decoration: const InputDecoration(labelText: 'CVC', hintText: '123'),
                validator: (v) => (v ?? '').length < 3 ? 'Invalid CVC' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: c.name,
          textCapitalization: TextCapitalization.characters,
          autofillHints: const [AutofillHints.creditCardName],
          decoration: const InputDecoration(labelText: 'Name on card', prefixIcon: Icon(Icons.person_outline_rounded)),
          onChanged: (_) => setState(() {}),
          validator: (v) => (v ?? '').trim().isEmpty ? 'Enter the name on the card' : null,
        ),
      ],
    );
  }

  static bool _luhn(String digits) {
    var sum = 0;
    var alt = false;
    for (var i = digits.length - 1; i >= 0; i--) {
      var n = digits.codeUnitAt(i) - 48;
      if (alt) {
        n *= 2;
        if (n > 9) n -= 9;
      }
      sum += n;
      alt = !alt;
    }
    return sum % 10 == 0;
  }
}

class _CardPreview extends StatelessWidget {
  const _CardPreview({required this.controller, required this.brandCode});
  final CardFormController controller;
  final String brandCode;

  @override
  Widget build(BuildContext context) {
    final isVisa = brandCode == 'visa';
    final d = controller.digits.padRight(16, '•');
    final groups = [for (var i = 0; i < 16; i += 4) d.substring(i, i + 4)].join('  ');
    final name = controller.name.text.trim().isEmpty ? 'CARDHOLDER NAME' : controller.name.text.toUpperCase();
    final exp = controller.expiry.text.isEmpty ? 'MM/YY' : controller.expiry.text;
    return AspectRatio(
      aspectRatio: 1.7,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isVisa
                ? const [Color(0xFF1A1F71), Color(0xFF2B3A9E), Color(0xFF000000)]
                : const [Color(0xFF262626), Color(0xFF3A0A12), Color(0xFF000000)],
          ),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 8))],
        ),
        child: DefaultTextStyle(
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
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
                      gradient: AppColors.brandGradient,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    isVisa ? 'VISA' : 'Mastercard',
                    style: TextStyle(
                      fontSize: isVisa ? 22 : 15,
                      fontStyle: isVisa ? FontStyle.italic : FontStyle.normal,
                      fontWeight: FontWeight.w900,
                      letterSpacing: isVisa ? 2 : 0,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(groups, style: const TextStyle(fontSize: 20, letterSpacing: 1.5)),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                  ),
                  Text(exp, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      buf.write(digits[i]);
    }
    final s = buf.toString();
    return TextEditingValue(text: s, selection: TextSelection.collapsed(offset: s.length));
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final s = digits.length > 2 ? '${digits.substring(0, 2)}/${digits.substring(2)}' : digits;
    return TextEditingValue(text: s, selection: TextSelection.collapsed(offset: s.length));
  }
}
