import 'json.dart';

/// One page of a list endpoint.
///
/// The backend returns lists in three shapes; [Paged.parse] accepts all:
///   1. a bare array (legacy, unpaginated)
///   2. `{ <key>: [...], total, page, per_page }`
///   3. `{ data: [...], total, ... }`
class Paged<T> {
  const Paged({required this.items, required this.total, required this.page, required this.perPage});

  final List<T> items;
  final int total;
  final int page;
  final int perPage;

  bool get hasMore => page * perPage < total;

  static const _knownKeys = [
    'data', 'items', 'invoices', 'parties', 'products', 'payments', 'payment_outs', 'bills',
    'categories', 'transactions', 'orders', 'results', 'records', 'entries',
  ];

  static Paged<T> parse<T>(Object? body, T Function(JsonMap) fromJson,
      {String? key, int page = 1, int perPage = 25}) {
    List<JsonMap> raw;
    var total = -1;
    var p = page;
    var pp = perPage;
    if (body is List) {
      raw = asMapList(body);
    } else {
      final map = asMap(body);
      Object? list;
      if (key != null && map[key] is List) {
        list = map[key];
      } else {
        for (final k in _knownKeys) {
          if (map[k] is List) {
            list = map[k];
            break;
          }
        }
        // Last resort: the first list-valued field.
        list ??= map.values.firstWhere((v) => v is List, orElse: () => const []);
      }
      raw = asMapList(list);
      total = asInt(map['total'], -1);
      p = asInt(map['page'], page);
      pp = asInt(map['per_page'] ?? map['limit'], perPage);
    }
    // Unpaginated arrays: everything arrived at once.
    if (total < 0) {
      total = raw.length;
      pp = raw.isEmpty ? perPage : raw.length;
      p = 1;
    }
    return Paged(items: raw.map(fromJson).toList(), total: total, page: p, perPage: pp == 0 ? perPage : pp);
  }
}
