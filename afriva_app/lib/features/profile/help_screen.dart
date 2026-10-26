import 'package:material_ui/material_ui.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';

/// "Msaada": answers to common questions and how to reach support.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const _faq = [
    ('Which episodes are free?', 'The first episodes of every series are free (usually episodes 1-8). Each series shows exactly which ones before you start.'),
    ('How do I unlock the other episodes?', 'Join VIP to watch everything, or unlock single episodes with coins or an episode pack.'),
    ('How do I pay?', 'In Tanzania with M-Pesa, Mixx by Yas (Tigo Pesa), Airtel Money or HaloPesa. Outside Tanzania with Visa or Mastercard. You get coins or VIP as soon as the payment is confirmed, plus a receipt.'),
    ('I paid but did not receive anything', 'Open Payment history: if the payment is still pending, wait a moment. If it failed, no money was taken. Otherwise contact us with the payment reference.'),
    ('How do I submit my own series?', 'Open Profile → Submit your work. AFRIVA reviews every submission before it is published.'),
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Help'))),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.paddingOf(context).bottom + 24),
        children: [
          for (final (q, a) in _faq)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(context.tr(q), style: text.titleSmall),
              childrenPadding: const EdgeInsets.only(bottom: 12),
              children: [Align(alignment: Alignment.centerLeft, child: Text(context.tr(a), style: text.bodyMedium))],
            ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadii.card)),
            child: Row(
              children: [
                const Icon(Icons.support_agent_rounded, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(child: Text(context.tr('Need more help? Email support@afriva.com'), style: text.bodyMedium)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
