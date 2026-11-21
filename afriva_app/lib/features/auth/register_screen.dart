import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/haptics.dart';
import '../../core/theme.dart';
import '../../l10n/l10n.dart';
import '../../state/auth_state.dart';
import '../../state/favorites_state.dart';
import '../../widgets/buttons.dart';
import 'auth_scaffold.dart';
import 'google_sign_in.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _contact = TextEditingController();
  final _password = TextEditingController();
  bool _usePhone = true;
  /// The phone (or email) form opens after "Continue with phone number".
  bool _formOpen = false;
  bool _obscure = true;
  bool _busy = false;
  String? _error;
  Map<String, String?> _fieldErrors = {};

  @override
  void dispose() {
    _name.dispose();
    _contact.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _fieldErrors = {};
    });
    try {
      await context.read<AuthState>().register(
            name: _name.text,
            email: _usePhone ? null : _contact.text,
            phone: _usePhone ? _contact.text : null,
            password: _password.text,
          );
      Haptics.success();
      _onSignedIn();
    } on ApiException catch (e) {
      if (!mounted) return;
      Haptics.medium();
      setState(() {
        _error = e.message;
        _fieldErrors = {
          'name': e.fieldError('name'),
          'contact': e.fieldError(_usePhone ? 'phone' : 'email'),
          'password': e.fieldError('password'),
        };
      });
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Shared by the form and Google sign-in.
  void _onSignedIn() {
    if (!mounted) return;
    context.read<FavoritesState>().load().catchError((_) {});
    if (context.canPop()) {
      context.pop(true);
    } else {
      context.go('/home');
    }
  }

  void _openForm({required bool phone}) {
    Haptics.tap();
    setState(() {
      _formOpen = true;
      _usePhone = phone;
      _contact.clear();
      _fieldErrors = {};
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    // With no social sign-in configured, the form is the only way in, so show it straight away.
    final open = _formOpen || !GoogleAuthSection.anyAvailable(context);
    return AuthScaffold(
      title: l.registerTitle,
      subtitle: l.registerSubtitle,
      children: [
        FormErrorBanner(_error),
        // 1 + 2: Google and Facebook (each only when configured).
        GoogleAuthSection(
          divider: false,
          enabled: !_busy,
          onStart: () => setState(() {
            _error = null;
            _fieldErrors = {};
          }),
          onSignedIn: _onSignedIn,
          onError: (m) => setState(() => _error = m),
        ),
        // 3: phone number.
        AnimatedSize(
          duration: AppMotion.normal,
          curve: AppMotion.curve,
          alignment: Alignment.topCenter,
          child: open
              ? Padding(
                  padding: EdgeInsets.only(top: GoogleAuthSection.anyAvailable(context) ? 22 : 0),
                  child: _buildForm(text, l),
                )
              : Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _PhoneChoiceButton(
                    label: l.actionContinueWithPhone,
                    onPressed: _busy ? null : () => _openForm(phone: true),
                  ),
                ),
        ),
        const SizedBox(height: 18),
        Text(
          l.registerAgree,
          textAlign: TextAlign.center,
          style: text.labelSmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(l.registerHaveAccount, style: text.bodyMedium),
            TextButton(
              onPressed: () => context.pushReplacement('/login'),
              child: Text(l.actionLogIn, style: const TextStyle(color: AppColors.primary)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildForm(TextTheme text, AppLocalizations l) {
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _contact,
            keyboardType: _usePhone ? TextInputType.phone : TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofocus: _formOpen,
            autofillHints: [_usePhone ? AutofillHints.telephoneNumber : AutofillHints.email],
            decoration: InputDecoration(
              labelText: _usePhone ? l.fieldPhoneNumber : l.fieldEmail,
              hintText: _usePhone ? '0712 345 678' : 'you@example.com',
              prefixIcon: Icon(_usePhone ? Icons.phone_iphone_rounded : Icons.mail_outline_rounded),
              errorText: _fieldErrors['contact'],
            ),
            validator: (v) {
              final t = v?.trim() ?? '';
              if (t.isEmpty) return _usePhone ? l.validatePhoneRequired : l.validateEmailRequired;
              if (!_usePhone && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) {
                return l.validateEmailInvalid;
              }
              if (_usePhone && t.replaceAll(RegExp(r'\D'), '').length < 9) {
                return l.validatePhoneInvalid;
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            decoration: InputDecoration(
              labelText: l.fieldFullName,
              prefixIcon: const Icon(Icons.person_outline_rounded),
              errorText: _fieldErrors['name'],
            ),
            validator: (v) => (v == null || v.trim().length < 2) ? l.validateName : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _password,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            onFieldSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: l.fieldPassword,
              helperText: l.passwordHelper,
              helperStyle: text.labelSmall,
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              errorText: _fieldErrors['password'],
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: (v) => (v == null || v.length < 6) ? l.validatePasswordLength : null,
          ),
          const SizedBox(height: 22),
          PillButton(label: l.actionCreateAccount, expand: true, loading: _busy, onPressed: _submit),
          const SizedBox(height: 4),
          Center(
            child: TextButton(
              onPressed: _busy ? null : () => _openForm(phone: !_usePhone),
              child: Text(
                _usePhone ? l.registerWithEmail : l.registerWithPhone,
                style: text.labelMedium!.copyWith(color: AppColors.textMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Outlined pill matching the Google and Facebook buttons.
class _PhoneChoiceButton extends StatelessWidget {
  const _PhoneChoiceButton({required this.label, this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: StadiumBorder(side: BorderSide(color: AppColors.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          height: 50,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.phone_iphone_rounded, size: 20, color: AppColors.primary),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge!.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
