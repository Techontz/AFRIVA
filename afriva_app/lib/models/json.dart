/// Lenient JSON readers, the API may send numbers as strings, nulls, etc.
typedef Json = Map<String, dynamic>;

int asInt(Object? v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? double.tryParse(v)?.toInt() ?? fallback;
  if (v is bool) return v ? 1 : 0;
  return fallback;
}

int? asIntOrNull(Object? v) => v == null ? null : asInt(v);

String asString(Object? v, [String fallback = '']) {
  if (v == null) return fallback;
  return v.toString();
}

String? asStringOrNull(Object? v) {
  if (v == null) return null;
  final s = v.toString();
  return s.isEmpty ? null : s;
}

bool asBool(Object? v, [bool fallback = false]) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) return v == '1' || v.toLowerCase() == 'true';
  return fallback;
}

DateTime? asDate(Object? v) {
  if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v * 1000);
  return null;
}

Json asMap(Object? v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return <String, dynamic>{};
}

Json? asMapOrNull(Object? v) => v is Map ? asMap(v) : null;

List<T> asList<T>(Object? v, T Function(Json) parse) {
  if (v is Map && v['data'] is List) v = v['data'];
  if (v is! List) return <T>[];
  return v.whereType<Map>().map((e) => parse(asMap(e))).toList();
}

List<String> asStringList(Object? v) {
  if (v is! List) return const [];
  return v
      .map((e) {
        if (e is Map) return asString(e['name'] ?? e['title'] ?? e['label']);
        return asString(e);
      })
      .where((s) => s.isNotEmpty)
      .toList();
}
