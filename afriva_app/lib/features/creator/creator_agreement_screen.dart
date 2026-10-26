import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../models/studio.dart';
import '../../services/creator_service.dart';
import '../../state/auth_state.dart';
import '../../widgets/buttons.dart';
import '../../widgets/skeletons.dart';
import '../../widgets/states.dart';

/// Creator revenue agreement ("mkataba wa mapato"), accepted before any submission.
class CreatorAgreementScreen extends StatefulWidget {
  const CreatorAgreementScreen({super.key});

  @override
  State<CreatorAgreementScreen> createState() => _CreatorAgreementScreenState();
}

class _CreatorAgreementScreenState extends State<CreatorAgreementScreen> {
  CreatorAgreement? _agreement;
  Object? _error;
  bool _checked = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final a = await context.read<CreatorService>().agreement();
      if (mounted) setState(() => _agreement = a);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _accept() async {
    setState(() => _busy = true);
    final auth = context.read<AuthState>();
    final nav = Navigator.of(context);
    try {
      await context.read<CreatorService>().acceptAgreement();
      await auth.refresh();
      if (mounted) nav.pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, errorMessage(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = _agreement;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Revenue agreement'))),
      body: a == null
          ? (_error != null ? ErrorState(error: _error!, onRetry: _load) : const ListSkeleton(count: 4))
          : ListView(
              padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.paddingOf(context).bottom + 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadii.card)),
                  child: Text(a.text, style: text.bodyMedium),
                ),
                const SizedBox(height: 12),
                Text(
                  context.tr('Your revenue share: {n}%', {'n': a.revenueSharePercent.toStringAsFixed(0)}),
                  style: text.titleSmall,
                ),
                Text(context.tr('Version {v}', {'v': a.version}), style: text.labelSmall),
                const SizedBox(height: 16),
                if (a.accepted)
                  StateMessage(
                    icon: Icons.verified_rounded,
                    title: context.tr('You accepted this agreement'),
                    message: Fmt.dateTime(a.acceptedAt),
                    compact: true,
                  )
                else ...[
                  CheckboxListTile(
                    value: _checked,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (v) => setState(() => _checked = v ?? false),
                    title: Text(context.tr('I have read and accept the AFRIVA creator revenue agreement.')),
                  ),
                  const SizedBox(height: 12),
                  PillButton(
                    label: context.tr('Accept agreement'),
                    expand: true,
                    loading: _busy,
                    onPressed: _checked && !_busy ? _accept : null,
                  ),
                ],
              ],
            ),
    );
  }
}
