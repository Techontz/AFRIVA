import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../../widgets/calm.dart';
import 'drama_grid.dart';

/// Full grid for a home section / category with Popular / Newest sort.
class BrowseScreen extends StatefulWidget {
  const BrowseScreen({super.key, this.title, this.category, this.sort = 'popular'});

  final String? title;
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
        title: Text(widget.title ?? context.l10n.browseTitle),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                for (final (key, label) in [
                  ('popular', context.l10n.sortPopular),
                  ('newest', context.l10n.sortNewest),
                ]) ...[
                  CalmChip(
                    label: label,
                    selected: _sort == key,
                    onTap: () => setState(() => _sort = key),
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
        heroScope: 'browse-${widget.category ?? widget.title ?? ''}',
      ),
    );
  }
}
