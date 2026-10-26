import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../services/creator_service.dart';
import '../../state/auth_state.dart';
import '../../widgets/buttons.dart';
import '../../widgets/states.dart';
import 'review_chip.dart';

/// "Wasilisha Kazi Yako" for viewers: become a creator (POST /creator/apply).
class CreatorApplyScreen extends StatefulWidget {
  const CreatorApplyScreen({super.key});

  @override
  State<CreatorApplyScreen> createState() => _CreatorApplyScreenState();
}

class _CreatorApplyScreenState extends State<CreatorApplyScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _about = TextEditingController();
  bool _busy = false;
  ApiException? _error;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthState>().user;
    _phone.text = user?.phone ?? '';
    _email.text = user?.email ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _about.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = context.read<AuthState>();
    final router = GoRouter.of(context);
    try {
      await context.read<CreatorService>().apply(
            name: _name.text,
            phone: _phone.text,
            email: _email.text,
            description: _about.text,
          );
      await auth.refresh();
      if (!mounted) return;
      showSnack(context, context.tr('Application received. You can start preparing your work.'));
      router.pushReplacement('/creator');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final user = context.watch<AuthState>().user;
    if (user?.isCreator == true) {
      return Scaffold(
        appBar: AppBar(),
        body: StateMessage(
          icon: Icons.video_call_outlined,
          title: context.tr('You are already a creator'),
          actionLabel: context.tr('Open Creator Studio'),
          onAction: () => context.pushReplacement('/creator'),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Submit your work'))),
      body: Form(
        key: _form,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.paddingOf(context).bottom + 24),
          children: [
            Text(context.tr('Share your African stories with AFRIVA viewers'), style: text.titleLarge),
            const SizedBox(height: 8),
            Text(
              context.tr('Uploading does not publish your work. Every series is reviewed by AFRIVA first, then published with a date, price and free episodes.'),
              style: text.bodyMedium,
            ),
            const SizedBox(height: 18),
            const SubmissionSteps(),
            const SizedBox(height: 10),
            TextFormField(
              controller: _name,
              decoration: InputDecoration(
                labelText: context.tr('Studio or creator name'),
                errorText: _error?.fieldError('name'),
              ),
              validator: (v) => (v ?? '').trim().isEmpty ? context.tr('Enter a name') : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: context.tr('Phone number'), errorText: _error?.fieldError('phone')),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(labelText: context.tr('Email'), errorText: _error?.fieldError('email')),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _about,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(labelText: context.tr('About you and your work (optional)')),
            ),
            if (_error != null && _error!.errors.isEmpty) ...[
              const SizedBox(height: 12),
              Text(_error!.message, style: text.bodySmall!.copyWith(color: AppColors.danger)),
            ],
            const SizedBox(height: 20),
            PillButton(
              label: context.tr('Become a creator'),
              icon: Icons.check_rounded,
              expand: true,
              loading: _busy,
              onPressed: _busy ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
