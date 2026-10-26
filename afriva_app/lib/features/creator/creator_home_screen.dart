import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/haptics.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../models/drama.dart';
import '../../models/studio.dart';
import '../../services/creator_service.dart';
import '../../state/auth_state.dart';
import '../../widgets/buttons.dart';
import '../../widgets/net_image.dart';
import '../../widgets/skeletons.dart';
import '../../widgets/states.dart';
import 'review_chip.dart';

/// Creator Studio in the app: account status, revenue agreement and the creator's series.
class CreatorHomeScreen extends StatefulWidget {
  const CreatorHomeScreen({super.key});

  @override
  State<CreatorHomeScreen> createState() => _CreatorHomeScreenState();
}

class _CreatorHomeScreenState extends State<CreatorHomeScreen> {
  CreatorAgreement? _agreement;
  List<Drama>? _dramas;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    final service = context.read<CreatorService>();
    try {
      final results = await Future.wait([service.agreement(), service.dramas()]);
      if (!mounted) return;
      setState(() {
        _agreement = results[0] as CreatorAgreement;
        _dramas = results[1] as List<Drama>;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _open(String path) async {
    Haptics.tap();
    await context.push(path);
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthState>().user;
    if (user != null && !user.isCreator) {
      return Scaffold(
        appBar: AppBar(),
        body: StateMessage(
          icon: Icons.video_call_outlined,
          title: context.tr('Become a creator first'),
          actionLabel: context.tr('Submit your work'),
          onAction: () => context.pushReplacement('/creator/apply'),
        ),
      );
    }
    final dramas = _dramas;
    final a = _agreement;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Creator Studio'))),
      floatingActionButton: a == null
          ? null
          : FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              onPressed: () => _open('/creator/series/new'),
              icon: const Icon(Icons.add_rounded),
              label: Text(context.tr('New series')),
            ),
      body: dramas == null || a == null
          ? (_error != null ? ErrorState(error: _error!, onRetry: _load) : const ListSkeleton(count: 4))
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.paddingOf(context).bottom + 96),
                children: [
                  if (!a.creatorApproved)
                    _Notice(
                      icon: Icons.hourglass_top_rounded,
                      title: a.companyStatus == 'suspended'
                          ? context.tr('Your creator account is suspended')
                          : context.tr('Your creator account is being reviewed'),
                      body: context.tr('You can prepare series and episodes now. You can send them for review once AFRIVA approves your account.'),
                    ),
                  if (!a.accepted)
                    _Notice(
                      icon: Icons.description_outlined,
                      title: context.tr('Accept the revenue agreement'),
                      body: context.tr('Required before you can send work for review.'),
                      action: context.tr('Read agreement'),
                      onAction: () => _open('/creator/agreement'),
                    ),
                  const SizedBox(height: 8),
                  Text(context.tr('My series'), style: text.titleMedium),
                  const SizedBox(height: 8),
                  if (dramas.isEmpty) ...[
                    StateMessage(
                      icon: Icons.movie_creation_outlined,
                      title: context.tr('No series yet'),
                      message: context.tr('Create your first series, add episodes, then send it for review.'),
                      compact: true,
                    ),
                    const SubmissionSteps(),
                  ] else
                    for (final d in dramas)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Material(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadii.card),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(AppRadii.card),
                            onTap: () => _open('/creator/series/${d.id}'),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(AppRadii.poster),
                                    child: SizedBox(width: 54, height: 72, child: NetImage(d.posterUrl, memCacheWidth: 160)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(d.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.titleSmall),
                                        const SizedBox(height: 4),
                                        Text(context.tr('{n} episodes live', {'n': d.totalEpisodes}), style: text.labelSmall),
                                        const SizedBox(height: 6),
                                        ReviewStatusChip(d.reviewStatus, live: d.isLive),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right_rounded, color: AppColors.textDim),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                ],
              ),
            ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.title, required this.body, this.action, this.onAction});
  final IconData icon;
  final String title;
  final String body;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(gradient: AppColors.vipCardGradient, borderRadius: BorderRadius.circular(AppRadii.card)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleSmall),
                const SizedBox(height: 2),
                Text(body, style: text.bodySmall),
                if (action != null && onAction != null) ...[
                  const SizedBox(height: 8),
                  PillButton(label: action!, height: 36, onPressed: onAction),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
