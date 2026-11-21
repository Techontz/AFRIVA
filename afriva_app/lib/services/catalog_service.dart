import '../core/api_client.dart';
import '../core/disk_cache.dart';
import '../l10n/l10n.dart';
import '../models/drama.dart';
import '../models/home.dart';
import '../models/json.dart';

class CatalogService {
  CatalogService(this._api);
  final ApiClient _api;

  Future<HomeData>? _homeInFlight;
  DateTime? _homeStarted;

  /// Home feed. A request started moments ago (e.g. by [prefetchHome] on the
  /// splash screen) is reused instead of sending a second one.
  Future<HomeData> home() {
    final started = _homeStarted;
    final inFlight = _homeInFlight;
    if (inFlight != null && started != null && DateTime.now().difference(started) < const Duration(seconds: 20)) {
      _homeInFlight = null;
      return inFlight;
    }
    return _fetchHome();
  }

  Future<HomeData> _fetchHome() async {
    final raw = await _api.get('/home');
    DiskCache.write('home.${L10n.code}', raw);
    return HomeData.fromJson(asMap(raw));
  }

  /// Starts loading the home feed early (while the splash shows).
  void prefetchHome() {
    _homeStarted = DateTime.now();
    final f = _fetchHome();
    _homeInFlight = f;
    // A failed prefetch must not be reused (this listener also keeps its error handled).
    f.then((_) {}, onError: (_) {
      if (identical(_homeInFlight, f)) _homeInFlight = null;
    });
  }

  /// The home feed saved on the device by the last successful load.
  HomeData? cachedHome() {
    final raw = DiskCache.read('home.${L10n.code}');
    if (raw == null) return null;
    try {
      return HomeData.fromJson(asMap(raw));
    } catch (_) {
      return null;
    }
  }

  Future<List<Category>> categories() async {
    final raw = await _api.get('/categories');
    DiskCache.write('categories.${L10n.code}', raw);
    return asList(raw, Category.fromJson);
  }

  List<Category>? cachedCategories() {
    final raw = DiskCache.read('categories.${L10n.code}');
    if (raw is! List) return null;
    try {
      return asList(raw, Category.fromJson);
    } catch (_) {
      return null;
    }
  }

  Future<Paginated<Drama>> dramas({
    String? category,
    String? q,
    String sort = 'popular',
    int page = 1,
    int perPage = 18,
  }) async {
    final body = await _api.getJson('/dramas', query: {
      'category': category,
      'q': q,
      'sort': sort,
      'page': page,
      'per_page': perPage,
    });
    final meta = asMap(body['meta']);
    return Paginated(
      items: asList(body['data'], Drama.fromJson),
      currentPage: asInt(meta['current_page'], page),
      lastPage: asInt(meta['last_page'], page),
      total: asInt(meta['total']),
    );
  }

  Future<List<Drama>> rankings({String type = 'trending'}) async =>
      asList(await _api.get('/dramas/rankings', query: {'type': type}), Drama.fromJson);

  final _detailCache = <String, (DateTime, DramaDetail)>{};

  /// A non-zero [maxAge] reuses a detail fetched moments ago (detail → player)
  /// instead of requesting it again.
  Future<DramaDetail> drama(String slug, {Duration maxAge = Duration.zero}) async {
    final hit = _detailCache[slug];
    if (hit != null && DateTime.now().difference(hit.$1) < maxAge) return hit.$2;
    final d = DramaDetail.fromJson(asMap(await _api.get('/dramas/$slug')));
    if (_detailCache.length > 30) _detailCache.clear();
    _detailCache[slug] = (DateTime.now(), d);
    return d;
  }

  /// Items whose episode has no `video_url` yet stay in the feed and render a
  /// "Coming soon" state instead of a player.
  Future<List<FeedItem>> feed() async => asList(await _api.get('/feed'), FeedItem.fromJson);
}
