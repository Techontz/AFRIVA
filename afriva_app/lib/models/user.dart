import 'commerce.dart';
import 'drama.dart';
import 'json.dart';

class Subscription {
  const Subscription({
    required this.id,
    this.type = '',
    this.status = 'active',
    this.startsAt,
    this.endsAt,
    this.episodesRemaining,
    this.plan,
    this.serverActive,
  });

  final int id;
  /// `is_active` as computed by the API (authoritative when present).
  final bool? serverActive;

  /// weekly | monthly | yearly | episodes
  final String type;
  final String status;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final int? episodesRemaining;
  final Plan? plan;

  bool get isTimeBased => const ['weekly', 'monthly', 'yearly'].contains(type);
  bool get isActive =>
      serverActive ??
      (status == 'active' && (endsAt == null || endsAt!.isAfter(DateTime.now())));

  String get label {
    if (plan != null && plan!.name.isNotEmpty) return plan!.name;
    return switch (type) {
      'weekly' => 'Weekly VIP',
      'monthly' => 'Monthly VIP',
      'yearly' => 'Yearly VIP',
      'episodes' => 'Episode pack',
      _ => 'VIP',
    };
  }

  factory Subscription.fromJson(Json j) => Subscription(
        id: asInt(j['id']),
        type: asString(j['type'] ?? asMap(j['plan'])['type']),
        status: asString(j['status'], 'active'),
        startsAt: asDate(j['starts_at']),
        endsAt: asDate(j['ends_at']),
        episodesRemaining: asIntOrNull(j['episodes_remaining']),
        plan: asMapOrNull(j['plan']) == null ? null : Plan.fromJson(asMap(j['plan'])),
        serverActive: j['is_active'] == null ? null : asBool(j['is_active']),
      );
}

class User {
  const User({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.role = 'viewer',
    this.coins = 0,
    this.avatarUrl,
    this.company,
    this.activeSubscription,
    this.serverVip,
  });

  final int id;
  final String name;
  /// `is_vip` flag from the API (authoritative when present).
  final bool? serverVip;
  final String? email;
  final String? phone;
  final String role;
  final int coins;
  final String? avatarUrl;
  final Company? company;
  final Subscription? activeSubscription;

  bool get isVip =>
      serverVip ??
      activeSubscription != null &&
      activeSubscription!.isActive &&
      activeSubscription!.isTimeBased;

  String get contact => email ?? phone ?? '';

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'A';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  User copyWith({int? coins, Subscription? activeSubscription}) => User(
        id: id,
        name: name,
        email: email,
        phone: phone,
        role: role,
        coins: coins ?? this.coins,
        avatarUrl: avatarUrl,
        company: company,
        activeSubscription: activeSubscription ?? this.activeSubscription,
        serverVip: serverVip,
      );

  factory User.fromJson(Json j) => User(
        id: asInt(j['id']),
        name: asString(j['name'], 'Afriva viewer'),
        email: asStringOrNull(j['email']),
        phone: asStringOrNull(j['phone']),
        role: asString(j['role'], 'viewer'),
        coins: asInt(j['coins']),
        avatarUrl: asStringOrNull(j['avatar_url']),
        company: asMapOrNull(j['company']) == null ? null : Company.fromJson(asMap(j['company'])),
        activeSubscription: asMapOrNull(j['active_subscription']) == null
            ? null
            : Subscription.fromJson(asMap(j['active_subscription'])),
        serverVip: j['is_vip'] == null ? null : asBool(j['is_vip']),
      );
}

class AuthResult {
  const AuthResult({required this.token, required this.user});
  final String token;
  final User user;

  factory AuthResult.fromJson(Json j) => AuthResult(
        token: asString(j['token']),
        user: User.fromJson(asMap(j['user'])),
      );
}
