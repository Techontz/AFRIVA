import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';

/// Consistent Afriva modal bottom sheet with a grab handle.
Future<T?> showAfrivaSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double? heightFactor,
  bool useRootNavigator = true,
  bool dismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: useRootNavigator,
    useSafeArea: true,
    isDismissible: dismissible,
    enableDrag: dismissible,
    backgroundColor: AppColors.surface,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (ctx) {
      final media = MediaQuery.of(ctx);
      final content = Column(
        mainAxisSize: heightFactor == null ? MainAxisSize.min : MainAxisSize.max,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 10),
          if (heightFactor == null) Builder(builder: builder) else Expanded(child: Builder(builder: builder)),
          SizedBox(height: media.padding.bottom + 12),
        ],
      );
      // Sheets follow the app theme, even when opened from the black player.
      return Theme(
        data: AppColors.isDark ? AppTheme.dark : AppTheme.light,
        child: Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: heightFactor == null
            ? content
            : SizedBox(height: media.size.height * heightFactor, child: content),
        ),
      );
    },
  );
}
