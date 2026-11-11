import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/haptics.dart';
import '../../core/theme.dart';
import '../../l10n/l10n.dart';
import '../../models/drama.dart';
import '../../services/catalog_service.dart';
import '../../state/settings_state.dart';
import '../../widgets/calm.dart';
import '../../widgets/poster_card.dart';
import '../../widgets/skeletons.dart';
import '../../widgets/states.dart';
import '../home/drama_grid.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  late final Future<List<Drama>> _trending =
      context.read<CatalogService>().rankings(type: 'trending').catchError((_) => <Drama>[]);

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _query = v.trim());
    });
  }

  void _submit(String v) {
    _debounce?.cancel();
    final q = v.trim();
    if (q.isEmpty) return;
    context.read<SettingsState>().addRecentSearch(q);
    setState(() => _query = q);
  }

  void _useSuggestion(String q) {
    Haptics.tap();
    _controller.text = q;
    _controller.selection = TextSelection.collapsed(offset: q.length);
    _submit(q);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Material(
              type: MaterialType.transparency,
              child: SizedBox(
                height: 42,
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onChanged: _onChanged,
                  onSubmitted: _submit,
                  style: Theme.of(context).textTheme.bodyLarge!.copyWith(fontSize: 15),
                  decoration: InputDecoration(
                    hintText: context.l10n.searchFieldHint,
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                    suffixIcon: ValueListenableBuilder(
                      valueListenable: _controller,
                      builder: (_, v, _) => v.text.isEmpty
                          ? const SizedBox.shrink()
                          : IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () {
                                _controller.clear();
                                setState(() => _query = '');
                              },
                            ),
                    ),
                  ),
                ),
              ),
            ),
        ),
      ),
      body: AnimatedSwitcher(
        duration: AppMotion.normal,
        child: _query.isEmpty
            ? _Suggestions(trending: _trending, onPick: _useSuggestion)
            : DramaGrid(key: ValueKey(_query), query: _query, heroScope: 'search'),
      ),
    );
  }
}

class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.trending, required this.onPick});
  final Future<List<Drama>> trending;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsState>();
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    return ListView(
      padding: EdgeInsets.fromLTRB(0, 8, 0, MediaQuery.paddingOf(context).bottom + 24),
      children: [
        if (settings.recentSearches.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(child: Text(l.searchRecent, style: text.titleSmall)),
                TextButton(
                  onPressed: settings.clearRecentSearches,
                  child: Text(l.actionClear),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final q in settings.recentSearches)
                  CalmChip(label: q, selected: false, onTap: () => onPick(q)),
              ],
            ),
          ),
        ],
        SectionHeader(
          title: l.searchTrendingNow,
          onMore: () {
            Haptics.tap();
            context.push('/rankings');
          },
        ),
        FutureBuilder<List<Drama>>(
          future: trending,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Skeleton(child: ShelfSkeleton());
            }
            final items = snap.data ?? const [];
            if (items.isEmpty) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Text(l.searchTypeToSearch, style: text.bodyMedium),
              );
            }
            return PosterShelf(dramas: items, heroScope: 'search-trending');
          },
        ),
      ],
    );
  }
}

/// Convenience to open search from anywhere.
void openSearch(BuildContext context) => context.push('/search');
