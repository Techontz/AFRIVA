import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/payments.dart';
import '../../core/theme.dart';
import '../../l10n/l10n.dart';
import 'payment_widgets.dart';

/// +255 phone input. Accepts "07..", "7.." or a pasted "+255 7.." and shows
/// the detected network live. The viewer never picks a network.
class MobileMoneyField extends StatefulWidget {
  const MobileMoneyField({
    super.key,
    required this.controller,
    this.serverError,
    this.isNetworkAvailable,
    this.onChanged,
    this.autofocus = false,
    this.showHelper = true,
    this.fieldKey = const ValueKey('mm-phone'),
    this.labelText,
    this.helperText,
    this.requireKnownNetwork = true,
  });

  final TextEditingController controller;
  final String? serverError;
  final bool Function(MobileNetwork network)? isNetworkAvailable;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final bool showHelper;
  final Key fieldKey;

  /// Overrides for uses other than mobile money (the hosted card receipt phone).
  final String? labelText;
  final String? helperText;

  /// Mobile money needs a known network; a receipt phone only needs to be valid.
  final bool requireKnownNetwork;

  /// Validation shared with the add-number sheet.
  static String? validate(
    BuildContext context,
    String raw, {
    bool Function(MobileNetwork)? isAvailable,
    bool requireKnownNetwork = true,
  }) {
    final l = context.l10n;
    final network = TzPhone.detect(raw);
    if (requireKnownNetwork && TzPhone.national(raw).length >= 2 && network == null) return l.payNetworkUnknown;
    if (TzPhone.normalize(raw) == null) return l.payPhoneInvalid;
    if (network != null && isAvailable != null && !isAvailable(network)) {
      return l.payNetworkUnavailable(network.name);
    }
    return null;
  }

  @override
  State<MobileMoneyField> createState() => _MobileMoneyFieldState();
}

class _MobileMoneyFieldState extends State<MobileMoneyField> {
  @override
  void initState() {
    super.initState();
    // Bring a prefilled value ("0754123456", "255754123456") into display form.
    final v = widget.controller.text;
    if (v.isNotEmpty) widget.controller.text = TzPhoneFormatter.format(v);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    final raw = widget.controller.text;
    final network = TzPhone.detect(raw);
    final unknown = widget.requireKnownNetwork && TzPhone.national(raw).length >= 2 && network == null;
    return TextFormField(
      key: widget.fieldKey,
      controller: widget.controller,
      autofocus: widget.autofocus,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.telephoneNumberNational],
      inputFormatters: [TzPhoneFormatter()],
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: 0.6),
      decoration: InputDecoration(
        labelText: widget.labelText ?? l.payPhoneLabel,
        hintText: '754 123 456',
        helperText: widget.showHelper && !unknown ? (widget.helperText ?? l.payPhoneHelper) : null,
        helperMaxLines: 2,
        errorText: widget.serverError ?? (unknown ? l.payNetworkUnknown : null),
        errorMaxLines: 2,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 16, right: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('+255', style: text.bodyLarge!.copyWith(fontWeight: FontWeight.w700, color: AppColors.text, fontSize: 17)),
              const SizedBox(width: 10),
              Container(width: 1, height: 22, color: AppColors.border),
            ],
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: Padding(
          padding: const EdgeInsets.only(right: 10),
          child: AnimatedSwitcher(
            duration: AppMotion.slow,
            transitionBuilder: (child, a) => FadeTransition(
              opacity: a,
              child: ScaleTransition(scale: Tween(begin: 0.85, end: 1.0).animate(a), child: child),
            ),
            child: network == null
                ? const SizedBox.shrink(key: ValueKey('none'))
                : NetworkPill(key: ValueKey(network.code), network: network),
          ),
        ),
        suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      ),
      onChanged: (v) {
        setState(() {});
        widget.onChanged?.call(v);
      },
      validator: (v) => MobileMoneyField.validate(
        context,
        v ?? '',
        isAvailable: widget.isNetworkAvailable,
        requireKnownNetwork: widget.requireKnownNetwork,
      ),
    );
  }
}

/// Keeps only the 9 national digits and groups them "754 123 456".
class TzPhoneFormatter extends TextInputFormatter {
  static String format(String raw) {
    final n = TzPhone.national(raw);
    final buf = StringBuffer();
    for (var i = 0; i < n.length; i++) {
      if (i == 3 || i == 6) buf.write(' ');
      buf.write(n[i]);
    }
    return buf.toString();
  }

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    // "0" or "+" alone: let the viewer keep typing 07.. / +255..
    final t = newValue.text.trim();
    if (t == '0' || t == '+' || t == '+2' || t == '+25' || t == '+255') {
      return newValue;
    }
    final s = format(newValue.text);
    return TextEditingValue(text: s, selection: TextSelection.collapsed(offset: s.length));
  }
}
