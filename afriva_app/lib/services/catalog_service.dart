import '../core/api_client.dart';
import '../models/drama.dart';
import '../models/home.dart';
import '../models/json.dart';

class CatalogService {
  CatalogService(this._api);
  final ApiClient _api;

  Future<HomeData> home() async => HomeData.fromJson(asMap(await _api.get('/home')));

  Future<List<Category>> categories() async =>
      asList(await _api.get('/categories'), Category.fromJson);

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
