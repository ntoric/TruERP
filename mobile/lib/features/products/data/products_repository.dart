import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/json.dart';
import '../../../core/api/paged.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/models/product.dart';

class ProductsRepository {
  ProductsRepository(this._api);
  final ApiClient _api;

  /// [sort] = name | stock | sale_price | purchase_price | category.
  Future<Paged<Product>> list({
    int page = 1,
    int perPage = 25,
    String? search,
    String? category,
    String? sort,
    bool ascending = true,
  }) =>
      _api.getPaged('/products', Product.fromJson, key: 'products', page: page, perPage: perPage, query: {
        'search': search,
        'category': category,
        'sort': sort,
        if (sort != null) 'order': ascending ? 'asc' : 'desc',
      });

  Future<Product> get(String id) async => Product.fromJson(await _api.getMap('/products/$id'));

  /// Available quantity across all outlets/batches.
  Future<double> stock(String id) async {
    final rows = asMapList((await _api.getMap('/inventory/stocks/products/$id'))['data']);
    return rows.fold<double>(0, (sum, r) => sum + asDouble(r['available_qty']));
  }

  Future<Product> create(Product p, {double openingStock = 0}) async =>
      Product.fromJson(asMap(await _api.post('/products', body: p.toJson(openingStock: openingStock))));

  Future<Product> update(String id, Product p) async =>
      Product.fromJson(asMap(await _api.put('/products/$id', body: p.toJson())));

  Future<void> delete(String id) => _api.delete('/products/$id');

  Future<List<String>> units() async {
    final res = await _api.get('/products/units');
    final used = (res is List ? res : const []).map(asString).where((s) => s.isNotEmpty);
    return {...used, 'PCS', 'KG', 'GM', 'LTR', 'ML', 'BOX', 'PKT', 'DOZ', 'MTR', 'NOS'}.toList();
  }

  Future<List<String>> categories() async {
    final res = await _api.get('/categories', query: {'is_active': 'true'});
    final rows = res is List ? asMapList(res) : asMapList(asMap(res)['categories'] ?? asMap(res)['data']);
    return rows.map((r) => asString(r['name'])).where((s) => s.isNotEmpty).toSet().toList()..sort();
  }

  Future<String> generateItemCode() async => asString((await _api.getMap('/products/generate-item-code'))['item_code']);
}

final productsRepositoryProvider = Provider((ref) => ProductsRepository(ref.watch(apiClientProvider)));

/// Product plus live stock (the single-product endpoint omits stock).
final productDetailProvider = FutureProvider.autoDispose.family<Product, String>((ref, id) async {
  ref.watch(activeStoreIdProvider);
  final repo = ref.watch(productsRepositoryProvider);
  final results = await Future.wait([repo.get(id), repo.stock(id)]);
  return (results[0] as Product).withStock(results[1] as double);
});

final productCategoriesProvider = FutureProvider.autoDispose<List<String>>((ref) {
  ref.watch(activeStoreIdProvider);
  return ref.watch(productsRepositoryProvider).categories();
});

final productUnitsProvider = FutureProvider.autoDispose<List<String>>((ref) {
  ref.watch(activeStoreIdProvider);
  return ref.watch(productsRepositoryProvider).units();
});
