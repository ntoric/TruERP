/// Tolerant JSON readers. The backend sometimes sends numbers as strings,
/// omits fields, or returns `null`; these helpers never throw.
typedef JsonMap = Map<String, dynamic>;

double asDouble(Object? v, [double fallback = 0]) {
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim()) ?? fallback;
  return fallback;
}

int asInt(Object? v, [int fallback = 0]) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim()) ?? double.tryParse(v.trim())?.toInt() ?? fallback;
  return fallback;
}

String asString(Object? v, [String fallback = '']) {
  if (v == null) return fallback;
  if (v is String) return v;
  return v.toString();
}

String? asStringOrNull(Object? v) {
  final s = asString(v).trim();
  return s.isEmpty ? null : s;
}

bool asBool(Object? v, [bool fallback = false]) {
  if (v == null) return fallback;
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) return v.toLowerCase() == 'true' || v == '1';
  return fallback;
}

/// Parses ISO-8601 dates. Zero dates (`0001-01-01…`) come back as null.
DateTime? asDate(Object? v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  final s = asString(v).trim();
  if (s.isEmpty || s.startsWith('0001-01-01')) return null;
  return DateTime.tryParse(s)?.toLocal();
}

JsonMap asMap(Object? v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return v.map((k, val) => MapEntry(k.toString(), val));
  return <String, dynamic>{};
}

List<JsonMap> asMapList(Object? v) {
  if (v is List) return v.map(asMap).toList();
  return const [];
}

/// Reads a nested path such as `party.name`.
Object? pick(JsonMap json, String path) {
  Object? cur = json;
  for (final key in path.split('.')) {
    if (cur is Map) {
      cur = cur[key];
    } else {
      return null;
    }
  }
  return cur;
}

/// Serialises a date as the backend expects (RFC3339 at local midnight → UTC).
String apiDate(DateTime d) => DateTime(d.year, d.month, d.day).toUtc().toIso8601String();

/// `YYYY-MM-DD` used by report/list query params.
String ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
