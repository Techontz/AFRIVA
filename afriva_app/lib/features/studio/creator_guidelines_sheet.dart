import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../l10n/l10n.dart';
import '../../models/studio_application.dart';
import '../../services/studio_service.dart';
import '../../widgets/buttons.dart';
import '../../widgets/sheet.dart';
import '../../widgets/states.dart';

/// Opens the Afriva creator guidelines with the live revenue split.
Future<void> showCreatorGuidelines(BuildContext context) {
  final service = context.read<StudioService>();
  return showAfrivaSheet<void>(
    context,
    heightFactor: 0.88,
    builder: (_) => CreatorGuidelinesView(load: service.guidelines),
  );
}

class CreatorGuidelinesView extends StatefulWidget {
  const CreatorGuidelinesView({super.key, required this.load});

  final Future<RevenueSplit> Function() load;

  @override
  State<CreatorGuidelinesView> createState() => _CreatorGuidelinesViewState();
}

class _CreatorGuidelinesViewState extends State<CreatorGuidelinesView> {
  late Future<RevenueSplit> _split;

  @override
  void initState() {
    super.initState();
    _split = widget.load();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    final points = <Widget Function()>[
      () => Text(l.guidelinesPoint1, style: text.bodyMedium),
      () => Text(l.guidelinesPoint2, style: text.bodyMedium),
      () => Text(l.guidelinesPoint3, style: text.bodyMedium),
      () => Text(l.guidelinesPoint4, style: text.bodyMedium),
      () => Text(l.guidelinesPoint5, style: text.bodyMedium),
      () => FutureBuilder<RevenueSplit>(
            future: _split,
            builder: (context, snap) {
              if (snap.hasData) {
                return Text(
                  l.guidelinesPoint6(snap.data!.creatorLabel, snap.data!.platformLabel),
                  style: text.bodyMedium!.copyWith(color: AppColors.text, fontWeight: FontWeight.w600),
                );
              }
              if (snap.hasError) {
                return ErrorState(
                  error: snap.error!,
                  compact: true,
                  onRetry: () => setState(() => _split = widget.load()),
                );
              }
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: LinearProgressIndicator(color: AppColors.primary),
              );
            },
          ),
      () => Text(l.guidelinesPoint7, style: text.bodyMedium),
      () => Text(l.guidelinesPoint8, style: text.bodyMedium),
      () => Text(l.guidelinesPoint9, style: text.bodyMedium),
    ];
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            children: [
              Text(l.guidelinesTitle, style: text.titleLarge),
              const SizedBox(height: 8),
              Text(l.guidelinesIntro, style: text.bodyMedium),
              const SizedBox(height: 16),
              for (var i = 0; i < points.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text('${i + 1}.',
                            style: text.titleSmall!.copyWith(color: AppColors.primary)),
                      ),
                      Expanded(child: points[i]()),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: PillButton(
            label: l.actionGotIt,
            expand: true,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
      ],
    );
  }
}
