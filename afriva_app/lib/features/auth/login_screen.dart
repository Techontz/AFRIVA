import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/haptics.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../state/auth_state.dart';
import '../../state/favorites_state.dart';
import '../../widgets/buttons.dart';
import 'auth_scaffold.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _login = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;
  Map<String, String?> _fieldErrors = {};

  @override
  void dispose() {
    _login.dispose();
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
    final auth = context.read<AuthState>();
    final favs = context.read<FavoritesState>();
    try {
      await auth.login(_login.text, _password.text);
      Haptics.success();
      favs.load().catchError((_) {});
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
        _fieldErrors = {'login': e.fieldError('login'), 'password': e.fieldError('password')};
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AuthScaffold(
      title: context.tr('Welcome back'),
      subtitle: context.tr('Log in to continue your stories, unlock episodes and go VIP.'),
      children: [
        Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FormErrorBanner(_error),
                TextFormField(
                  controller: _login,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email, AutofillHints.telephoneNumber],
                  decoration: InputDecoration(
                    labelText: context.tr('Email or phone'),
                    hintText: context.tr('you@example.com or 0712 345 678'),
                    prefixIcon: const Icon(Icons.alternate_email_rounded),
                    errorText: _fieldErrors['login'],
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? context.tr('Enter your email or phone') : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: context.tr('Password'),
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    errorText: _fieldErrors['password'],
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? context.tr('Enter your password') : null,
                ),
                const SizedBox(height: 24),
                PillButton(label: context.tr('Log in'), expand: true, loading: _busy, onPressed: _submit),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(context.tr('New to Afriva?'), style: text.bodyMedium),
                    TextButton(
                      onPressed: () => context.pushReplacement('/register'),
                      child: Text(context.tr('Create account'), style: const TextStyle(color: AppColors.primary)),
                    ),
                  ],
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: Wrap(
                      spacing: 8,
                      children: [
                        for (final email in const ['viewer@afriva.com', 'vip@afriva.com'])
                          ActionChip(
                            label: Text(email),
                            onPressed: () {
                              _login.text = email;
                              _password.text = 'password';
                            },
                            backgroundColor: AppColors.surface,
                            side: BorderSide.none,
                            labelStyle: text.labelSmall,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(child: Text(context.tr('Demo accounts (debug builds only)'), style: text.labelSmall)),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
