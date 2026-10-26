import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import 'drama_grid.dart';

/// Full grid for a home section / category with Popular / Newest sort.
class BrowseScreen extends StatefulWidget {
  const BrowseScreen({super.key, required this.title, this.category, this.sort = 'popular'});

  final String title;
  final String? category;
  final String sort;

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  late String _sort = widget.sort;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr(widget.title)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                for (final (key, label) in const [('popular', 'Popular'), ('newest', 'Newest')]) ...[
                  ChoiceChip(
                    label: Text(context.tr(label)),
                    selected: _sort == key,
                    showCheckmark: false,
                    onSelected: (_) {
                      Haptics.tap();
                      setState(() => _sort = key);
                    },
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.surface,
                    side: BorderSide.none,
                    labelStyle: TextStyle(
                      color: _sort == key ? Colors.white : AppColors.chipText,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: const StadiumBorder(),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ),
      ),
      body: DramaGrid(
        category: widget.category,
        sort: _sort,
        heroScope: 'browse-${widget.category ?? widget.title}',
      ),
    );
  }
}
