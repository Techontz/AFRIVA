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

  /// Next episodes loaded ahead of time: episode id -> (fetched at, result).
  final _prefetched = <int, (DateTime, PlayResult)>{};
  final _prefetching = <int>{};

  /// Loads an episode's play info ahead of time (no view is recorded), so
  /// moving to it starts the video without waiting for the API.
  Future<void> prefetch(int episodeId) async {
    if (_prefetched.containsKey(episodeId) || !_prefetching.add(episodeId)) return;
    try {
      final res = PlayResult.fromJson(asMap(await _api.get('/episodes/$episodeId/play', query: {'prefetch': 1})));
      if (res.videoUrl != null && res.videoUrl!.isNotEmpty) {
        if (_prefetched.length > 6) _prefetched.clear();
        _prefetched[episodeId] = (DateTime.now(), res);
      }
    } catch (_) {
      // Locked, offline...: the normal play call handles it later.
    } finally {
      _prefetching.remove(episodeId);
    }
  }

  /// Forget prefetched play info (e.g. after the viewer's access changed).
  void clearPrefetched() => _prefetched.clear();

  Future<PlayResult> play(int episodeId) async {
    final hit = _prefetched.remove(episodeId);
    // Signed video links stay valid far longer than this.
    if (hit != null && DateTime.now().difference(hit.$1) < const Duration(minutes: 5)) {
      // Count the view now that it is really watched.
      _api.post('/episodes/$episodeId/view').catchError((_) => null);
      return hit.$2;
    }
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

  Future<void> saveProgress(int episodeId, int seconds) async {
    if (!_api.hasToken) return;
    try {
      await _api.post('/episodes/$episodeId/progress', body: {'progress_seconds': seconds});
    } on ApiException {
      // Progress saving is best-effort.
    }
  }
}
