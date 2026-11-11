import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/haptics.dart';
import '../../core/payments.dart';
import '../../core/theme.dart';
import '../../l10n/l10n.dart';
import '../../models/commerce.dart';
import '../../services/commerce_service.dart';
import '../../widgets/buttons.dart';
import '../../widgets/sheet.dart';
import 'payment_widgets.dart';

enum PromptOutcome { success, failed, retry, closed }

/// The pop-up shown after a mobile money checkout: "Check your phone".
///
/// The viewer approves on the prompt their network sends to the phone. This
/// sheet never asks for, or has a field for, a PIN. It polls the payment every
/// few seconds and reports how it ended.
Future<(PromptOutcome, Payment?)> showPaymentPrompt(
  BuildContext context, {
  required Payment payment,
  String? phone,
  MobileNetwork? network,
  String? networkName,
  bool mobileMoney = true,
  String? redirectUrl,
}) async {
  final res = await showAfrivaSheet<(PromptOutcome, Payment?)>(
    context,
    dismissible: false,
    builder: (_) => PaymentPromptSheet(
      payment: payment,
      phone: phone,
      network: network,
      networkName: networkName,
      mobileMoney: mobileMoney,
      redirectUrl: redirectUrl,
    ),
  );
  return res ?? (PromptOutcome.closed, payment);
}

enum _State { waiting, timeout, failed, success }

class PaymentPromptSheet extends StatefulWidget {
  const PaymentPromptSheet({
    super.key,
    required this.payment,
    this.phone,
    this.network,
    this.networkName,
    this.mobileMoney = true,
    this.redirectUrl,
    this.pollInterval = AppConfig.paymentPollInterval,
    this.timeout = AppConfig.paymentPollTimeout,
  });

  final Payment payment;
  final String? phone;
  final MobileNetwork? network;
  final String? networkName;
  final bool mobileMoney;
  final String? redirectUrl;
  final Duration pollInterval;
  final Duration timeout;

  @override
  State<PaymentPromptSheet> createState() => _PaymentPromptSheetState();
}

class _PaymentPromptSheetState extends State<PaymentPromptSheet> {
  late Payment _payment = widget.payment;
  _State _state = _State.waiting;
  Timer? _timer;
  late DateTime _started;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _started = DateTime.now();
    _timer?.cancel();
    _timer = Timer.periodic(widget.pollInterval, (_) => _check());
    setState(() => _state = _State.waiting);
  }

  Future<void> _check() async {
    if (_state != _State.waiting) return;
    if (DateTime.now().difference(_started) > widget.timeout) {
      _timer?.cancel();
      Haptics.medium();
      setState(() => _state = _State.timeout);
      return;
    }
    if (_checking) return;
    _checking = true;
    try {
      final p = await context.read<CommerceService>().payment(_payment.reference);
      if (!mounted) return;
      _payment = p;
      if (p.isSuccess) {
        _done();
      } else if (p.isFailed) {
        _timer?.cancel();
        Haptics.medium();
        setState(() => _state = _State.failed);
      }
    } catch (e) {
      // Keep polling through brief network trouble; give up at the timeout.
      if (e is ApiException && e.statusCode == 404) {
        _timer?.cancel();
        if (mounted) setState(() => _state = _State.failed);
      }
    } finally {
      _checking = false;
    }
  }

  void _done() {
    _timer?.cancel();
    Haptics.success();
    setState(() => _state = _State.success);
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) Navigator.of(context).pop((PromptOutcome.success, _payment));
    });
  }

  void _close(PromptOutcome o) => Navigator.of(context).pop((o, _payment));

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    final networkName = widget.network?.name ?? widget.networkName;
    final title = switch (_state) {
      _State.success => l.promptSuccess,
      _State.failed => _payment.status == 'cancelled' ? l.failedCancelledTitle : l.checkoutTitleFailed,
      _State.timeout => l.promptTimeoutTitle,
      _State.waiting => widget.mobileMoney ? l.promptTitle : l.promptCardTitle,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
      child: AnimatedSize(
        duration: AppMotion.slow,
        curve: AppMotion.curve,
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 132,
              child: AnimatedSwitcher(
                duration: AppMotion.slow,
                child: switch (_state) {
                  _State.waiting => _PhonePulse(key: const ValueKey('w'), mobile: widget.mobileMoney),
                  _State.success => const _ResultBadge(key: ValueKey('s'), ok: true),
                  _ => const _ResultBadge(key: ValueKey('f'), ok: false),
                },
              ),
            ),
            const SizedBox(height: 8),
            Text(title, style: text.headlineSmall!.copyWith(fontSize: 22), textAlign: TextAlign.center),
            const SizedBox(height: 10),
            if (_state == _State.waiting && widget.mobileMoney) ...[
              Text(
                networkName == null ? l.promptSentToPlain : l.promptSentTo(networkName),
                style: text.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              _NumberChip(phone: widget.phone, network: widget.network),
              const SizedBox(height: 18),
              _PinNotice(text: l.promptPinNote),
              const SizedBox(height: 18),
              _WaitingLine(label: l.promptWaiting),
            ] else if (_state == _State.waiting) ...[
              Text(l.promptCardBody, style: text.bodyMedium, textAlign: TextAlign.center),
              if (widget.redirectUrl != null) ...[
                const SizedBox(height: 10),
                SelectableText(l.checkoutRedirect(widget.redirectUrl!), style: text.bodySmall, textAlign: TextAlign.center),
              ],
              const SizedBox(height: 18),
              _WaitingLine(label: l.promptWaiting),
            ] else if (_state == _State.timeout)
              Text(l.promptTimeoutBody, style: text.bodyMedium, textAlign: TextAlign.center)
            else if (_state == _State.failed)
              Text(l.promptFailedBody, style: text.bodyMedium, textAlign: TextAlign.center)
            else
              Text(context.l10n.successRef(_payment.reference), style: text.labelSmall),
            const SizedBox(height: 22),
            ..._actions(l),
          ],
        ),
      ),
    );
  }

  List<Widget> _actions(AppLocalizations l) => switch (_state) {
        _State.waiting => [
            if (widget.mobileMoney)
              Text(l.promptNoPrompt, style: Theme.of(context).textTheme.labelSmall, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => _close(PromptOutcome.closed),
              child: Text(l.checkoutFinishLater, style: TextStyle(color: AppColors.textMuted)),
            ),
          ],
        _State.timeout => [
            PillButton(
              label: l.promptCheckAgain,
              icon: Icons.refresh_rounded,
              expand: true,
              onPressed: () {
                _start();
                _check();
              },
            ),
            const SizedBox(height: 10),
            PillButton(label: l.actionTryAgain, secondary: true, expand: true, onPressed: () => _close(PromptOutcome.retry)),
          ],
        _State.failed => [
            PillButton(label: l.actionTryAgain, expand: true, onPressed: () => _close(PromptOutcome.retry)),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => _close(PromptOutcome.failed),
              child: Text(l.actionClose, style: TextStyle(color: AppColors.textMuted)),
            ),
          ],
        _State.success => const [SizedBox(height: 40)],
      };
}

