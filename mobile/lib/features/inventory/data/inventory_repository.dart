import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/json.dart';
import '../../../core/api/paged.dart';
import '../../../core/api/revision.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/models/inventory.dart';

class InventoryRepository {
  InventoryRepository(this._api);
  final ApiClient _api;

  Future<InventoryStats> stats() async => InventoryStats.fromJson(await _api.getMap('/inventory/stats'));

  /// Stock positions (product × warehouse × batch), paginated.
  Future<Paged<StockRow>> stocks({int page = 1, String? search, String? outletId, String? productId, bool availableOnly = false}) =>
      _api.getPaged('/inventory/stocks', StockRow.fromJson, key: 'data', page: page, query: {
        'search': search,
        'outlet_id': outletId,
        'product_id': productId,
        if (availableOnly) 'available_only': 'true',
      });

  /// Stock positions for specific products (used to resolve names).
  Future<List<StockRow>> stocksFor(List<String> productIds) async {
    if (productIds.isEmpty) return const [];
    final res = await _api.get('/inventory/stocks', query: {'product_ids': productIds.join(',')});
    return (res is List ? asMapList(res) : asMapList(asMap(res)['data'])).map(StockRow.fromJson).toList();
  }

  Future<Paged<LowStockRow>> lowStock({int page = 1}) =>
      _api.getPaged('/inventory/alerts/low-stock', LowStockRow.fromJson, key: 'data', page: page);

  /// Signed [quantity]: positive adds stock, negative removes it.
  Future<void> adjust({
    required String productId,
    required String productName,
    required String outletId,
    required double quantity,
    required String reason,
    String batchNo = '',
  }) =>
      _api.post('/inventory/stocks/adjust', body: {
        'item_name': productName,
        'product_id': productId,
        'outlet_id': outletId,
        'quantity': quantity,
        'batch_no': batchNo,
        'reason': reason.trim(),
      });

  // ── Approvals ────────────────────────────────────────────────────────
  Future<Paged<StockEntry>> entries({int page = 1, String? status}) =>
      _api.getPaged('/inventory/entries', StockEntry.fromJson, key: 'data', page: page, query: {'approval_status': status});

  Future<void> approve(String id) => _api.post('/inventory/entries/$id/approve');
  Future<void> reject(String id, String reason) => _api.post('/inventory/entries/$id/reject', body: {'reason': reason.trim()});
  Future<void> approveAll() => _api.post('/inventory/entries/approve-all', body: const {});

  // ── Movements ────────────────────────────────────────────────────────
  Map<String, dynamic> _movementQuery(DateTime from, DateTime to, String? type, String? search) => {
        'from_date': ymd(from),
        'to_date': ymd(to),
        'type': type,
        'search': search,
      };

  Future<Paged<Movement>> movements({required DateTime from, required DateTime to, int page = 1, String? type, String? search}) =>
      _api.getPaged('/inventory/movements', Movement.fromJson,
          key: 'data', page: page, perPage: 50, query: _movementQuery(from, to, type, search));

  Future<MovementSummary> movementSummary({required DateTime from, required DateTime to, String? type, String? search}) async =>
      MovementSummary.fromJson(await _api.getMap('/inventory/movements/summary', query: _movementQuery(from, to, type, search)));

  // ── Warehouses ───────────────────────────────────────────────────────
  Future<List<Warehouse>> warehouses() async {
    final res = await _api.get('/warehouses');
    return (res is List ? asMapList(res) : asMapList(asMap(res)['data'])).map(Warehouse.fromJson).toList();
  }

  Future<Warehouse> createWarehouse(Warehouse w) async =>
      Warehouse.fromJson(asMap(await _api.post('/warehouses', body: w.toJson())));

  Future<void> updateWarehouse(String id, Warehouse w) => _api.put('/warehouses/$id', body: w.toJson());
  Future<void> deleteWarehouse(String id) => _api.delete('/warehouses/$id');

  Future<(List<WarehouseStockItem>, double)> warehouseStock(String id) async {
    final res = await _api.getMap('/warehouses/$id/stock');
    return (asMapList(res['items']).map(WarehouseStockItem.fromJson).toList(), asDouble(res['total_value']));
  }

  // ── Categories ───────────────────────────────────────────────────────
  Future<List<ProductCategory>> categories() async {
    final res = await _api.get('/categories');
    return (res is List ? asMapList(res) : asMapList(asMap(res)['categories'] ?? asMap(res)['data']))
        .map(ProductCategory.fromJson)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Future<void> createCategory(String name, {String description = ''}) =>
      _api.post('/categories', body: {'name': name.trim(), 'description': description.trim(), 'is_active': true});

  /// The backend rewrites parent and active flag, so both are always sent.
  Future<void> updateCategory(ProductCategory c, {required String name, required String description, required bool isActive}) =>
      _api.put('/categories/${c.id}', body: {
        'name': name.trim(),
        'description': description.trim(),
        'parent_id': c.parentId,
        'is_active': isActive,
      });

  Future<void> deleteCategory(String id) => _api.delete('/categories/$id');

  // ── Transfers ────────────────────────────────────────────────────────
  Future<Paged<StockTransfer>> transfers({int page = 1, String? status}) =>
      _api.getPaged('/inventory/transfers', StockTransfer.fromJson, key: 'data', page: page, query: {'status': status});

  Future<StockTransfer> transfer(String id) async => StockTransfer.fromJson(await _api.getMap('/inventory/transfers/$id'));

  Future<StockTransfer> createTransfer({
    required String fromId,
    required String toId,
    required Map<String, double> qtyByProduct,
    String notes = '',
  }) async =>
      StockTransfer.fromJson(asMap(await _api.post('/inventory/transfers', body: {
        'from_outlet_id': fromId,
        'to_outlet_id': toId,
        'notes': notes.trim(),
        'items': [
          for (final e in qtyByProduct.entries)
            if (e.value > 0) {'product_id': e.key, 'quantity': e.value},
        ],
      })));

  Future<void> submitTransfer(String id) => _api.post('/inventory/transfers/$id/submit');
  Future<void> receiveTransfer(String id) => _api.post('/inventory/transfers/$id/receive');
}

final inventoryRepositoryProvider = Provider((ref) => InventoryRepository(ref.watch(apiClientProvider)));

final inventoryStatsProvider = FutureProvider.autoDispose<InventoryStats>((ref) {
  ref.watch(activeStoreIdProvider);
  ref.watch(dataRevisionProvider);
  return ref.watch(inventoryRepositoryProvider).stats();
});

final warehousesProvider = FutureProvider.autoDispose<List<Warehouse>>((ref) {
  ref.watch(activeStoreIdProvider);
  ref.watch(dataRevisionProvider);
  return ref.watch(inventoryRepositoryProvider).warehouses();
});

final productCategoryListProvider = FutureProvider.autoDispose<List<ProductCategory>>((ref) {
  ref.watch(activeStoreIdProvider);
  ref.watch(dataRevisionProvider);
  return ref.watch(inventoryRepositoryProvider).categories();
});
