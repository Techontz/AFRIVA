import 'drama.dart';
import 'episode.dart';
import 'json.dart';

class HomeSection {
  const HomeSection({
    required this.key,
    required this.title,
    required this.layout,
    required this.dramas,
  });

  final String key;
  final String title;

  /// row | ranking | grid
  final String layout;
  final List<Drama> dramas;

  factory HomeSection.fromJson(Json j) => HomeSection(
        key: asString(j['key'], asString(j['title'])),
        title: asString(j['title']),
        layout: asString(j['layout'], 'row'),
        dramas: asList(j['dramas'], Drama.fromJson),
      );
}

class HomeData {
  const HomeData({required this.banners, required this.sections});

  final List<Drama> banners;
  final List<HomeSection> sections;

  factory HomeData.fromJson(Json j) => HomeData(
        banners: asList(j['banners'], Drama.fromJson),
        sections: asList(j['sections'], HomeSection.fromJson)
            .where((s) => s.dramas.isNotEmpty)
            .toList(),
      );
}

/// One For-You feed entry: a drama plus its first episode (with video_url).
class FeedItem {
  const FeedItem({required this.drama, required this.episode});

  final Drama drama;
  final Episode episode;

  factory FeedItem.fromJson(Json j) => FeedItem(
        drama: Drama.fromJson(asMap(j['drama'])),
        episode: Episode.fromJson(asMap(j['episode'])),
      );
}

/// `GET /me/history` entry.
class HistoryEntry {
  const HistoryEntry({
    required this.drama,
    this.episodeNumber = 1,
    this.episodeId,
    this.progressSeconds = 0,
    this.durationSeconds = 0,
    this.updatedAt,
  });

  final Drama drama;
  final int episodeNumber;
  final int? episodeId;
  final int progressSeconds;
  final int durationSeconds;
  final DateTime? updatedAt;

  double get progress =>
      durationSeconds > 0 ? (progressSeconds / durationSeconds).clamp(0, 1).toDouble() : 0;

  factory HistoryEntry.fromJson(Json j) {
    final ep = asMap(j['episode']);
    return HistoryEntry(
      drama: Drama.fromJson(asMap(j['drama'])),
      episodeNumber: asInt(ep['number'] ?? j['episode_number'], 1),
      episodeId: asIntOrNull(ep['id'] ?? j['episode_id']),
      progressSeconds: asInt(j['progress_seconds']),
      durationSeconds: asInt(ep['duration_seconds'] ?? j['duration_seconds']),
      updatedAt: asDate(j['updated_at'] ?? j['watched_at']),
    );
  }
}
