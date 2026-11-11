import 'package:material_ui/material_ui.dart';

import '../core/api_client.dart';
import '../core/theme.dart';
import '../l10n/l10n.dart';
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
            Icon(icon, size: compact ? 26 : 34, color: AppColors.textDim),
            const SizedBox(height: 14),
            Text(title, textAlign: TextAlign.center, style: text.titleMedium),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(message!, textAlign: TextAlign.center, style: text.bodyMedium),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 22),
              PillButton(label: actionLabel!, onPressed: onAction, height: 44, secondary: true),
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
    final l = context.l10n;
    final network = error is ApiException && (error as ApiException).isNetwork;
    return StateMessage(
      icon: network ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
      title: network ? l.stateOffline : l.stateSomethingWrong,
      message: errorMessage(error),
      actionLabel: l.actionTryAgain,
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

/// Section heading: bold title on the left, quiet "See all" on the right.
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
      padding: padding ?? const EdgeInsets.fromLTRB(16, 30, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: text.titleLarge!.copyWith(fontSize: 19, fontWeight: FontWeight.w700),
            ),
          ),
          if (onMore != null)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onMore,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 0, 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.l10n.actionSeeAll,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textMuted),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
                  ],
                ),
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
