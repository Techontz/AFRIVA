import '../core/api_client.dart';
import '../models/episode.dart';
import '../models/json.dart';

/// Thrown by [PlayerService.play] when the API answers 402 `episode_locked`.
class EpisodeLockedException implements Exception {
  EpisodeLockedException(this.info);
  final UnlockInfo info;
}

class PlayerService {
  PlayerService(this._api);
  final ApiClient _api;

  Future<PlayResult> play(int episodeId) async {
    try {
      return PlayResult.fromJson(asMap(await _api.get('/episodes/$episodeId/play')));
    } on ApiException catch (e) {
      if (e.isEpisodeLocked) {
        throw EpisodeLockedException(
          UnlockInfo.fromJson(asMap(e.body['unlock']), message: e.message),
        );
      }
      rethrow;
    }
  }

  /// [method] is `coins` or `episode_pack`. Returns the raw `data` payload.
  Future<Json> unlock(int episodeId, String method) async =>
      asMap(await _api.post('/episodes/$episodeId/unlock', body: {'method': method}));

  /// Player analytics (SPEC §8.3). Best-effort: never throws.
  Future<void> sendEvents(List<Json> events) async {
    if (events.isEmpty) return;
    try {
      await _api.post('/events', body: {'events': events});
    } on ApiException {
      // Analytics must never interrupt playback.
    }
  }

  Future<void> saveProgress(int episodeId, int seconds) async {
    if (!_api.hasToken) return;
    try {
      await _api.post('/episodes/$episodeId/progress', body: {'progress_seconds': seconds});
    } on ApiException {
      // Progress saving is best-effort.
    }
  }
}
