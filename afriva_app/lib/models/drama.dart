import 'episode.dart';
import 'json.dart';

class Category {
  const Category({required this.id, required this.name, required this.slug});

  final int id;
  final String name;
  final String slug;

  factory Category.fromJson(Json j) => Category(
        id: asInt(j['id']),
        name: asString(j['name']),
        slug: asString(j['slug']),
      );
}

class Company {
  const Company({required this.id, required this.name, required this.slug});

  final int id;
  final String name;
  final String slug;

  factory Company.fromJson(Json j) => Company(
        id: asInt(j['id']),
        name: asString(j['name']),
        slug: asString(j['slug']),
      );
}

class Drama {
  const Drama({
    required this.id,
    required this.slug,
    required this.title,
    this.synopsis = '',
    this.posterUrl = '',
    this.backdropUrl = '',
    this.totalEpisodes = 0,
    this.freeEpisodes = 0,
    this.coinsPerEpisode = 0,
    this.badge,
    this.views = 0,
    this.categories = const [],
    this.tags = const [],
    this.company,
    this.isFavorite = false,
    this.trailerUrl,
    this.ageRating,
    this.accessMode = 'coins_or_vip',
    this.totalDurationSeconds = 0,
    this.resume,
    this.status,
    this.reviewStatus,
    this.reviewNotes,
    this.isLive = false,
    this.language,
  });

  final int id;
  final String slug;
  final String title;
  final String synopsis;
  final String posterUrl;
  final String backdropUrl;
  final int totalEpisodes;
  final int freeEpisodes;
  final int coinsPerEpisode;

  /// `hot` | `new` | `vip` | null
  final String? badge;
  final int views;
  final List<Category> categories;
  final List<String> tags;
  final Company? company;
  final bool isFavorite;

  /// Playable trailer (signed URL when uploaded).
  final String? trailerUrl;

  /// all | 7+ | 13+ | 16+ | 18+
  final String? ageRating;

  /// coins_or_vip | vip_only | coins_only
  final String accessMode;

  /// Sum of episode durations (detail endpoint only).
  final int totalDurationSeconds;

  /// "Endelea kutazama" position (home `continue_watching` section only).
  final ResumeInfo? resume;

  // Creator Studio only.
  final String? status;
  final String? reviewStatus;
  final String? reviewNotes;
  final bool isLive;
  final String? language;

  bool get isVipOnly => accessMode == 'vip_only';

  /// Up to two short genre labels for cards.
  List<String> get chips {
    final out = <String>[...categories.map((c) => c.name), ...tags];
    return out.take(2).toList();
  }

  String get backdropOrPoster => backdropUrl.isNotEmpty ? backdropUrl : posterUrl;

  Drama copyWith({bool? isFavorite}) => Drama(
        trailerUrl: trailerUrl,
        ageRating: ageRating,
        accessMode: accessMode,
        totalDurationSeconds: totalDurationSeconds,
        resume: resume,
        status: status,
        reviewStatus: reviewStatus,
        reviewNotes: reviewNotes,
        isLive: isLive,
        language: language,
        id: id,
        slug: slug,
        title: title,
        synopsis: synopsis,
        posterUrl: posterUrl,
        backdropUrl: backdropUrl,
        totalEpisodes: totalEpisodes,
        freeEpisodes: freeEpisodes,
        coinsPerEpisode: coinsPerEpisode,
        badge: badge,
        views: views,
        categories: categories,
        tags: tags,
        company: company,
        isFavorite: isFavorite ?? this.isFavorite,
      );

  factory Drama.fromJson(Json j) => Drama(
        id: asInt(j['id']),
        slug: asString(j['slug']),
        title: asString(j['title']),
        synopsis: asString(j['synopsis']),
        posterUrl: asString(j['poster_url']),
        backdropUrl: asString(j['backdrop_url']),
        totalEpisodes: asInt(j['total_episodes'] ?? j['episodes_count']),
        freeEpisodes: asInt(j['free_episodes']),
        coinsPerEpisode: asInt(j['coins_per_episode']),
        badge: asStringOrNull(j['badge'])?.toLowerCase(),
        views: asInt(j['views']),
        categories: asList(j['categories'], Category.fromJson),
        tags: asStringList(j['tags']),
        company: asMapOrNull(j['company']) == null ? null : Company.fromJson(asMap(j['company'])),
        isFavorite: asBool(j['is_favorite']),
        trailerUrl: asStringOrNull(j['trailer_url']),
        ageRating: asStringOrNull(j['age_rating']),
        accessMode: asString(j['access_mode'], 'coins_or_vip'),
        totalDurationSeconds: asInt(j['total_duration_seconds']),
        resume: asMapOrNull(j['resume']) == null ? null : ResumeInfo.fromJson(asMap(j['resume'])),
        status: asStringOrNull(j['status']),
        reviewStatus: asStringOrNull(j['review_status']),
        reviewNotes: asStringOrNull(j['review_notes']),
        isLive: asBool(j['is_live']),
        language: asStringOrNull(j['language']),
      );
}

/// Where to continue a series: episode number + position in that episode.
class ResumeInfo {
  const ResumeInfo({required this.episodeNumber, this.episodeId, this.progressSeconds = 0, this.durationSeconds = 0});

  final int? episodeId;
  final int episodeNumber;
  final int progressSeconds;
  final int durationSeconds;

  double get progress =>
      durationSeconds > 0 ? (progressSeconds / durationSeconds).clamp(0, 1).toDouble() : 0;

  factory ResumeInfo.fromJson(Json j) => ResumeInfo(
        episodeId: asIntOrNull(j['episode_id']),
        episodeNumber: asInt(j['episode_number'], 1),
        progressSeconds: asInt(j['progress_seconds']),
        durationSeconds: asInt(j['duration_seconds']),
      );
}

/// `GET /dramas/{slug}` → Drama + episodes + related.
class DramaDetail {
  const DramaDetail({required this.drama, required this.episodes, required this.related});

  final Drama drama;
  final List<Episode> episodes;
  final List<Drama> related;

  int indexOfNumber(int number) {
    final i = episodes.indexWhere((e) => e.number == number);
    return i < 0 ? 0 : i;
  }

  factory DramaDetail.fromJson(Json j) {
    final episodes = asList(j['episodes'], Episode.fromJson)
      ..sort((a, b) => a.number.compareTo(b.number));
    return DramaDetail(
      drama: Drama.fromJson(j),
      episodes: episodes,
      related: asList(j['related'], Drama.fromJson),
    );
  }
}

class Paginated<T> {
  const Paginated({
    required this.items,
    this.currentPage = 1,
    this.lastPage = 1,
    this.total = 0,
  });

  final List<T> items;
  final int currentPage;
  final int lastPage;
  final int total;

  bool get hasMore => currentPage < lastPage;
}
