import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../l10n/l10n.dart';
import '../../models/studio_application.dart';
import '../../services/studio_service.dart';
import '../../widgets/states.dart';
import 'creator_guidelines_sheet.dart';
import 'studio_widgets.dart';

/// Shows the signed-in user's studio request: review status, samples and
/// where to upload them.
class StudioStatusScreen extends StatefulWidget {
  const StudioStatusScreen({super.key});

  @override
  State<StudioStatusScreen> createState() => _StudioStatusScreenState();
}

class _StudioStatusScreenState extends State<StudioStatusScreen> {
  late Future<StudioApplication?> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<StudioService>().myApplication();
  }

  Future<void> _reload() async {
    final f = context.read<StudioService>().myApplication();
    setState(() => _future = f);
    try {
      await f;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.studioStatusTitle),
        actions: [
          IconButton(
            tooltip: l.guidelinesTitle,
            icon: const Icon(Icons.menu_book_outlined),
            onPressed: () => showCreatorGuidelines(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _reload,
        child: FutureBuilder<StudioApplication?>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator(color: AppColors.primary));
            }
            if (snap.hasError) {
              return ScrollableFill(child: ErrorState(error: snap.error!, onRetry: _reload));
            }
            final app = snap.data;
            if (app == null) {
              return ScrollableFill(
                child: StateMessage(
                  icon: Icons.movie_creation_outlined,
                  title: l.studioNoApplicationTitle,
                  message: l.studioNoApplicationMessage,
                  actionLabel: l.requestToPost,
                  onAction: () => context.pushReplacement('/studio/apply'),
                ),
              );
            }
            return StudioStatusView(application: app);
          },
        ),
      ),
    );
  }
}

class StudioStatusView extends StatelessWidget {
  const StudioStatusView({super.key, required this.application});
  final StudioApplication application;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    final app = application;
    final status = app.effectiveStatus;
    final color = studioStatusColor(status);
    final sum = app.summary;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.paddingOf(context).bottom + 24),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    switch (status) {
                      'approved' => Icons.verified_rounded,
                      'rejected' => Icons.cancel_outlined,
                      _ => Icons.hourglass_top_rounded,
                    },
                    color: color,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(studioStatusLabel(l, status), style: text.titleMedium!.copyWith(color: color)),
                  ),
                ],
              ),
              if (app.companyName.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(app.companyName, style: text.titleSmall),
              ],
              if (app.createdAt != null) ...[
                const SizedBox(height: 2),
                Text(l.studioSubmittedOn(Fmt.date(app.createdAt)), style: text.labelSmall),
              ],
              if (status == 'rejected' && (app.rejectionReason ?? '').isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(l.studioRejectionReason(app.rejectionReason!), style: text.bodyMedium),
              ],
              if (status == 'approved') ...[
                const SizedBox(height: 10),
                Text(l.studioApprovedBody, style: text.bodyMedium),
              ],
              if (status == 'ready_for_review') ...[
                const SizedBox(height: 10),
                Text(l.studioReadyBody, style: text.bodyMedium),
              ],
              if (app.revenueSplit != null) ...[
                const SizedBox(height: 10),
                Text(
                  l.studioRevenueSplit(app.revenueSplit!.creatorLabel, app.revenueSplit!.platformLabel),
                  style: text.bodySmall,
                ),
              ],
            ],
          ),
        ),
        StudioSectionLabel(l.studioSamplesValid(sum.valid, sum.required)),
        Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: sum.required == 0 ? 0 : (sum.valid / sum.required).clamp(0, 1).toDouble(),
                        minHeight: 6,
                        color: AppColors.primary,
                        backgroundColor: AppColors.surface2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(l.studioSamplesUploaded(sum.uploaded), style: text.labelSmall),
                  ],
                ),
              ),
              if (app.samples.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(l.studioNoSamples, style: text.bodySmall),
                  ),
                )
              else
                for (final s in app.samples) _SampleTile(sample: s),
            ],
          ),
        ),
        if (status != 'rejected') ...[
          const SizedBox(height: 18),
          StudioWebsiteCard(showSamples: status != 'approved'),
        ],
      ],
    );
  }
}

class _SampleTile extends StatelessWidget {
  const _SampleTile({required this.sample});
  final StudioSample sample;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    final statusLabel = switch (sample.status) {
      'processing' => l.studioSampleProcessing,
      'ready' => l.studioSampleReady,
      'failed' => l.studioSampleFailed,
      _ => l.studioSampleUploading,
    };
    final lengthMark = switch (sample.lengthCheck) {
      'too_short' => l.studioSampleTooShort,
      'too_long' => l.studioSampleTooLong,
      _ => null,
    };
    final parts = [
      statusLabel,
      if (sample.durationSeconds != null) Fmt.duration(Duration(seconds: sample.durationSeconds!)),
    ];
    return ListTile(
      leading: Icon(
        sample.valid
            ? Icons.check_circle_rounded
            : sample.status == 'failed' || lengthMark != null
                ? Icons.error_outline_rounded
                : Icons.schedule_rounded,
        color: sample.valid
            ? AppColors.success
            : sample.status == 'failed' || lengthMark != null
                ? AppColors.danger
                : AppColors.textMuted,
      ),
      title: Text(
        sample.title.isEmpty ? '#${sample.id}' : sample.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: text.titleSmall,
      ),
      subtitle: Text(parts.join('  ·  '), style: text.labelSmall),
      trailing: lengthMark == null
          ? null
          : Text(lengthMark, style: text.labelSmall!.copyWith(color: AppColors.danger, fontWeight: FontWeight.w700)),
    );
  }
}
