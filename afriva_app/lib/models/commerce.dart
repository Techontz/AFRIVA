import 'json.dart';

class Plan {
  const Plan({
    required this.id,
    required this.name,
    required this.type,
    required this.price,
    this.currency = 'TZS',
    this.durationDays,
    this.episodeQuota,
    this.coins,
    this.bonusCoins,
    this.description = '',
    this.features = const [],
    this.isPopular = false,
  });

  final int id;
  final String name;

  /// weekly | monthly | yearly | episodes | coins
  final String type;
  final int price;
  final String currency;
  final int? durationDays;
  final int? episodeQuota;
  final int? coins;
  final int? bonusCoins;
  final String description;
  final List<String> features;
  final bool isPopular;

  bool get isSubscription => const ['weekly', 'monthly', 'yearly'].contains(type);
  bool get isEpisodePack => type == 'episodes';
  bool get isCoins => type == 'coins';

  String get periodLabel => switch (type) {
        'weekly' => '/ week',
        'monthly' => '/ month',
        'yearly' => '/ year',
        _ => '',
      };

  /// Price per day for subscriptions, used for "only X TZS/day" hints.
  int? get pricePerDay =>
      (durationDays != null && durationDays! > 0) ? (price / durationDays!).round() : null;

  factory Plan.fromJson(Json j) => Plan(
        id: asInt(j['id']),
        name: asString(j['name']),
        type: asString(j['type']),
        price: asInt(j['price'] ?? j['amount']),
        currency: asString(j['currency'], 'TZS'),
        durationDays: asIntOrNull(j['duration_days']),
        episodeQuota: asIntOrNull(j['episode_quota']),
        coins: asIntOrNull(j['coins']),
        bonusCoins: asIntOrNull(j['bonus_coins']),
        description: asString(j['description']),
        features: asStringList(j['features']),
        isPopular: asBool(j['is_popular']),
      );
}

class PaymentMethod {
  const PaymentMethod({
    required this.id,
    required this.code,
    required this.name,
    required this.type,
    this.logoUrl,
    this.color,
    this.isEnabled = true,
    this.isIntegrated = false,
  });

  final int id;
  final String code;
  final String name;

  /// mobile_money | card | bank
  final String type;
  final String? logoUrl;
  final String? color;
  final bool isEnabled;
  final bool isIntegrated;

  bool get isMobileMoney => type == 'mobile_money';
  bool get isCard => type == 'card';
  bool get isBank => type == 'bank';

  factory PaymentMethod.fromJson(Json j) => PaymentMethod(
        id: asInt(j['id']),
        code: asString(j['code']),
        name: asString(j['name']),
        type: asString(j['type']),
        logoUrl: asStringOrNull(j['logo_url']),
        color: asStringOrNull(j['color']),
        isEnabled: asBool(j['is_enabled'], true),
        isIntegrated: asBool(j['is_integrated']),
      );
}

class Payment {
  const Payment({
    required this.reference,
    required this.status,
    required this.amount,
    this.currency = 'TZS',
    this.methodCode,
    this.planName,
    this.createdAt,
    this.paidAt,
  });

  final String reference;

  /// pending | success | failed | cancelled
  final String status;
  final int amount;
  final String currency;
  final String? methodCode;
  final String? planName;
  final DateTime? createdAt;
  final DateTime? paidAt;

  bool get isPending => status == 'pending';
  bool get isSuccess => status == 'success';
  bool get isFailed => status == 'failed' || status == 'cancelled';

  factory Payment.fromJson(Json j) {
    final plan = asMapOrNull(j['plan']);
    final method = asMapOrNull(j['payment_method']);
    return Payment(
      reference: asString(j['reference']),
      status: asString(j['status'], 'pending'),
      amount: asInt(j['amount']),
      currency: asString(j['currency'], 'TZS'),
      methodCode: asStringOrNull(j['payment_method_code']) ??
          (method != null ? asStringOrNull(method['code']) : asStringOrNull(j['payment_method'])),
      planName: plan != null ? asStringOrNull(plan['name']) : asStringOrNull(j['plan_name']),
      createdAt: asDate(j['created_at']),
      paidAt: asDate(j['paid_at']),
    );
  }
}

/// `POST /checkout` response.
class CheckoutResult {
  const CheckoutResult({
    required this.payment,
    this.message = '',
    this.nextAction = 'none',
    this.redirectUrl,
  });

  final Payment payment;
  final String message;

  /// await_ussd | redirect | none
  final String nextAction;
  final String? redirectUrl;

  factory CheckoutResult.fromJson(Json j) => CheckoutResult(
        payment: Payment.fromJson(asMap(j['payment'])),
        message: asString(j['message']),
        nextAction: asString(j['next_action'], 'none'),
        redirectUrl: asStringOrNull(j['redirect_url']),
      );
}
