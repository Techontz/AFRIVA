import '../core/i18n.dart';
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
    this.access = '',
    this.priceCoins = 0,
    this.vipOnly = false,
    this.subtitleUrl,
    this.videoUrl,
    this.reviewStatus,
    this.reviewNotes,
    this.videoStatus,
    this.videoError,
    this.playbackVerified = false,
  });

  final int id;
  final int number;
  final String title;
  final int durationSeconds;
  final String thumbnailUrl;
  final bool isFree;
  final bool isUnlocked;

  /// free | unlocked | locked (SPEC §8.2). Empty for older payloads.
  final String access;

  /// Coins needed to unlock (0 when free or VIP-only).
  final int priceCoins;
  final bool vipOnly;
  final String? subtitleUrl;

  /// Only present from the play endpoint / feed / studio.
  final String? videoUrl;

  // Creator Studio only.
  final String? reviewStatus;
  final String? reviewNotes;

  /// uploaded | processing | ready | failed
  final String? videoStatus;
  final String? videoError;
  final bool playbackVerified;

  bool get isLocked => access.isNotEmpty ? access == 'locked' : !isFree && !isUnlocked;

  Episode copyWith({bool? isUnlocked, String? videoUrl}) => Episode(
        id: id,
        number: number,
        title: title,
        durationSeconds: durationSeconds,
        thumbnailUrl: thumbnailUrl,
        isFree: isFree,
        isUnlocked: isUnlocked ?? this.isUnlocked,
        access: isUnlocked == true && access == 'locked' ? 'unlocked' : access,
        priceCoins: priceCoins,
        vipOnly: vipOnly,
        subtitleUrl: subtitleUrl,
        videoUrl: videoUrl ?? this.videoUrl,
        reviewStatus: reviewStatus,
        reviewNotes: reviewNotes,
        videoStatus: videoStatus,
        videoError: videoError,
        playbackVerified: playbackVerified,
      );

  factory Episode.fromJson(Json j) => Episode(
        id: asInt(j['id']),
        number: asInt(j['number']),
        title: asString(j['title']),
        durationSeconds: asInt(j['duration_seconds']),
        thumbnailUrl: asString(j['thumbnail_url']),
        isFree: asBool(j['is_free']),
        isUnlocked: asBool(j['is_unlocked']),
        access: asString(j['access']),
        priceCoins: asInt(j['price_coins']),
        vipOnly: asBool(j['vip_only']),
        subtitleUrl: asStringOrNull(j['subtitle_url']),
        videoUrl: asStringOrNull(j['video_url']),
        reviewStatus: asStringOrNull(j['review_status']),
        reviewNotes: asStringOrNull(j['review_notes']),
        videoStatus: asStringOrNull(j['video_status']),
        videoError: asStringOrNull(j['video_error']),
        playbackVerified: j['playback_verified_at'] != null,
      );
}

/// One playable source for the quality picker: "auto" (adaptive HLS) or a fixed rendition.
class VideoSource {
  const VideoSource({required this.quality, required this.label, required this.url, this.type = 'mp4'});

  /// auto | 480p | 720p | 1080p
  final String quality;
  final String label;
  final String url;

  /// hls | mp4
  final String type;

  bool get isAuto => quality == 'auto';

  factory VideoSource.fromJson(Json j) => VideoSource(
        quality: asString(j['quality'], 'auto'),
        label: asString(j['label'], asString(j['quality'], 'Auto')),
        url: asString(j['url']),
        type: asString(j['type'], 'mp4'),
      );
}

/// `GET /episodes/{id}/play` success payload.
class PlayResult {
  const PlayResult({
    required this.videoUrl,
    required this.episode,
    this.sources = const [],
    this.subtitleUrl,
    this.resumeSeconds = 0,
    this.sessionId = '',
    this.nextEpisodeId,
    this.prevEpisodeId,
  });

  final String videoUrl;
  final Episode episode;
  final List<VideoSource> sources;
  final String? subtitleUrl;

  /// Where this viewer stopped last time in this episode (0 = start).
  final int resumeSeconds;

  /// Sent back with analytics events (POST /events).
  final String sessionId;
  final int? nextEpisodeId;
  final int? prevEpisodeId;

  /// Sources with a usable URL; falls back to [videoUrl] as "Auto".
  List<VideoSource> get playable {
    final s = sources.where((e) => e.url.isNotEmpty).toList();
    if (s.isNotEmpty) return s;
    return [VideoSource(quality: 'auto', label: 'Auto', url: videoUrl)];
  }

  factory PlayResult.fromJson(Json j) => PlayResult(
        videoUrl: asString(j['video_url']),
        episode: Episode.fromJson(asMap(j['episode'])),
        sources: asList(j['sources'], VideoSource.fromJson),
        subtitleUrl: asStringOrNull(j['subtitle_url']),
        resumeSeconds: asInt(j['resume_seconds']),
        sessionId: asString(j['session_id']),
        nextEpisodeId: asIntOrNull(j['next_episode_id']),
        prevEpisodeId: asIntOrNull(j['prev_episode_id']),
      );
}

/// The `unlock` object of a 402 `episode_locked` / `vip_required` response.
class UnlockInfo {
  const UnlockInfo({
    this.coinsRequired = 0,
    this.userCoins = 0,
    this.canUsePack = false,
    this.canUseCoins = true,
    this.canUseVip = true,
    this.vipOnly = false,
    this.episodesRemaining = 0,
    this.requiresLogin = false,
    this.message = 'This episode is locked.',
  });

  final int coinsRequired;
  final int userCoins;
  final bool canUsePack;
  final bool canUseCoins;
  final bool canUseVip;

  /// Series that only VIP members can watch (coins cannot unlock it).
  final bool vipOnly;
  final int episodesRemaining;
  final bool requiresLogin;
  final String message;

  bool get hasEnoughCoins => userCoins >= coinsRequired && coinsRequired > 0;

  factory UnlockInfo.fromJson(Json j, {String? message}) => UnlockInfo(
        coinsRequired: asInt(j['coins_required']),
        userCoins: asInt(j['user_coins']),
        canUsePack: asBool(j['can_use_pack']),
        canUseCoins: asBool(j['can_use_coins'], !asBool(j['vip_only'])),
        canUseVip: asBool(j['can_use_vip'], true),
        vipOnly: asBool(j['vip_only']),
        episodesRemaining: asInt(j['episodes_remaining']),
        requiresLogin: asBool(j['requires_login']),
        message: message ?? trNow('This episode is locked.'),
      );
}
