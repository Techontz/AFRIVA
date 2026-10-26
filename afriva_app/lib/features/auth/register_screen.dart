import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/haptics.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../state/auth_state.dart';
import '../../widgets/buttons.dart';
import 'auth_scaffold.dart';

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
  bool _usePhone = false;
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
      if (!mounted) return;
      if (context.canPop()) {
        context.pop(true);
      } else {
        context.go('/home');
      }
    } on ApiException catch (e) {
      Haptics.medium();
      setState(() {
        _error = e.message;
        _fieldErrors = {
          'name': e.fieldError('name'),
          'contact': e.fieldError(_usePhone ? 'phone' : 'email'),
          'password': e.fieldError('password'),
        };
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AuthScaffold(
      title: context.tr('Create your account'),
      subtitle: context.tr('Free episodes every day. Save your list and pick up where you left off.'),
      children: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FormErrorBanner(_error),
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: false, label: Text(context.tr('Email')), icon: const Icon(Icons.mail_outline_rounded)),
                  ButtonSegment(value: true, label: Text(context.tr('Phone')), icon: const Icon(Icons.phone_iphone_rounded)),
                ],
                selected: {_usePhone},
                showSelectedIcon: false,
                onSelectionChanged: (s) {
                  Haptics.tap();
                  setState(() {
                    _usePhone = s.first;
                    _contact.clear();
                  });
                },
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith(
                    (s) => s.contains(WidgetState.selected)
                        ? AppColors.primary
                        : AppColors.surface,
                  ),
                  foregroundColor: WidgetStateProperty.resolveWith(
                    (s) => s.contains(WidgetState.selected) ? Colors.white : AppColors.textMuted,
                  ),
                  side: const WidgetStatePropertyAll(BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                decoration: InputDecoration(
                  labelText: context.tr('Full name'),
                  prefixIcon: const Icon(Icons.person_outline_rounded),
                  errorText: _fieldErrors['name'],
                ),
                validator: (v) => (v == null || v.trim().length < 2) ? context.tr('Enter your name') : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _contact,
                keyboardType: _usePhone ? TextInputType.phone : TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: [_usePhone ? AutofillHints.telephoneNumber : AutofillHints.email],
                decoration: InputDecoration(
                  labelText: context.tr(_usePhone ? 'Phone number' : 'Email'),
                  hintText: _usePhone ? '0712 345 678' : 'you@example.com',
                  prefixIcon: Icon(_usePhone ? Icons.phone_iphone_rounded : Icons.mail_outline_rounded),
                  errorText: _fieldErrors['contact'],
                ),
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (t.isEmpty) return context.tr(_usePhone ? 'Enter your phone number' : 'Enter your email');
                  if (!_usePhone && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) {
                    return context.tr('Enter a valid email');
                  }
                  if (_usePhone && t.replaceAll(RegExp(r'\D'), '').length < 9) {
                    return context.tr('Enter a valid phone number');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: context.tr('Password'),
                  helperText: context.tr('At least 8 characters'),
                  helperStyle: text.labelSmall,
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  errorText: _fieldErrors['password'],
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) => (v == null || v.length < 8) ? context.tr('Use at least 8 characters') : null,
              ),
              const SizedBox(height: 24),
              PillButton(label: context.tr('Create account'), expand: true, loading: _busy, onPressed: _submit),
              const SizedBox(height: 12),
              Text(
                context.tr('By continuing you agree to the Afriva Terms and Privacy Policy.'),
                textAlign: TextAlign.center,
                style: text.labelSmall,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(context.tr('Already have an account?'), style: text.bodyMedium),
                  TextButton(
                    onPressed: () => context.pushReplacement('/login'),
                    child: Text(context.tr('Log in'), style: const TextStyle(color: AppColors.primary)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
