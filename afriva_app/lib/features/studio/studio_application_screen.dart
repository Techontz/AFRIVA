import 'package:flutter/gestures.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/payments.dart';
import '../../core/haptics.dart';
import '../../core/theme.dart';
import '../../l10n/l10n.dart';
import '../../models/studio_application.dart';
import '../../services/studio_service.dart';
import '../../state/auth_state.dart';
import '../../widgets/buttons.dart';
import '../auth/auth_scaffold.dart';
import 'creator_guidelines_sheet.dart';
import 'studio_widgets.dart';

/// Payout provider code the API expects for a network detected from the wallet number.
const _payoutProviderFor = <String, String>{
  'mpesa': 'mpesa',
  'tigopesa': 'mixx',
  'airtelmoney': 'airtel',
  'halopesa': 'halopesa',
  'tpesa': 'tpesa',
};

/// The API's payout provider for a wallet number, worked out from its prefix (null when unknown).
String? payoutProviderForNumber(String number) {
  final network = TzPhone.detect(number);
  return network == null ? null : _payoutProviderFor[network.code];
}

/// Client-side checks mirroring the API rules.
class StudioValidators {
  StudioValidators._();

  static final _idNumber = RegExp(r'^[A-Za-z0-9\- ]{4,40}$');
  static final _phone = RegExp(r'^[0-9+ ]{9,32}$');

  static bool idNumber(String v) => _idNumber.hasMatch(v.trim());
  static bool phone(String v) => _phone.hasMatch(v.trim());
}

/// "Request to post" form. Signed-out visitors also choose a login.
class StudioApplicationScreen extends StatefulWidget {
  const StudioApplicationScreen({super.key});

  @override
  State<StudioApplicationScreen> createState() => _StudioApplicationScreenState();
}

class _StudioApplicationScreenState extends State<StudioApplicationScreen> {
  final _form = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  final _idNumber = TextEditingController();
  final _bankName = TextEditingController();
  final _accountName = TextEditingController();
  final _accountNumber = TextEditingController();
  final _studioName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  late final TapGestureRecognizer _guidelinesTap = TapGestureRecognizer()
    ..onTap = () => showCreatorGuidelines(context);

  String _idType = 'nida';
  String _payoutMethod = 'mobile_money';
  bool _accepted = false;
  bool _obscure = true;
  bool _busy = false;
  String? _error;
  Map<String, String?> _fieldErrors = {};
  StudioApplyResult? _result;
  late final bool _wasLoggedIn;

  @override
  void initState() {
    super.initState();
    _wasLoggedIn = context.read<AuthState>().isLoggedIn;
  }

  @override
  void dispose() {
    for (final c in [
      _fullName,
      _phone,
      _idNumber,
      _bankName,
      _accountName,
      _accountNumber,
      _studioName,
      _email,
      _password,
    ]) {
      c.dispose();
    }
    _guidelinesTap.dispose();
    super.dispose();
  }

