import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/haptics.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../models/drama.dart';
import '../../services/catalog_service.dart';
import '../../state/settings_state.dart';
import '../../widgets/poster_card.dart';
import '../../widgets/skeletons.dart';
import '../home/drama_grid.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.embedded = false});

  /// True when shown as the "Tafuta" tab: no autofocus (the keyboard would pop up on every tab switch).
  final bool embedded;

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
          child: Hero(
            tag: 'search-field-tab',
            child: Material(
              type: MaterialType.transparency,
              child: SizedBox(
                height: 42,
                child: TextField(
                  controller: _controller,
                  autofocus: !widget.embedded,
                  textInputAction: TextInputAction.search,
                  onChanged: _onChanged,
                  onSubmitted: _submit,
                  style: Theme.of(context).textTheme.bodyLarge!.copyWith(fontSize: 15),
                  decoration: InputDecoration(
                    hintText: context.tr('Search titles, tags, studios'),
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
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.paddingOf(context).bottom + 24),
      children: [
        if (settings.recentSearches.isNotEmpty) ...[
          Row(
            children: [
              Expanded(child: Text(context.tr('Recent searches'), style: text.titleSmall)),
              TextButton(
                onPressed: settings.clearRecentSearches,
                child: Text(context.tr('Clear')),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final q in settings.recentSearches)
                ActionChip(
                  avatar: const Icon(Icons.history_rounded, size: 16, color: AppColors.textDim),
                  label: Text(q),
                  onPressed: () => onPick(q),
                  backgroundColor: AppColors.surface,
                  side: BorderSide.none,
                  shape: const StadiumBorder(),
                  labelStyle: const TextStyle(color: AppColors.chipText, fontWeight: FontWeight.w600),
                ),
            ],
          ),
          const SizedBox(height: 18),
        ],
        Text(context.tr('Trending now'), style: text.titleSmall),
        const SizedBox(height: 6),
        FutureBuilder<List<Drama>>(
          future: trending,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const SizedBox(height: 400, child: ListSkeleton(count: 4, thumbWidth: 72));
            }
            final items = snap.data ?? const [];
            if (items.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(context.tr('Type to search the Afriva catalog.'), style: text.bodyMedium),
              );
            }
            return Column(
              children: [
                for (var i = 0; i < items.length && i < 10; i++)
                  RankingTile(rank: i + 1, drama: items[i], heroScope: 'search-trending'),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Convenience to open search from anywhere.
void openSearch(BuildContext context) => context.go('/search');
