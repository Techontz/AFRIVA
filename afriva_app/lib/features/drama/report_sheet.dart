import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/i18n.dart';
import '../../models/drama.dart';
import '../../services/catalog_service.dart';
import '../../widgets/buttons.dart';
import '../../widgets/sheet.dart';
import '../../widgets/states.dart';

/// "Ripoti ukiukaji": report a copyright or content problem with a series (scope §04).
Future<void> showReportSheet(BuildContext context, Drama drama) => showAfrivaSheet<void>(
      context,
      builder: (_) => _ReportBody(drama: drama),
    );

class _ReportBody extends StatefulWidget {
  const _ReportBody({required this.drama});
  final Drama drama;

  @override
  State<_ReportBody> createState() => _ReportBodyState();
}

class _ReportBodyState extends State<_ReportBody> {
  static const _reasons = [
    ('copyright', 'Copyright: this is my work or I own the rights'),
    ('inappropriate', 'Inappropriate content'),
    ('misleading', 'Misleading title or poster'),
    ('other', 'Something else'),
  ];

  String _reason = 'copyright';
  final _details = TextEditingController();
  final _contact = TextEditingController();
  bool _busy = false;
  String? _detailsError;

  @override
  void dispose() {
    _details.dispose();
    _contact.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_reason == 'copyright' && _details.text.trim().isEmpty) {
      setState(() => _detailsError = context.tr('Describe the work and how you own it.'));
      return;
    }
    setState(() {
      _busy = true;
      _detailsError = null;
    });
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final msg = await context.read<CatalogService>().report(
            widget.drama.id,
            reason: _reason,
            details: _details.text,
            contact: _contact.text,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger?.showSnackBar(SnackBar(content: Text(msg.isNotEmpty ? msg : trNow('Thank you. Your report was received.'))));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _detailsError = e is ApiException ? e.fieldError('details') : null;
      });
      if (_detailsError == null) showSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(context.tr('Report "{title}"', {'title': widget.drama.title}), style: text.titleLarge),
          const SizedBox(height: 6),
          Text(context.tr('The AFRIVA team reviews every report.'), style: text.bodySmall),
          const SizedBox(height: 12),
          for (final (code, label) in _reasons)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: ChoiceChip(
                label: Text(context.tr(label)),
                selected: _reason == code,
                onSelected: (_) => setState(() => _reason = code),
              ),
            ),
          const SizedBox(height: 6),
          TextField(
            controller: _details,
            minLines: 3,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: context.tr('Details'),
              errorText: _detailsError,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _contact,
            decoration: InputDecoration(labelText: context.tr('Your phone or email (optional)')),
          ),
          const SizedBox(height: 16),
          PillButton(label: context.tr('Send report'), icon: Icons.flag_rounded, expand: true, loading: _busy, onPressed: _busy ? null : _send),
        ],
      ),
    );
  }
}
