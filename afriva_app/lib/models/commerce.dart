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
    this.isAvailable = true,
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

  /// Connected to a tested provider (or demo sandbox). Others are shown as
  /// "Inakuja hivi karibuni" and cannot be chosen (SPEC §8.4).
  final bool isAvailable;

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
        isAvailable: asBool(j['is_available'], true),
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
    this.receiptNumber,
    this.refundedAmount = 0,
  });

  final String reference;
  final String? receiptNumber;
  final int refundedAmount;

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
  bool get isRefunded => status == 'refunded';

  /// A receipt exists once the server confirmed the payment.
  bool get hasReceipt => isSuccess || isRefunded;
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
      receiptNumber: asStringOrNull(j['receipt_number']),
      refundedAmount: asInt(j['refunded_amount']),
    );
  }
}

/// `GET /me/payments/{reference}/receipt`
class Receipt {
  const Receipt({
    required this.reference,
    required this.amount,
    this.receiptNumber,
    this.providerReference,
    this.status = 'success',
    this.issuedAt,
    this.customerName,
    this.customerContact,
    this.itemName,
    this.itemDelivered,
    this.methodName = '',
    this.refundedAmount = 0,
    this.currency = 'TZS',
    this.sellerName = 'Afriva',
    this.sellerEmail,
  });

  final String? receiptNumber;
  final String reference;
  final String? providerReference;
  final String status;
  final DateTime? issuedAt;
  final String? customerName;
  final String? customerContact;
  final String? itemName;
  final String? itemDelivered;
  final String methodName;
  final int amount;
  final int refundedAmount;
  final String currency;
  final String sellerName;
  final String? sellerEmail;

  factory Receipt.fromJson(Json j) {
    final customer = asMap(j['customer']);
    final item = asMap(j['item']);
    final method = asMap(j['payment_method']);
    final seller = asMap(j['seller']);
    return Receipt(
      receiptNumber: asStringOrNull(j['receipt_number']),
      reference: asString(j['reference']),
      providerReference: asStringOrNull(j['provider_reference']),
      status: asString(j['status'], 'success'),
      issuedAt: asDate(j['issued_at']),
      customerName: asStringOrNull(customer['name']),
      customerContact: asStringOrNull(customer['phone']) ?? asStringOrNull(customer['email']),
      itemName: asStringOrNull(item['name']),
      itemDelivered: asStringOrNull(item['delivered']),
      methodName: asString(method['name'], asString(method['code'])),
      amount: asInt(j['amount']),
      refundedAmount: asInt(j['refunded_amount']),
      currency: asString(j['currency'], 'TZS'),
      sellerName: asString(seller['name'], 'Afriva'),
      sellerEmail: asStringOrNull(seller['email']),
    );
  }
}

/// `GET /me/coins` ledger entry.
class CoinTransaction {
  const CoinTransaction({
    required this.id,
    required this.amount,
    required this.balanceAfter,
    required this.type,
    this.description,
    this.dramaTitle,
    this.episodeNumber,
    this.createdAt,
  });

  final int id;

  /// Positive = credit, negative = debit.
  final int amount;
  final int balanceAfter;

  /// purchase | bonus | unlock | admin_adjust | refund
  final String type;
  final String? description;
  final String? dramaTitle;
  final int? episodeNumber;
  final DateTime? createdAt;

  factory CoinTransaction.fromJson(Json j) {
    final ep = asMapOrNull(j['episode']);
    final drama = ep == null ? null : asMapOrNull(ep['drama']);
    return CoinTransaction(
      id: asInt(j['id']),
      amount: asInt(j['amount']),
      balanceAfter: asInt(j['balance_after']),
      type: asString(j['type']),
      description: asStringOrNull(j['description']),
      dramaTitle: drama == null ? null : asStringOrNull(drama['title']),
      episodeNumber: ep == null ? null : asIntOrNull(ep['number']),
      createdAt: asDate(j['created_at']),
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
