import 'package:material_ui/material_ui.dart';

/// Afriva logo: white "AFRIVA" wordmark on a red block.
/// [size] matches the old wordmark text size; the image is drawn a bit taller.
class AfrivaLogo extends StatelessWidget {
  const AfrivaLogo({super.key, this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Afriva',
      child: ExcludeSemantics(
        child: Image.asset(
          'assets/images/afriva_logo.png',
          height: size * 1.3,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}
