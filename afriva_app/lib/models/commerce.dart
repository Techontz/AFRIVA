import '../l10n/l10n.dart';
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

  /// How much this subscription saves against buying the next shorter one
  /// repeatedly (monthly vs 4 weeks, yearly vs 12 months). Null when none.
  int? savingsAgainst(Iterable<Plan> all) {
    final days = durationDays ?? 0;
    if (!isSubscription || days <= 0) return null;
    Plan? shorter;
    for (final p in all) {
      final d = p.durationDays ?? 0;
      if (!p.isSubscription || d <= 0 || d >= days) continue;
      if (shorter == null || d > (shorter.durationDays ?? 0)) shorter = p;
    }
    if (shorter == null) return null;
    final units = (days / shorter.durationDays!).round();
    final save = units * shorter.price - price;
    return units > 1 && save > 0 ? save : null;
  }

  bool get isSubscription => const ['weekly', 'monthly', 'yearly'].contains(type);
  bool get isEpisodePack => type == 'episodes';
  bool get isCoins => type == 'coins';

  String get periodLabel => switch (type) {
        'weekly' => L10n.current.perWeek,
        'monthly' => L10n.current.perMonth,
        'yearly' => L10n.current.perYear,
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

/// One payment channel from `GET /checkout/options`.
class CheckoutChannel {
  const CheckoutChannel({required this.available, this.options = const [], this.hosted = false});
  final bool available;

  /// Card only: true when the card is typed on the payment partner's secure
  /// hosted page (Snippe) instead of in the app. No card fields, no saved cards.
  final bool hosted;

  /// Networks (mobile money) or brands (card): code, name, available.
  final List<({String code, String name, bool available})> options;

  bool isAvailable(String code) => options.any((o) => o.code == code && o.available);

  factory CheckoutChannel.fromJson(Json? j, String listKey) => CheckoutChannel(
        available: asBool(j?['available']),
        hosted: asBool(j?['hosted']),
        options: j == null
            ? const []
            : asList(j[listKey], (o) => (
                  code: asString(o['code']),
                  name: asString(o['name']),
                  available: asBool(o['available']),
                )),
      );
}

/// `GET /checkout/options`.
class CheckoutOptions {
  const CheckoutOptions({required this.mobileMoney, required this.card, this.demo = false});
  final CheckoutChannel mobileMoney;
  final CheckoutChannel card;
  final bool demo;

  /// Cards are paid on the partner's secure hosted page.
  bool get hostedCards => card.available && card.hosted;

  factory CheckoutOptions.fromJson(Json j) => CheckoutOptions(
        mobileMoney: CheckoutChannel.fromJson(asMapOrNull(j['mobile_money']), 'networks'),
        card: CheckoutChannel.fromJson(asMapOrNull(j['card']), 'brands'),
        demo: asBool(j['demo']),
      );
}

/// A way to pay the viewer saved earlier (`GET /me/payment-methods`).
class SavedMethod {
  const SavedMethod({
    required this.id,
    required this.type,
    required this.methodCode,
    this.network,
    this.phone,
    this.cardBrand,
    this.cardLast4,
    this.cardExpMonth,
    this.cardExpYear,
    this.isDefault = false,
    this.isExpired = false,
    this.oneTap = true,
    this.lastUsedAt,
  });

  final int id;

  /// mobile_money | card
  final String type;
  final String methodCode;
  final String? network;
  final String? phone;
  final String? cardBrand;
  final String? cardLast4;
  final int? cardExpMonth;
  final int? cardExpYear;
  final bool isDefault;
  final bool isExpired;
  final bool oneTap;
  final DateTime? lastUsedAt;

  bool get isCard => type == 'card';
  bool get isMobileMoney => type == 'mobile_money';
  bool get canPay => oneTap && !isExpired;

  String get expiryLabel => cardExpMonth == null || cardExpYear == null
      ? ''
      : '${cardExpMonth.toString().padLeft(2, '0')}/${(cardExpYear! % 100).toString().padLeft(2, '0')}';

  factory SavedMethod.fromJson(Json j) => SavedMethod(
        id: asInt(j['id']),
        type: asString(j['type']),
        methodCode: asString(j['method_code']),
        network: asStringOrNull(j['network']),
        phone: asStringOrNull(j['phone']),
        cardBrand: asStringOrNull(j['card_brand']),
        cardLast4: asStringOrNull(j['card_last4']),
        cardExpMonth: asIntOrNull(j['card_exp_month']),
        cardExpYear: asIntOrNull(j['card_exp_year']),
        isDefault: asBool(j['is_default']),
        isExpired: asBool(j['is_expired']),
        oneTap: asBool(j['one_tap'], true),
        lastUsedAt: asDate(j['last_used_at']),
      );
}

class Payment {
  const Payment({
    required this.reference,
    required this.status,
    required this.amount,
    this.currency = 'TZS',
    this.methodCode,
    this.phone,
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
  final String? phone;
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
      phone: asStringOrNull(j['phone']),
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
    this.userCoins,
  });

  final Payment payment;
  final String message;

  /// await_ussd | redirect | none
  final String nextAction;
  final String? redirectUrl;
  final int? userCoins;

  factory CheckoutResult.fromJson(Json j) => CheckoutResult(
        payment: Payment.fromJson(asMap(j['payment'])),
        message: asString(j['message']),
        nextAction: asString(j['next_action'], 'none'),
        redirectUrl: asStringOrNull(j['redirect_url']),
        userCoins: asIntOrNull(j['user_coins']),
      );
}
