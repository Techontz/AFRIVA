import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/haptics.dart';
import '../../core/theme.dart';
import '../../l10n/l10n.dart';
import '../../services/google_auth.dart';
import '../../state/auth_state.dart';

/// "or" divider plus "Continue with Google". Renders nothing until Google
/// sign-in is configured (see [AppConfig.googleServerClientId]).
///
/// Runs the whole flow: Google account picker, `POST /auth/google`, then the
/// same session handling as password login via [AuthState.loginWithGoogle].
class GoogleAuthSection extends StatefulWidget {
  const GoogleAuthSection({
    super.key,
    required this.onSignedIn,
    required this.onError,
    this.onStart,
    this.enabled = true,
  });

  /// Called once the Afriva session exists.
  final VoidCallback onSignedIn;

  /// Called with a localized message when sign-in fails.
  final ValueChanged<String> onError;

  /// Called when the flow starts (e.g. to clear an old error banner).
  final VoidCallback? onStart;
  final bool enabled;

  @override
  State<GoogleAuthSection> createState() => _GoogleAuthSectionState();
}

class _GoogleAuthSectionState extends State<GoogleAuthSection> {
  bool _busy = false;

  Future<void> _run(GoogleAuth google) async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    widget.onStart?.call();
    setState(() => _busy = true);
    final auth = context.read<AuthState>();
    final l = context.l10n;
    try {
      final token = await google.idToken();
      if (token == null) return; // Cancelled in Google's sheet.
      await auth.loginWithGoogle(token);
      Haptics.success();
      if (mounted) widget.onSignedIn();
    } on GoogleAuthException catch (e) {
      Haptics.medium();
      if (mounted) {
        widget.onError(
            e.reason == GoogleAuthFailure.unavailable ? l.googleSignInUnavailable : l.googleSignInFailed);
      }
    } on ApiException catch (e) {
      Haptics.medium();
      if (mounted) widget.onError(e.message);
    } catch (e) {
      if (mounted) widget.onError(errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final google = context.read<GoogleAuth?>();
    if (google == null || !google.isAvailable) return const SizedBox.shrink();
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        _OrDivider(label: l.authOr),
        const SizedBox(height: 20),
        GoogleSignInButton(
          label: l.actionContinueWithGoogle,
          loading: _busy,
          onPressed: widget.enabled ? () => _run(google) : null,
        ),
      ],
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final line = Expanded(child: Divider(color: AppColors.border, height: 1, thickness: 1));
    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(label, style: Theme.of(context).textTheme.labelMedium!.copyWith(color: AppColors.textMuted)),
        ),
        line,
      ],
    );
  }
}

/// Google-branded pill button: the light variant on light theme, the dark
/// variant on dark theme, each with the full-colour "G" (per Google's
/// Sign-In branding guidelines).
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({super.key, required this.label, this.onPressed, this.loading = false});

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fill = dark ? const Color(0xFF131314) : Colors.white;
    final stroke = dark ? const Color(0xFF8E918F) : const Color(0xFF747775);
    final fg = dark ? const Color(0xFFE3E3E3) : const Color(0xFF1F1F1F);
    final enabled = onPressed != null && !loading;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.pill),
      side: BorderSide(color: stroke),
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: AnimatedOpacity(
        duration: AppMotion.fast,
        opacity: enabled || loading ? 1 : 0.5,
        child: Material(
          color: fill,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled
                ? () {
                    Haptics.tap();
                    onPressed!();
                  }
                : null,
            child: SizedBox(
              height: 50,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox.square(
                      dimension: 20,
                      child: loading
                          ? Padding(
                              padding: const EdgeInsets.all(1),
                              child: CircularProgressIndicator(strokeWidth: 2.2, color: fg),
                            )
                          : const GoogleLogo(size: 20),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge!.copyWith(
                              color: fg,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.25,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The multicolour Google "G", drawn locally (no network image).
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 20});
  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: const _GoogleLogoPainter());
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  // Paths from Google's 48x48 "G" mark.
  static final Path _red = Path()
    ..moveTo(24, 9.5)
    ..relativeCubicTo(3.54, 0, 6.71, 1.22, 9.21, 3.6)
    ..relativeLineTo(6.85, -6.85)
    ..cubicTo(35.9, 2.38, 30.47, 0, 24, 0)
    ..cubicTo(14.62, 0, 6.51, 5.38, 2.56, 13.22)
    ..relativeLineTo(7.98, 6.19)
    ..cubicTo(12.43, 13.72, 17.74, 9.5, 24, 9.5)
    ..close();

  static final Path _blue = Path()
    ..moveTo(46.98, 24.55)
    ..relativeCubicTo(0, -1.57, -0.15, -3.09, -0.38, -4.55)
    ..lineTo(24, 20)
    ..relativeLineTo(0, 9.02)
    ..relativeLineTo(12.94, 0)
    ..relativeCubicTo(-0.58, 2.96, -2.26, 5.48, -4.78, 7.18)
    ..relativeLineTo(7.73, 6)
    ..relativeCubicTo(4.51, -4.18, 7.09, -10.36, 7.09, -17.65)
    ..close();

  static final Path _yellow = Path()
    ..moveTo(10.53, 28.59)
    ..relativeCubicTo(-0.48, -1.45, -0.76, -2.99, -0.76, -4.59)
    ..relativeCubicTo(0, -1.6, 0.27, -3.14, 0.76, -4.59)
    ..relativeLineTo(-7.98, -6.19)
    ..cubicTo(0.92, 16.46, 0, 20.12, 0, 24)
    ..relativeCubicTo(0, 3.88, 0.92, 7.54, 2.56, 10.78)
    ..relativeLineTo(7.97, -6.19)
    ..close();

  static final Path _green = Path()
    ..moveTo(24, 48)
    ..relativeCubicTo(6.48, 0, 11.93, -2.13, 15.89, -5.81)
    ..relativeLineTo(-7.73, -6)
    ..relativeCubicTo(-2.15, 1.45, -4.92, 2.3, -8.16, 2.3)
    ..relativeCubicTo(-6.26, 0, -11.57, -4.22, -13.47, -9.91)
    ..relativeLineTo(-7.98, 6.19)
    ..cubicTo(6.51, 42.62, 14.62, 48, 24, 48)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 48, size.height / 48);
    final paint = Paint()..isAntiAlias = true;
    canvas.drawPath(_red, paint..color = const Color(0xFFEA4335));
    canvas.drawPath(_blue, paint..color = const Color(0xFF4285F4));
    canvas.drawPath(_yellow, paint..color = const Color(0xFFFBBC05));
    canvas.drawPath(_green, paint..color = const Color(0xFF34A853));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
