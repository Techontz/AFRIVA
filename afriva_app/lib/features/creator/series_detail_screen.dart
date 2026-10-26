import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../models/episode.dart';
import '../../models/studio.dart';
import '../../services/creator_service.dart';
import '../../services/file_picker_service.dart';
import '../../widgets/buttons.dart';
import '../../widgets/net_image.dart';
import '../../widgets/sheet.dart';
import '../../widgets/skeletons.dart';
import '../../widgets/states.dart';
import 'review_chip.dart';

/// One of the creator's series: episodes with review/processing state, upload, submit, review history.
class SeriesDetailScreen extends StatefulWidget {
  const SeriesDetailScreen({super.key, required this.id});
  final int id;

  @override
  State<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends State<SeriesDetailScreen> {
  StudioDrama? _data;
  Object? _error;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final d = await context.read<CreatorService>().drama(widget.id);
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _episodeSheet({Episode? episode}) async {
    final changed = await showAfrivaSheet<bool>(
      context,
      builder: (_) => _EpisodeUploadSheet(dramaId: widget.id, episode: episode),
    );
    if (changed == true && mounted) _load();
  }

  Future<void> _deleteEpisode(Episode e) async {
    final ok = await _confirm(context.tr('Delete episode {n}?', {'n': e.number}));
    if (ok != true || !mounted) return;
    try {
      await context.read<CreatorService>().deleteEpisode(widget.id, e.id);
      _load();
    } catch (err) {
      if (mounted) showSnack(context, errorMessage(err), error: true);
    }
  }

  Future<void> _deleteSeries() async {
    final ok = await _confirm(context.tr('Delete this series and all its episodes?'));
    if (ok != true || !mounted) return;
    final router = GoRouter.of(context);
    try {
      await context.read<CreatorService>().deleteDrama(widget.id);
      router.pop(true);
    } catch (err) {
      if (mounted) showSnack(context, errorMessage(err), error: true);
    }
  }

  Future<bool?> _confirm(String title) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.tr('Cancel'))),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.tr('Delete'), style: const TextStyle(color: AppColors.danger)),
            ),
          ],
        ),
      );

  /// Rights declaration (scope §04 "Tamko la umiliki/haki") before sending for review.
  Future<void> _submit() async {
    var declared = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(ctx.tr('Send for review')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ctx.tr('AFRIVA will check quality, rights and playback. Your work is not published until it is approved.')),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: declared,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (v) => setLocal(() => declared = v ?? false),
                title: Text(ctx.tr('I confirm I own or have licensed all rights to this content (video, music, images and trailer).')),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.tr('Cancel'))),
            TextButton(onPressed: declared ? () => Navigator.pop(ctx, true) : null, child: Text(ctx.tr('Send'))),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _submitting = true);
    try {
      final d = await context.read<CreatorService>().submit(widget.id);
      if (!mounted) return;
      setState(() => _data = d);
      showSnack(context, context.tr('Sent for review. We will let you know the result here.'));
    } on ApiException catch (e) {
      if (!mounted) return;
      final first = e.errors.values.whereType<List>().expand((l) => l).map((x) => x.toString()).firstOrNull;
      showSnack(context, first ?? e.message, error: true);
      if (e.code == 'agreement_required') context.push('/creator/agreement').then((_) => _load());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final text = Theme.of(context).textTheme;
    if (data == null) {
      return Scaffold(
        appBar: AppBar(),
        body: _error != null ? ErrorState(error: _error!, onRetry: _load) : const ListSkeleton(count: 4),
      );
    }
    final d = data.drama;
    final rejected = d.reviewStatus == ReviewStatus.rejected;
    final pending = d.reviewStatus == ReviewStatus.submitted || d.reviewStatus == ReviewStatus.inReview;
    return Scaffold(
      appBar: AppBar(
        title: Text(d.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (data.editable)
            IconButton(
              tooltip: context.tr('Edit series'),
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push('/creator/series/${d.id}/edit').then((_) => _load()),
            ),
          if (data.editable || rejected)
            IconButton(
              tooltip: context.tr('Delete'),
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _deleteSeries,
            ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.paddingOf(context).bottom + 24),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.poster),
                  child: SizedBox(width: 84, height: 112, child: NetImage(d.posterUrl, memCacheWidth: 200)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ReviewStatusChip(d.reviewStatus, live: d.isLive),
                      const SizedBox(height: 6),
                      Text(d.categories.map((c) => c.name).join(' · '), style: text.labelSmall),
                      const SizedBox(height: 6),
                      Text(d.synopsis, maxLines: 4, overflow: TextOverflow.ellipsis, style: text.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            if ((d.reviewNotes ?? '').isNotEmpty && d.reviewStatus != ReviewStatus.approved) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFFFF4D6), borderRadius: BorderRadius.circular(AppRadii.card)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr('Reviewer notes'), style: text.titleSmall),
                    const SizedBox(height: 4),
                    Text(d.reviewNotes!, style: text.bodyMedium),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (pending)
              Text(context.tr('Under review. You cannot change it until AFRIVA responds.'), style: text.bodySmall)
            else if (rejected)
              Text(context.tr('This series was rejected and cannot be sent again.'), style: text.bodySmall)
            else
              PillButton(
                label: data.pendingEpisodes.isEmpty
                    ? context.tr('Add episodes to send for review')
                    : context.tr('Send for review ({n} episodes)', {'n': data.pendingEpisodes.length}),
                icon: Icons.send_rounded,
                expand: true,
                loading: _submitting,
                onPressed: data.canSubmit && !_submitting ? _submit : null,
              ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: Text(context.tr('Episodes'), style: text.titleMedium)),
                if (!pending && !rejected)
                  TextButton.icon(
                    onPressed: () => _episodeSheet(),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(context.tr('Add episode')),
                  ),
              ],
            ),
            if (data.episodes.isEmpty)
              StateMessage(icon: Icons.video_library_outlined, title: context.tr('No episodes yet'), compact: true)
            else
              for (final e in data.episodes)
                _EpisodeRow(
                  episode: e,
                  onEdit: ReviewStatus.isEditable(e.reviewStatus) ? () => _episodeSheet(episode: e) : null,
                  onDelete: ReviewStatus.isEditable(e.reviewStatus) ? () => _deleteEpisode(e) : null,
                ),
            if (data.reviews.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(context.tr('Review history'), style: text.titleMedium),
              const SizedBox(height: 6),
              for (final r in data.reviews)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.history_rounded, color: AppColors.textMuted),
                  title: Text(r.episodeNumber != null ? '${r.label} · EP ${r.episodeNumber}' : r.label),
                  subtitle: Text([Fmt.dateTime(r.createdAt), if ((r.notes ?? '').isNotEmpty) r.notes!].join('\n')),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EpisodeRow extends StatelessWidget {
  const _EpisodeRow({required this.episode, this.onEdit, this.onDelete});
  final Episode episode;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final e = episode;
    final video = switch (e.videoStatus) {
      'processing' || 'uploaded' => context.tr('Video processing…'),
      'failed' => context.tr('Video processing failed'),
      _ => e.durationSeconds > 0 ? Fmt.duration(Duration(seconds: e.durationSeconds)) : context.tr('Video ready'),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadii.card)),
      child: Row(
        children: [
          CircleAvatar(radius: 16, backgroundColor: AppColors.surface2, child: Text('${e.number}', style: text.labelLarge)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.title.isNotEmpty ? e.title : 'Episode ${e.number}', style: text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  video,
                  style: text.labelSmall!.copyWith(color: e.videoStatus == 'failed' ? AppColors.danger : null),
                ),
                if ((e.reviewNotes ?? '').isNotEmpty && e.reviewStatus == ReviewStatus.changesRequested)
                  Text(e.reviewNotes!, style: text.labelSmall!.copyWith(color: const Color(0xFFB54708))),
                const SizedBox(height: 4),
                ReviewStatusChip(e.reviewStatus),
              ],
            ),
          ),
          if (onEdit != null) IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: onEdit),
          if (onDelete != null) IconButton(icon: const Icon(Icons.delete_outline_rounded, size: 20), onPressed: onDelete),
        ],
      ),
    );
  }
}

