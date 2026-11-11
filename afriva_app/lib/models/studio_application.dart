import 'json.dart';

/// Formats a percentage from the API without a trailing ".0"
/// (60 -> "60", 60.0 -> "60", 62.5 -> "62.5", 33.333 -> "33.33").
String formatPercent(num value) {
  if (value == value.roundToDouble()) return value.round().toString();
  var s = value.toStringAsFixed(2);
  s = s.replaceFirst(RegExp(r'0+$'), '');
  return s.endsWith('.') ? s.substring(0, s.length - 1) : s;
}

num _asNum(Object? v) {
  if (v is num) return v;
  if (v is String) return num.tryParse(v) ?? 0;
  return 0;
}

/// Revenue split from `GET /creator-guidelines` (never hard-coded).
class RevenueSplit {
  const RevenueSplit({required this.creatorPercent, required this.platformPercent});

  final num creatorPercent;
  final num platformPercent;

  String get creatorLabel => formatPercent(creatorPercent);
  String get platformLabel => formatPercent(platformPercent);

  factory RevenueSplit.fromJson(Json j) => RevenueSplit(
        creatorPercent: _asNum(j['creator_percent']),
        platformPercent: _asNum(j['platform_percent']),
      );
}

class StudioSample {
  const StudioSample({
    required this.id,
    this.title = '',
    this.status = 'uploading',
    this.durationSeconds,
    this.lengthCheck,
    this.valid = false,
  });

  final int id;
  final String title;

  /// uploading | processing | ready | failed
  final String status;
  final int? durationSeconds;

  /// ok | too_short | too_long | null
  final String? lengthCheck;
  final bool valid;

  factory StudioSample.fromJson(Json j) => StudioSample(
        id: asInt(j['id']),
        title: asString(j['title']),
        status: asString(j['status'], 'uploading'),
        durationSeconds: asIntOrNull(j['duration_seconds']),
        lengthCheck: asStringOrNull(j['length_check']),
        valid: asBool(j['valid']),
      );
}

class SamplesSummary {
  const SamplesSummary({this.required = 10, this.uploaded = 0, this.valid = 0});

  final int required;
  final int uploaded;
  final int valid;

  factory SamplesSummary.fromJson(Json j) => SamplesSummary(
        required: asInt(j['required'], 10),
        uploaded: asInt(j['uploaded']),
        valid: asInt(j['valid']),
      );
}

/// `GET /me/studio-application` payload.
class StudioApplication {
  const StudioApplication({
    this.status = 'pending',
    this.reviewStatus = 'pending',
    this.rejectionReason,
    this.companyName = '',
    this.samples = const [],
    this.summary = const SamplesSummary(),
    this.revenueSplit,
    this.createdAt,
    this.reviewedAt,
  });

  /// pending | approved | rejected
  final String status;

  /// pending | ready_for_review | approved | rejected
  final String reviewStatus;
  final String? rejectionReason;
  final String companyName;
  final List<StudioSample> samples;
  final SamplesSummary summary;
  final RevenueSplit? revenueSplit;
  final DateTime? createdAt;
  final DateTime? reviewedAt;

  /// Review state used for display, falling back to the account status.
  String get effectiveStatus {
    if (status == 'approved' || status == 'rejected') return status;
    return reviewStatus.isEmpty ? status : reviewStatus;
  }

  factory StudioApplication.fromJson(Json j) => StudioApplication(
        status: asString(j['status'], 'pending'),
        reviewStatus: asString(j['review_status'], 'pending'),
        rejectionReason: asStringOrNull(j['rejection_reason']),
        companyName: asString(asMap(j['company'])['name']),
        samples: asList(j['samples'], StudioSample.fromJson),
        summary: SamplesSummary.fromJson(asMap(j['samples_summary'])),
        revenueSplit:
            asMapOrNull(j['revenue_split']) == null ? null : RevenueSplit.fromJson(asMap(j['revenue_split'])),
        createdAt: asDate(j['created_at']),
        reviewedAt: asDate(j['reviewed_at']),
      );
}

/// Result of `POST /auth/studio-application`.
class StudioApplyResult {
  const StudioApplyResult({this.status = 'pending', this.existingUser = false, this.message});

  final String status;
  final bool existingUser;
  final String? message;
}
