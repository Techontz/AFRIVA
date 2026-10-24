import 'package:material_ui/material_ui.dart';

import '../core/api_client.dart';
import '../core/theme.dart';
import 'buttons.dart';

/// Friendly empty / error / prompt state with an optional action.
class StateMessage extends StatelessWidget {
  const StateMessage({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32, vertical: compact ? 24 : 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: compact ? 56 : 76,
              height: compact ? 56 : 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.surface,
              ),
              child: Icon(icon, size: compact ? 26 : 34, color: AppColors.primary),
            ),
            const SizedBox(height: 18),
            Text(title, textAlign: TextAlign.center, style: text.titleMedium),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(message!, textAlign: TextAlign.center, style: text.bodyMedium),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 22),
              PillButton(label: actionLabel!, onPressed: onAction, height: 44),
            ],
          ],
        ),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.error, required this.onRetry, this.compact = false});

  final Object error;
  final VoidCallback onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final network = error is ApiException && (error as ApiException).isNetwork;
    return StateMessage(
      icon: network ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
      title: network ? "You're offline" : 'Something went wrong',
      message: errorMessage(error),
      actionLabel: 'Try again',
      onAction: onRetry,
      compact: compact,
    );
  }
}

/// Wraps a non-scrollable state so it still supports pull-to-refresh.
class ScrollableFill extends StatelessWidget {
  const ScrollableFill({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: child,
          ),
        ),
      );
}

/// Section heading: bold title on the left, "More >" on the right.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.onMore,
    this.padding,
    this.icon = Icons.movie_filter_rounded,
  });

  final String title;
  final IconData icon;
  final VoidCallback? onMore;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(16, 22, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: text.titleLarge!.copyWith(fontSize: 20, fontWeight: FontWeight.w800),
            ),
          ),
          if (onMore != null)
            TextButton(
              onPressed: onMore,
              style: TextButton.styleFrom(foregroundColor: text.titleLarge!.color),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [Text('More'), Icon(Icons.chevron_right_rounded, size: 18)],
              ),
            ),
        ],
      ),
    );
  }
}

void showSnack(BuildContext context, String message, {bool error = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(
        children: [
          Icon(
            error ? Icons.error_outline_rounded : Icons.check_circle_rounded,
            color: error ? AppColors.danger : AppColors.success,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    ));
}