class _NumberChip extends StatelessWidget {
  const _NumberChip({this.phone, this.network});
  final String? phone;
  final MobileNetwork? network;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
        decoration: BoxDecoration(
          color: AppColors.text.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandMark.network(network ?? TzPhone.detect(phone ?? ''), size: 30),
            const SizedBox(width: 10),
            Text(
              TzPhone.pretty(phone),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text, letterSpacing: 0.4),
            ),
          ],
        ),
      );
}

class _PinNotice extends StatelessWidget {
  const _PinNotice({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.22)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lock_outline_rounded, size: 20, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text, style: Theme.of(context).textTheme.bodySmall!.copyWith(color: AppColors.text, height: 1.4)),
            ),
          ],
        ),
      );
}

/// "Waiting for your confirmation" with three breathing dots.
class _WaitingLine extends StatefulWidget {
  const _WaitingLine({required this.label});
  final String label;

  @override
  State<_WaitingLine> createState() => _WaitingLineState();
}

class _WaitingLineState extends State<_WaitingLine> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium!.copyWith(color: AppColors.textMuted),
            ),
          ),
          const SizedBox(width: 6),
          AnimatedBuilder(
            animation: _c,
            builder: (_, _) => Row(
              children: [
                for (var i = 0; i < 3; i++)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(
                        alpha: 0.25 + 0.75 * (0.5 + 0.5 * math.sin((_c.value - i * 0.18) * 2 * math.pi)).clamp(0.0, 1.0),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
}

/// A phone (or card) with soft red rings radiating out.
class _PhonePulse extends StatefulWidget {
  const _PhonePulse({super.key, required this.mobile});
  final bool mobile;

  @override
  State<_PhonePulse> createState() => _PhonePulseState();
}

class _PhonePulseState extends State<_PhonePulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: 132,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, child) => Stack(
            alignment: Alignment.center,
            children: [
              for (final phase in const [0.0, 0.33, 0.66])
                Builder(builder: (_) {
                  final t = (_c.value + phase) % 1;
                  return Opacity(
                    opacity: (1 - t) * 0.7,
                    child: Container(
                      width: 64 + 68 * t,
                      height: 64 + 68 * t,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary, width: 1.5),
                      ),
                    ),
                  );
                }),
              child!,
            ],
          ),
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.brandGradient,
              boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.45), blurRadius: 22)],
            ),
            child: Icon(
              widget.mobile ? Icons.phonelink_ring_rounded : Icons.credit_card_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
        ),
      );
}

class _ResultBadge extends StatelessWidget {
  const _ResultBadge({super.key, required this.ok});
  final bool ok;

  @override
  Widget build(BuildContext context) => Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.6, end: 1),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutBack,
          builder: (_, v, child) => Transform.scale(scale: v, child: child),
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ok ? AppColors.primary : AppColors.text.withValues(alpha: 0.08),
              boxShadow: ok ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.45), blurRadius: 26)] : null,
            ),
            child: Icon(
              ok ? Icons.check_rounded : Icons.priority_high_rounded,
              size: 40,
              color: ok ? Colors.white : AppColors.text,
            ),
          ),
        ),
      );
}
