import '../core/i18n.dart';
import 'drama.dart';
import 'episode.dart';
import 'json.dart';

/// Review states of creator work (scope §04) with their Kiswahili labels.
class ReviewStatus {
  ReviewStatus._();

  static const draft = 'draft';
  static const submitted = 'submitted';
  static const inReview = 'in_review';
  static const changesRequested = 'changes_requested';
  static const approved = 'approved';
  static const rejected = 'rejected';

  /// Creators may only edit work that is still a draft or was sent back.
  static bool isEditable(String? s) => s == null || s == draft || s == changesRequested;

  static String label(String? s) => switch (s) {
        submitted => trNow('Submitted'),
        inReview => trNow('In review'),
        changesRequested => trNow('Changes requested'),
        approved => trNow('Approved'),
        rejected => trNow('Rejected'),
        _ => trNow('Draft'),
      };
}

/// One entry of a series' review history.
class ContentReview {
  const ContentReview({
    required this.id,
    required this.action,
    this.episodeNumber,
    this.notes,
    this.userName,
    this.createdAt,
  });

  final int id;

  /// submitted | resubmitted | review_started | playback_verified | approve | request_changes | reject | published | scheduled | unpublished
  final String action;
  final int? episodeNumber;
  final String? notes;
  final String? userName;
  final DateTime? createdAt;

  String get label => switch (action) {
        'submitted' => trNow('Sent for review'),
        'resubmitted' => trNow('Sent again after changes'),
        'review_started' => trNow('Review started'),
        'playback_verified' => trNow('Playback checked'),
        'approve' => trNow('Approved'),
        'request_changes' => trNow('Changes requested'),
        'reject' => trNow('Rejected'),
        'published' => trNow('Published'),
        'scheduled' => trNow('Scheduled for publishing'),
        'unpublished' => trNow('Unpublished'),
        _ => action,
      };

  factory ContentReview.fromJson(Json j) => ContentReview(
        id: asInt(j['id']),
        action: asString(j['action']),
        episodeNumber: asIntOrNull(j['episode_number']),
        notes: asStringOrNull(j['notes']),
        userName: asMapOrNull(j['user']) == null ? null : asStringOrNull(asMap(j['user'])['name']),
        createdAt: asDate(j['created_at']),
      );
}

/// `GET /studio/dramas/{id}`: the creator's series with all episodes and review history.
class StudioDrama {
  const StudioDrama({required this.drama, required this.episodes, required this.reviews});

  final Drama drama;
  final List<Episode> episodes;
  final List<ContentReview> reviews;

  bool get editable => ReviewStatus.isEditable(drama.reviewStatus);

  /// Episodes that would be sent with the next submission.
  List<Episode> get pendingEpisodes => episodes.where((e) => ReviewStatus.isEditable(e.reviewStatus)).toList();

  bool get canSubmit {
    final s = drama.reviewStatus;
    if (s == ReviewStatus.submitted || s == ReviewStatus.inReview || s == ReviewStatus.rejected) return false;
    return pendingEpisodes.isNotEmpty;
  }

  factory StudioDrama.fromJson(Json j) {
    final episodes = asList(j['episodes'], Episode.fromJson)..sort((a, b) => a.number.compareTo(b.number));
    return StudioDrama(
      drama: Drama.fromJson(j),
      episodes: episodes,
      reviews: asList(j['reviews'], ContentReview.fromJson),
    );
  }
}

/// `GET /studio/agreement`
class CreatorAgreement {
  const CreatorAgreement({
    required this.version,
    required this.text,
    this.accepted = false,
    this.acceptedAt,
    this.revenueSharePercent = 0,
    this.companyStatus = 'pending',
  });

  final String version;
  final String text;
  final bool accepted;
  final DateTime? acceptedAt;
  final double revenueSharePercent;

  /// pending | active | suspended
  final String companyStatus;

  bool get creatorApproved => companyStatus == 'active';

  factory CreatorAgreement.fromJson(Json j) => CreatorAgreement(
        version: asString(j['version']),
        text: asString(j['text']),
        accepted: asBool(j['accepted']),
        acceptedAt: asDate(j['accepted_at']),
        revenueSharePercent: double.tryParse(asString(j['revenue_share_percent'], '0')) ?? 0,
        companyStatus: asString(j['company_status'], 'pending'),
      );
}

/// A file picked on the device for upload.
class PickedUpload {
  const PickedUpload({required this.path, required this.name, this.size = 0});

  final String path;
  final String name;
  final int size;
}
