import 'package:material_ui/material_ui.dart';

import '../core/haptics.dart';
import '../core/theme.dart';

/// Quiet pill used for filters and ranges, matching the website's chips:
/// solid text colour when selected, a faint wash otherwise.
class CalmChip extends StatelessWidget {
  const CalmChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Haptics.tap();
        onTap();
      },
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.curve,
        height: 34,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.text
              : AppColors.text.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Text(
          label,
          maxLines: 1,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.bg : AppColors.textMuted,
          ),
        ),
      ),
    ),
  );
}

/// A row of [CalmChip]s driven by the nearest [DefaultTabController].
class CalmTabBar extends StatefulWidget {
  const CalmTabBar({
    super.key,
    required this.labels,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });
  final List<String> labels;
  final EdgeInsets padding;

  @override
  State<CalmTabBar> createState() => _CalmTabBarState();
}

class _CalmTabBarState extends State<CalmTabBar> {
  TabController? _controller;
  late List<GlobalKey> _keys = _makeKeys();

  List<GlobalKey> _makeKeys() => [for (final _ in widget.labels) GlobalKey()];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final c = DefaultTabController.of(context);
    if (c != _controller) {
      _controller?.removeListener(_onTab);
      _controller = c..addListener(_onTab);
    }
  }

  @override
  void didUpdateWidget(CalmTabBar old) {
    super.didUpdateWidget(old);
    if (old.labels.length != widget.labels.length) _keys = _makeKeys();
  }

  @override
  void dispose() {
    _controller?.removeListener(_onTab);
    super.dispose();
  }

  void _onTab() {
    if (!mounted) return;
    setState(() {});
    final i = _controller!.index;
    if (i >= _keys.length) return;
    final ctx = _keys[i].currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.5,
        duration: AppMotion.slow,
        curve: AppMotion.curve,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _controller?.index ?? 0;
    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: widget.padding,
        child: Row(
          children: [
            for (var i = 0; i < widget.labels.length; i++)
              Padding(
                key: _keys[i],
                padding: EdgeInsets.only(
                  right: i == widget.labels.length - 1 ? 0 : 8,
                ),
                child: CalmChip(
                  label: widget.labels[i],
                  selected: i == current,
                  onTap: () => _controller?.animateTo(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