/// Add or replace an episode: title, video (with upload progress), optional subtitles.
class _EpisodeUploadSheet extends StatefulWidget {
  const _EpisodeUploadSheet({required this.dramaId, this.episode});
  final int dramaId;
  final Episode? episode;

  @override
  State<_EpisodeUploadSheet> createState() => _EpisodeUploadSheetState();
}

class _EpisodeUploadSheetState extends State<_EpisodeUploadSheet> {
  final _title = TextEditingController();
  final _picker = const FilePickerService();
  PickedUpload? _video;
  PickedUpload? _subtitle;
  double? _progress;
  CancelToken? _cancel;
  String? _error;

  @override
  void initState() {
    super.initState();
    _title.text = widget.episode?.title ?? '';
  }

  @override
  void dispose() {
    _cancel?.cancel();
    _title.dispose();
    super.dispose();
  }

  Future<void> _upload() async {
    if (widget.episode == null && _video == null) {
      setState(() => _error = context.tr('Choose the episode video.'));
      return;
    }
    final cancel = CancelToken();
    setState(() {
      _progress = 0;
      _error = null;
      _cancel = cancel;
    });
    final nav = Navigator.of(context);
    try {
      await context.read<CreatorService>().saveEpisode(
            dramaId: widget.dramaId,
            episodeId: widget.episode?.id,
            title: _title.text,
            video: _video,
            subtitle: _subtitle,
            cancelToken: cancel,
            onProgress: (sent, total) {
              if (mounted && total > 0) setState(() => _progress = sent / total);
            },
          );
      if (mounted) nav.pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _progress = null;
        _error = e.fieldError('video') ?? e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final uploading = _progress != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.episode == null
                ? context.tr('Add episode')
                : context.tr('Episode {n}', {'n': widget.episode!.number}),
            style: text.titleLarge,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            enabled: !uploading,
            decoration: InputDecoration(labelText: context.tr('Episode title (optional)')),
          ),
          const SizedBox(height: 12),
          PillButton(
            label: _video?.name ?? context.tr(widget.episode == null ? 'Choose video' : 'Replace video'),
            icon: Icons.video_file_outlined,
            secondary: true,
            expand: true,
            height: 44,
            onPressed: uploading
                ? null
                : () async {
                    final f = await _picker.pickVideo();
                    if (f != null && mounted) setState(() => _video = f);
                  },
          ),
          if (_video != null && _video!.size > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('${(_video!.size / (1024 * 1024)).toStringAsFixed(1)} MB', style: text.labelSmall),
            ),
          const SizedBox(height: 8),
          PillButton(
            label: _subtitle?.name ?? context.tr('Add subtitles (.vtt / .srt, optional)'),
            icon: Icons.subtitles_outlined,
            secondary: true,
            expand: true,
            height: 44,
            onPressed: uploading
                ? null
                : () async {
                    final f = await _picker.pickSubtitle();
                    if (f != null && mounted) setState(() => _subtitle = f);
                  },
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: text.bodySmall!.copyWith(color: AppColors.danger)),
          ],
          const SizedBox(height: 16),
          if (uploading) ...[
            LinearProgressIndicator(value: _progress, color: AppColors.primary),
            const SizedBox(height: 6),
            Text(context.tr('Uploading {n}%', {'n': ((_progress ?? 0) * 100).round()}), style: text.labelSmall),
            const SizedBox(height: 8),
            TextButton(onPressed: () => _cancel?.cancel(), child: Text(context.tr('Cancel upload'))),
          ] else
            PillButton(label: context.tr('Save episode'), icon: Icons.cloud_upload_outlined, expand: true, onPressed: _upload),
          const SizedBox(height: 8),
          Text(
            context.tr('After uploading, the video is processed and checked by AFRIVA before viewers can see it.'),
            style: text.labelSmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
