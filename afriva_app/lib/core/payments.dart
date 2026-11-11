/// On-device payment helpers: Tanzanian mobile money numbers and card checks.
///
/// Nothing here talks to the network. The card helpers exist so the full card
/// number and CVC can be validated on the phone and then thrown away: only the
/// brand, last four digits and expiry ever leave the device.
library;

/// A mobile money network, told apart from the number prefix.
class MobileNetwork {
  const MobileNetwork(this.code, this.name);

  /// Payment method code used by the API (mpesa, airtelmoney, ...).
  final String code;
  final String name;

  static const mpesa = MobileNetwork('mpesa', 'M-Pesa');
  static const airtel = MobileNetwork('airtelmoney', 'Airtel Money');
  static const mixx = MobileNetwork('tigopesa', 'Mixx by Yas');
  static const halopesa = MobileNetwork('halopesa', 'HaloPesa');
  static const tpesa = MobileNetwork('tpesa', 'T-Pesa');

  /// Two digits after 255 => network. Mirrors backend `App\Payments\MobileNetwork`.
  static const prefixes = <String, MobileNetwork>{
    '74': mpesa, '75': mpesa, '76': mpesa, '79': mpesa,
    '68': airtel, '69': airtel, '78': airtel,
    '65': mixx, '67': mixx, '71': mixx, '77': mixx,
    '61': halopesa, '62': halopesa,
    '73': tpesa,
  };

  static const all = [mpesa, airtel, mixx, halopesa, tpesa];

  static MobileNetwork? byCode(String? code) {
    for (final n in all) {
      if (n.code == code) return n;
    }
    return null;
  }

  @override
  String toString() => name;
}

/// Tanzanian mobile number handling.
class TzPhone {
  TzPhone._();

  /// The national part (9 digits, no leading 0) of whatever was typed so far:
  /// "0754 123" => "754123", "+255 754" => "754", "754" => "754".
  static String national(String raw) {
    var d = raw.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('255')) {
      d = d.substring(3);
    } else if (d.startsWith('0')) {
      d = d.substring(1);
    }
    return d.length > 9 ? d.substring(0, 9) : d;
  }

  /// "0754123456" / "754123456" / "+255754123456" => "255754123456", or null
  /// when it is not a complete Tanzanian mobile number.
  static String? normalize(String raw) {
    final n = national(raw);
    if (!RegExp(r'^[67]\d{8}$').hasMatch(n)) return null;
    return '255$n';
  }

  /// Network for a (possibly partial) number, as soon as two digits are known.
  static MobileNetwork? detect(String raw) {
    final n = national(raw);
    if (n.length < 2) return null;
    return MobileNetwork.prefixes[n.substring(0, 2)];
  }

  /// "255754123456" => "+255 754 123 456".
  static String pretty(String? phone) {
    if (phone == null || phone.isEmpty) return '';
    final n = national(phone);
    if (n.length != 9) return phone;
    return '+255 ${n.substring(0, 3)} ${n.substring(3, 6)} ${n.substring(6)}';
  }

  /// "255754123456" => "+255 75• ••• 456" for quiet display.
  static String masked(String? phone) {
    final n = national(phone ?? '');
    if (n.length != 9) return pretty(phone);
    return '+255 ${n.substring(0, 2)}• ••• ${n.substring(6)}';
  }
}

enum CardBrand {
  visa('visa', 'Visa'),
  mastercard('mastercard', 'Mastercard');

  const CardBrand(this.code, this.label);
  final String code;
  final String label;

  static CardBrand? fromCode(String? code) => switch (code) {
        'visa' => visa,
        'mastercard' => mastercard,
        _ => null,
      };
}

enum CardError { number, brand, month, year, expired, cvc }

/// Card checks done on the device.
class CardValidator {
  CardValidator._();

  static String digits(String raw) => raw.replaceAll(RegExp(r'\D'), '');

  /// 4 => Visa; 51-55 or 2221-2720 => Mastercard; anything else is not accepted.
  static CardBrand? brandOf(String raw) {
    final d = digits(raw);
    if (d.isEmpty) return null;
    if (d.startsWith('4')) return CardBrand.visa;
    if (d.length >= 2) {
      final two = int.parse(d.substring(0, 2));
      if (two >= 51 && two <= 55) return CardBrand.mastercard;
    }
    if (d.length >= 4) {
      final four = int.parse(d.substring(0, 4));
      if (four >= 2221 && four <= 2720) return CardBrand.mastercard;
    }
    return null;
  }

