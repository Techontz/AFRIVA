import 'json.dart';

class Episode {
  const Episode({
    required this.id,
    required this.number,
    this.title = '',
    this.durationSeconds = 0,
    this.thumbnailUrl = '',
    this.isFree = false,
    this.isUnlocked = false,
    this.videoUrl,
  });

  final int id;
  final int number;
  final String title;
  final int durationSeconds;
  final String thumbnailUrl;
  final bool isFree;
  final bool isUnlocked;

  /// Only present from the play endpoint / feed.
  final String? videoUrl;

  bool get isLocked => !isFree && !isUnlocked;

  Episode copyWith({bool? isUnlocked, String? videoUrl}) => Episode(
        id: id,
        number: number,
        title: title,
        durationSeconds: durationSeconds,
        thumbnailUrl: thumbnailUrl,
        isFree: isFree,
        isUnlocked: isUnlocked ?? this.isUnlocked,
        videoUrl: videoUrl ?? this.videoUrl,
      );

  factory Episode.fromJson(Json j) => Episode(
        id: asInt(j['id']),
        number: asInt(j['number']),
        title: asString(j['title']),
        durationSeconds: asInt(j['duration_seconds']),
        thumbnailUrl: asString(j['thumbnail_url']),
        isFree: asBool(j['is_free']),
        isUnlocked: asBool(j['is_unlocked']),
        videoUrl: asStringOrNull(j['video_url']),
      );
}

/// `GET /episodes/{id}/play` success payload.
class PlayResult {
  const PlayResult({
    required this.videoUrl,
    required this.episode,
    this.nextEpisodeId,
    this.prevEpisodeId,
  });

  final String videoUrl;
  final Episode episode;
  final int? nextEpisodeId;
  final int? prevEpisodeId;

  factory PlayResult.fromJson(Json j) => PlayResult(
        videoUrl: asString(j['video_url']),
        episode: Episode.fromJson(asMap(j['episode'])),
        nextEpisodeId: asIntOrNull(j['next_episode_id']),
        prevEpisodeId: asIntOrNull(j['prev_episode_id']),
      );
}

/// The `unlock` object of a 402 `episode_locked` response.
class UnlockInfo {
  const UnlockInfo({
    this.coinsRequired = 0,
    this.userCoins = 0,
    this.canUsePack = false,
    this.episodesRemaining = 0,
    this.requiresLogin = false,
    this.message = 'This episode is locked.',
  });

  final int coinsRequired;
  final int userCoins;
  final bool canUsePack;
  final int episodesRemaining;
  final bool requiresLogin;
  final String message;

  bool get hasEnoughCoins => userCoins >= coinsRequired && coinsRequired > 0;

  factory UnlockInfo.fromJson(Json j, {String? message}) => UnlockInfo(
        coinsRequired: asInt(j['coins_required']),
        userCoins: asInt(j['user_coins']),
        canUsePack: asBool(j['can_use_pack']),
        episodesRemaining: asInt(j['episodes_remaining']),
        requiresLogin: asBool(j['requires_login']),
        message: message ?? 'This episode is locked.',
      );
}
