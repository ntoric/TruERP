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
  if (v is String) {
    return int.tryParse(v.trim()) ??
        double.tryParse(v.trim())?.toInt() ??
        fallback;
  }
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
  final p = DateTime.tryParse(s);
  if (p == null) return null;
  // Date-only values ("2026-11-05" or UTC midnight, how [apiDate] and the web
  // send them) are calendar days: keep the day instead of shifting it into
  // the device's time zone, which would show the previous day west of UTC.
  if (s.length == 10 ||
      (p.isUtc &&
          p.hour == 0 &&
          p.minute == 0 &&
          p.second == 0 &&
          p.millisecond == 0)) {
    return DateTime(p.year, p.month, p.day);
  }
  return p.toLocal();
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

/// Serialises a calendar date the way the web app does: UTC midnight of the
/// chosen day (`new Date('2026-11-01').toISOString()` → `2026-11-01T00:00:00Z`).
///
/// Converting *local* midnight to UTC instead would shift every date one day
/// back in India (00:00 IST = 18:30Z the previous day), so invoices, bills
/// and payroll periods would land on the wrong day in reports.
String apiDate(DateTime d) =>
    DateTime.utc(d.year, d.month, d.day).toIso8601String();

String? apiDateOrNull(DateTime? d) => d == null ? null : apiDate(d);

/// `YYYY-MM-DD` used by report/list query params.
String ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