  /// True while the typed digits could still become a Visa / Mastercard.
  static bool couldBeSupported(String raw) {
    final d = digits(raw);
    if (d.isEmpty) return true;
    if (brandOf(d) != null) return true;
    if (d[0] == '5') return d.length < 2;
    if (d[0] == '2') {
      if (d.length >= 4) return false;
      // Some 4-digit completion of this prefix lands in 2221..2720.
      final lo = int.parse(d.padRight(4, '0'));
      final hi = int.parse(d.padRight(4, '9'));
      return hi >= 2221 && lo <= 2720;
    }
    return false;
  }

  static bool luhn(String raw) {
    final d = digits(raw);
    if (d.isEmpty) return false;
    var sum = 0;
    var alt = false;
    for (var i = d.length - 1; i >= 0; i--) {
      var n = d.codeUnitAt(i) - 48;
      if (alt) {
        n *= 2;
        if (n > 9) n -= 9;
      }
      sum += n;
      alt = !alt;
    }
    return sum % 10 == 0;
  }

  static CardError? number(String raw) {
    final d = digits(raw);
    final brand = brandOf(d);
    if (d.length >= 2 && brand == null && !couldBeSupported(d)) return CardError.brand;
    if (d.length != 16 && !(brand == CardBrand.visa && (d.length == 13 || d.length == 19))) {
      return CardError.number;
    }
    if (brand == null) return CardError.brand;
    if (!luhn(d)) return CardError.number;
    return null;
  }

  /// [year] may be 2 digits (28) or 4 (2028).
  static int? fullYear(String year) {
    final y = int.tryParse(digits(year));
    if (y == null) return null;
    return y < 100 ? 2000 + y : y;
  }

  static CardError? expiry(String month, String year, {DateTime? now}) {
    final m = int.tryParse(digits(month));
    if (m == null || m < 1 || m > 12) return CardError.month;
    final y = fullYear(year);
    if (y == null || digits(year).length < 2) return CardError.year;
    final t = now ?? DateTime.now();
    // A card is valid through the last day of its expiry month.
    if (y < t.year || (y == t.year && m < t.month)) return CardError.expired;
    if (y > t.year + 25) return CardError.year;
    return null;
  }

  static CardError? cvc(String raw) => RegExp(r'^\d{3}$').hasMatch(raw) ? null : CardError.cvc;
}

/// What the app is allowed to send about a card: never the number or CVC.
class CardPayload {
  const CardPayload({
    required this.brand,
    required this.last4,
    required this.expMonth,
    required this.expYear,
    this.token,
  });

  final CardBrand brand;
  final String last4;
  final int expMonth;
  final int expYear;

  /// Single-use token from the card provider's SDK (see [CardPayload.fromInput]).
  final String? token;

  /// Validates the typed card and reduces it to the safe payload. Returns null
  /// when anything is invalid. The caller should clear the number and CVC
  /// fields once this has been built.
  static CardPayload? fromInput({
    required String number,
    required String month,
    required String year,
    required String cvc,
    DateTime? now,
  }) {
    if (CardValidator.number(number) != null) return null;
    if (CardValidator.expiry(month, year, now: now) != null) return null;
    if (CardValidator.cvc(cvc) != null) return null;
    final d = CardValidator.digits(number);

    // CARD PROVIDER TOKENIZATION GOES HERE.
    // When a card gateway is connected, hand `number`, `cvc` and the expiry
    // to its client SDK right here (directly from the device to the provider,
    // never to the Afriva API) and put the single-use token it returns into
    // `token` below. The full number and CVC must not be stored, logged or
    // sent anywhere else.
    const String? token = null;

    return CardPayload(
      brand: CardValidator.brandOf(d)!,
      last4: d.substring(d.length - 4),
      expMonth: int.parse(CardValidator.digits(month)),
      expYear: CardValidator.fullYear(year)!,
      token: token,
    );
  }

  Map<String, dynamic> toJson() => {
        'brand': brand.code,
        'last4': last4,
        'exp_month': expMonth,
        'exp_year': expYear,
        'token': ?token,
      };
}
