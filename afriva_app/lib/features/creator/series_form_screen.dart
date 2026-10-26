import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../models/drama.dart';
import '../../models/studio.dart';
import '../../services/creator_service.dart';
import '../../services/file_picker_service.dart';
import '../../widgets/buttons.dart';
import '../../widgets/net_image.dart';
import '../../widgets/skeletons.dart';
import '../../widgets/states.dart';

/// Create / edit a series: title, description, genre, cover, trailer, age rating.
/// Publishing rules (date, price, free episodes) are set by AFRIVA, not here.
class SeriesFormScreen extends StatefulWidget {
  const SeriesFormScreen({super.key, this.id});
  final int? id;

  @override
  State<SeriesFormScreen> createState() => _SeriesFormScreenState();
}

class _SeriesFormScreenState extends State<SeriesFormScreen> {
  static const _ratings = ['all', '7+', '13+', '16+', '18+'];

  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _synopsis = TextEditingController();
  final _picker = const FilePickerService();
  List<Category>? _categories;
  final Set<int> _selected = {};
  String? _rating;
  String? _posterUrl;
  bool _hasTrailer = false;
  PickedUpload? _poster;
  PickedUpload? _trailer;
  Object? _loadError;
  ApiException? _error;
  double? _progress;

  bool get _editing => widget.id != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _synopsis.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    final service = context.read<CreatorService>();
    try {
      final cats = await service.categories();
      StudioDrama? existing;
      if (_editing) existing = await service.drama(widget.id!);
      if (!mounted) return;
      setState(() {
        _categories = cats;
        if (existing != null) {
          final d = existing.drama;
          _title.text = d.title;
          _synopsis.text = d.synopsis;
          _selected.addAll(d.categories.map((c) => c.id));
          _rating = d.ageRating;
          _posterUrl = d.posterUrl;
          _hasTrailer = (d.trailerUrl ?? '').isNotEmpty;
        }
      });
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  Future<void> _pickPoster() async {
    final f = await _picker.pickImage();
    if (f != null && mounted) setState(() => _poster = f);
  }

  Future<void> _pickTrailer() async {
    final f = await _picker.pickVideo();
    if (f != null && mounted) setState(() => _trailer = f);
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    if (_selected.isEmpty) {
      showSnack(context, context.tr('Choose at least one genre.'), error: true);
      return;
    }
    setState(() {
      _progress = 0;
      _error = null;
    });
    final router = GoRouter.of(context);
    try {
      final d = await context.read<CreatorService>().saveDrama(
            id: widget.id,
            title: _title.text,
            synopsis: _synopsis.text,
            categoryIds: _selected.toList(),
            ageRating: _rating,
            poster: _poster,
            trailer: _trailer,
            onProgress: (sent, total) {
              if (mounted && total > 0) setState(() => _progress = sent / total);
            },
          );
      if (!mounted) return;
      if (_editing) {
        router.pop(true);
      } else {
        router.pushReplacement('/creator/series/${d.id}');
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _progress = null;
        _error = e;
      });
      if (e.errors.isEmpty) showSnack(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cats = _categories;
    final text = Theme.of(context).textTheme;
    final saving = _progress != null;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr(_editing ? 'Edit series' : 'New series'))),
      body: cats == null
          ? (_loadError != null ? ErrorState(error: _loadError!, onRetry: _load) : const ListSkeleton(count: 4))
          : Form(
              key: _form,
              child: ListView(
                padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.paddingOf(context).bottom + 24),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: saving ? null : _pickPoster,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadii.poster),
                          child: Container(
                            width: 96,
                            height: 128,
                            color: AppColors.surface,
                            child: _poster != null
                                ? Center(child: Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: Text(_poster!.name, textAlign: TextAlign.center, style: text.labelSmall),
                                  ))
                                : (_posterUrl ?? '').isNotEmpty
                                    ? NetImage(_posterUrl, memCacheWidth: 200)
                                    : Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.add_photo_alternate_outlined, color: AppColors.textMuted),
                                          Text(context.tr('Cover'), style: text.labelSmall),
                                        ],
                                      ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(context.tr('Cover (vertical 3:4)'), style: text.titleSmall),
                            if (_error?.fieldError('poster') != null)
                              Text(_error!.fieldError('poster')!, style: text.bodySmall!.copyWith(color: AppColors.danger)),
                            const SizedBox(height: 8),
                            PillButton(
                              label: context.tr(_poster == null ? 'Choose cover' : 'Change cover'),
                              icon: Icons.image_outlined,
                              secondary: true,
                              height: 38,
                              onPressed: saving ? null : _pickPoster,
                            ),
                            const SizedBox(height: 8),
                            PillButton(
                              label: _trailer != null
                                  ? _trailer!.name
                                  : context.tr(_hasTrailer ? 'Replace trailer' : 'Add trailer'),
                              icon: Icons.movie_creation_outlined,
                              secondary: true,
                              height: 38,
                              onPressed: saving ? null : _pickTrailer,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _title,
                    decoration: InputDecoration(labelText: context.tr('Series title'), errorText: _error?.fieldError('title')),
                    validator: (v) => (v ?? '').trim().isEmpty ? context.tr('Enter a title') : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _synopsis,
                    minLines: 4,
                    maxLines: 8,
                    decoration: InputDecoration(labelText: context.tr('Description'), errorText: _error?.fieldError('synopsis')),
                    validator: (v) => (v ?? '').trim().isEmpty ? context.tr('Describe the story') : null,
                  ),
                  const SizedBox(height: 16),
                  Text(context.tr('Genre'), style: text.titleSmall),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in cats)
                        FilterChip(
                          label: Text(c.name),
                          selected: _selected.contains(c.id),
                          onSelected: (on) => setState(() => on ? _selected.add(c.id) : _selected.remove(c.id)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(context.tr('Age rating'), style: text.titleSmall),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final r in _ratings)
                        ChoiceChip(
                          label: Text(r == 'all' ? context.tr('All ages') : r),
                          selected: _rating == r,
                          onSelected: (_) => setState(() => _rating = r),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.tr('AFRIVA sets the publishing date, coin price and free episodes after approval.'),
                    style: text.bodySmall,
                  ),
                  const SizedBox(height: 20),
                  if (saving) ...[
                    LinearProgressIndicator(value: _progress, color: AppColors.primary),
                    const SizedBox(height: 6),
                    Text(context.tr('Uploading {n}%', {'n': ((_progress ?? 0) * 100).round()}), style: text.labelSmall),
                    const SizedBox(height: 12),
                  ],
                  PillButton(
                    label: context.tr(_editing ? 'Save changes' : 'Create series'),
                    icon: Icons.check_rounded,
                    expand: true,
                    loading: saving,
                    onPressed: saving ? null : _save,
                  ),
                ],
              ),
            ),
    );
  }
}