  bool get _mobile => _payoutMethod == 'mobile_money';

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_accepted || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _fieldErrors = {};
    });
    final auth = context.read<AuthState>();
    try {
      final res = await context.read<StudioService>().apply(
            fullName: _fullName.text,
            idType: _idType,
            idNumber: _idNumber.text,
            phone: _phone.text,
            payoutMethod: _payoutMethod,
            payoutProvider: _mobile ? payoutProviderForNumber(_accountNumber.text) : null,
            payoutBankName: _mobile ? null : _bankName.text,
            payoutAccountName: _accountName.text,
            payoutAccountNumber: _accountNumber.text,
            studioName: _studioName.text,
            email: _wasLoggedIn ? null : _email.text,
            password: _wasLoggedIn ? null : _password.text,
          );
      Haptics.success();
      if (_wasLoggedIn) auth.refresh();
      if (mounted) setState(() => _result = res);
    } on ApiException catch (e) {
      if (!mounted) return;
      Haptics.medium();
      setState(() {
        _error = e.message;
        _fieldErrors = {
          for (final f in const [
            'full_name',
            'id_type',
            'id_number',
            'phone',
            'payout_method',
            'payout_provider',
            'payout_bank_name',
            'payout_account_name',
            'payout_account_number',
            'studio_name',
            'guidelines_accepted',
            'email',
            'password',
          ])
            f: e.fieldError(f),
        };
      });
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.requestToPost)),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: _result == null ? _buildForm(context) : _buildSuccess(context, _result!),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    String? required(String? v) => (v == null || v.trim().isEmpty) ? l.studioValidateRequired : null;

    return Form(
      key: _form,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.paddingOf(context).bottom + 24),
        children: [
          Text(l.studioApplyIntro, style: text.bodyMedium),
          const SizedBox(height: 16),
          FormErrorBanner(_error),

          StudioSectionLabel(l.studioSectionDetails),
          TextFormField(
            controller: _fullName,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            decoration: InputDecoration(
              labelText: l.studioFullName,
              prefixIcon: const Icon(Icons.person_outline_rounded),
              errorText: _fieldErrors['full_name'],
            ),
            validator: required,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.telephoneNumber],
            decoration: InputDecoration(
              labelText: l.fieldPhoneNumber,
              hintText: '0712 345 678',
              prefixIcon: const Icon(Icons.phone_iphone_rounded),
              errorText: _fieldErrors['phone'],
            ),
            validator: (v) => required(v) ?? (StudioValidators.phone(v!) ? null : l.studioValidatePhone),
          ),

          StudioSectionLabel(l.studioSectionIdentity),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'nida', label: Text(l.studioIdNida), icon: const Icon(Icons.badge_outlined)),
              ButtonSegment(
                  value: 'passport', label: Text(l.studioIdPassport), icon: const Icon(Icons.public_rounded)),
            ],
            selected: {_idType},
            showSelectedIcon: false,
            onSelectionChanged: (s) {
              Haptics.tap();
              setState(() => _idType = s.first);
            },
            style: studioSegmentStyle(),
          ),
          if (_fieldErrors['id_type'] != null) _InlineError(_fieldErrors['id_type']!),
          const SizedBox(height: 14),
          TextFormField(
            controller: _idNumber,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: _idType == 'nida' ? l.studioIdNumberNida : l.studioIdNumberPassport,
              prefixIcon: const Icon(Icons.credit_card_rounded),
              errorText: _fieldErrors['id_number'],
            ),
            validator: (v) => required(v) ?? (StudioValidators.idNumber(v!) ? null : l.studioValidateIdNumber),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: AppColors.textDim),
              const SizedBox(width: 8),
              Expanded(child: Text(l.studioIdPhotoNote, style: text.labelSmall)),
            ],
          ),

          StudioSectionLabel(l.studioSectionPayout),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(
                  value: 'mobile_money',
                  label: Text(l.studioPayoutMobile),
                  icon: const Icon(Icons.phone_android_rounded)),
              ButtonSegment(
                  value: 'bank', label: Text(l.studioPayoutBank), icon: const Icon(Icons.account_balance_outlined)),
            ],
            selected: {_payoutMethod},
            showSelectedIcon: false,
            onSelectionChanged: (s) {
              Haptics.tap();
              setState(() => _payoutMethod = s.first);
            },
            style: studioSegmentStyle(),
          ),
          if (_fieldErrors['payout_method'] != null) _InlineError(_fieldErrors['payout_method']!),
          const SizedBox(height: 14),
          if (!_mobile)
            TextFormField(
              controller: _bankName,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l.studioBankName,
                prefixIcon: const Icon(Icons.account_balance_outlined),
                errorText: _fieldErrors['payout_bank_name'],
              ),
              validator: required,
            ),
          if (!_mobile) const SizedBox(height: 14),
          TextFormField(
            controller: _accountName,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: l.studioAccountName,
              prefixIcon: const Icon(Icons.person_outline_rounded),
              errorText: _fieldErrors['payout_account_name'],
            ),
            validator: required,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _accountNumber,
            keyboardType: _mobile ? TextInputType.phone : TextInputType.text,
            textInputAction: TextInputAction.next,
            // Rebuild so the detected network shows as soon as the prefix is typed.
            onChanged: _mobile ? (_) => setState(() {}) : null,
            decoration: InputDecoration(
              labelText: _mobile ? l.studioWalletNumber : l.studioAccountNumber,
              hintText: _mobile ? '0712 345 678' : null,
              prefixIcon: const Icon(Icons.numbers_rounded),
              helperText: _mobile ? (TzPhone.detect(_accountNumber.text)?.name ?? l.payPhoneHelper) : null,
              errorText: _fieldErrors['payout_account_number'] ?? (_mobile ? _fieldErrors['payout_provider'] : null),
            ),
            validator: (v) {
              final base = required(v);
              if (base != null || !_mobile) return base;
              if (TzPhone.normalize(v!) == null) return l.payPhoneInvalid;
              if (payoutProviderForNumber(v) == null) return l.payNetworkUnknown;
              return null;
            },
          ),

          StudioSectionLabel(l.studioSectionStudio),
          TextFormField(
            controller: _studioName,
            textCapitalization: TextCapitalization.words,
            textInputAction: _wasLoggedIn ? TextInputAction.done : TextInputAction.next,
            decoration: InputDecoration(
              labelText: l.studioSectionStudio,
              hintText: l.studioNameHint,
              helperText: l.studioOptional,
              helperStyle: text.labelSmall,
              prefixIcon: const Icon(Icons.movie_filter_outlined),
              errorText: _fieldErrors['studio_name'],
            ),
          ),

          if (!_wasLoggedIn) ...[
            StudioSectionLabel(l.studioSectionLogin),
            Text(l.studioLoginHelp, style: text.labelSmall),
            const SizedBox(height: 12),
            AutofillGroup(
              child: Column(
                children: [
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    decoration: InputDecoration(
                      labelText: l.fieldEmail,
                      hintText: 'you@example.com',
                      prefixIcon: const Icon(Icons.mail_outline_rounded),
                      errorText: _fieldErrors['email'],
                    ),
                    validator: (v) {
                      final t = v?.trim() ?? '';
                      if (t.isEmpty) return l.validateEmailRequired;
                      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) return l.validateEmailInvalid;
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _password,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: InputDecoration(
                      labelText: l.fieldPassword,
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      errorText: _fieldErrors['password'],
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? l.validatePassword : null,
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Checkbox(
                value: _accepted,
                activeColor: AppColors.primary,
                onChanged: (v) {
                  Haptics.tap();
                  setState(() => _accepted = v ?? false);
                },
              ),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: l.studioAcceptPrefix,
                    children: [
                      TextSpan(
                        text: l.studioAcceptLink,
                        recognizer: _guidelinesTap,
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  style: text.bodyMedium,
                ),
              ),
            ],
          ),
          if (_fieldErrors['guidelines_accepted'] != null) _InlineError(_fieldErrors['guidelines_accepted']!),
          const SizedBox(height: 18),
          PillButton(
            label: l.studioSubmit,
            expand: true,
            loading: _busy,
            onPressed: _accepted ? _submit : null,
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess(BuildContext context, StudioApplyResult res) {
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 24, 16, MediaQuery.paddingOf(context).bottom + 24),
      children: [
        Center(
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.surface),
            child: Icon(Icons.check_circle_rounded, size: 40, color: AppColors.success),
          ),
        ),
        const SizedBox(height: 18),
        Text(l.studioSuccessTitle, style: text.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(l.studioSuccessBody, style: text.bodyMedium, textAlign: TextAlign.center),
        if (!_wasLoggedIn) ...[
          const SizedBox(height: 8),
          Text(
            res.existingUser ? l.studioSuccessExisting : l.studioSuccessGuest,
            style: text.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 22),
        const StudioWebsiteCard(),
        const SizedBox(height: 22),
        if (_wasLoggedIn)
          PillButton(
            label: l.studioViewStatus,
            expand: true,
            onPressed: () => context.pushReplacement('/studio/status'),
          )
        else
          PillButton(
            label: l.actionLogIn,
            expand: true,
            onPressed: () => context.pushReplacement('/login'),
          ),
      ],
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 12, top: 6),
        child: Text(
          message,
          style: Theme.of(context).textTheme.labelSmall!.copyWith(color: AppColors.danger),
        ),
      );
}
