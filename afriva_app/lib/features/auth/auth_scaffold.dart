import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme.dart';
import '../../widgets/afriva_logo.dart';

/// Shared chrome for login / register: ambient glow, logo, title.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.title, required this.subtitle, required this.children});

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.canPop() ? context.pop(false) : context.go('/home'),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                  children: [
                    const Center(child: AfrivaMark(size: 48)),
                    const SizedBox(height: 28),
                    Text(title, style: text.headlineSmall!.copyWith(fontSize: 28), textAlign: TextAlign.center),
                    const SizedBox(height: 6),
                    Text(subtitle, style: text.bodyMedium, textAlign: TextAlign.center),
                    const SizedBox(height: 28),
                    ...children,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Inline banner for form-level errors.
class FormErrorBanner extends StatelessWidget {
  const FormErrorBanner(this.message, {super.key});
  final String? message;

  @override
  Widget build(BuildContext context) => AnimatedSize(
        duration: AppMotion.normal,
        child: message == null
            ? const SizedBox(width: double.infinity)
            : Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(message!,
                          style: Theme.of(context).textTheme.bodySmall!.copyWith(color: AppColors.text)),
                    ),
                  ],
                ),
              ),
      );
}
