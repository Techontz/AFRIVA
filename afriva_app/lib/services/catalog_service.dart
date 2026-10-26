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

  Future<DramaDetail> drama(String slug) async =>
      DramaDetail.fromJson(asMap(await _api.get('/dramas/$slug')));

  /// "Ripoti": copyright / content problem with a series. [reason]: copyright | inappropriate | misleading | other.
  Future<String> report(int dramaId, {required String reason, String? details, String? contact}) async {
    final data = asMap(await _api.post('/dramas/$dramaId/report', body: {
      'reason': reason,
      if (details != null && details.trim().isNotEmpty) 'details': details.trim(),
      if (contact != null && contact.trim().isNotEmpty) 'contact': contact.trim(),
    }));
    return asString(data['message']);
  }

  Future<List<FeedItem>> feed() async => asList(await _api.get('/feed'), FeedItem.fromJson)
      .where((f) => (f.episode.videoUrl ?? '').isNotEmpty)
      .toList();
}
