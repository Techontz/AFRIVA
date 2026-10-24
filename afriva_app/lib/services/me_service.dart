import '../core/api_client.dart';
import '../models/commerce.dart';
import '../models/drama.dart';
import '../models/home.dart';
import '../models/json.dart';
import '../models/user.dart';

class MeService {
  MeService(this._api);
  final ApiClient _api;

  Future<Subscription?> subscription() async {
    final data = await _api.get('/me/subscription');
    final m = asMapOrNull(data);
    if (m == null || m.isEmpty) return null;
    return Subscription.fromJson(m['subscription'] is Map ? asMap(m['subscription']) : m);
  }

  Future<List<Payment>> payments() async =>
      asList(await _api.get('/me/payments'), Payment.fromJson);

  Future<List<HistoryEntry>> history() async =>
      asList(await _api.get('/me/history'), HistoryEntry.fromJson);

  Future<List<Drama>> favorites() async => asList(
        await _api.get('/me/favorites'),
        (j) => Drama.fromJson(j['drama'] is Map ? asMap(j['drama']) : j),
      );

  /// Toggles a favorite. Returns the new state when the API reports it.
  Future<bool?> toggleFavorite(int dramaId) async {
    final data = asMap(await _api.post('/me/favorites/$dramaId'));
    if (data.containsKey('is_favorite')) return asBool(data['is_favorite']);
    if (data.containsKey('favorited')) return asBool(data['favorited']);
    return null;
  }
}
