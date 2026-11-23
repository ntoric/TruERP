import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/json.dart';
import '../../../core/api/paged.dart';
import '../../../core/api/revision.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/models/expense.dart';

class ExpenseDraft {
  ExpenseDraft({
    required this.category,
    required this.date,
    required this.items,
    this.description = '',
    this.vendor = '',
    this.originalInvoiceNum = '',
    this.paymentMode = 'cash',
    this.bankAccountId,
    this.withGst = false,
    this.taxRate = 0,
    this.notes = '',
  });

  String category;
  DateTime date;
  List<ExpenseItem> items;
  String description;
  String vendor;
  String originalInvoiceNum;
  String paymentMode;
  String? bankAccountId;
  bool withGst;
  double taxRate;
  String notes;

  double get subTotal => items.fold(0, (s, i) => s + i.amount);
  double get tax => withGst ? subTotal * taxRate / 100 : 0;

  /// Matches the server: items × price, plus GST on each item when enabled.
  double get total => subTotal + tax;

  /// The server computes the amount from [items]; an expense saved without
  /// items is stored as ₹0, so the form always sends at least one.
  JsonMap toJson() => {
        'category': category,
        'description': description.trim(),
        'original_invoice_num': originalInvoiceNum.trim(),
        'amount': total,
        'date': date.toUtc().toIso8601String(),
        'vendor': vendor.trim(),
        'payment_mode': paymentMode,
        'bank_account_id': paymentMode == 'cash' ? null : bankAccountId,
        'notes': notes.trim(),
        'with_gst': withGst,
        'tax_rate': withGst ? taxRate : 0,
        'items': items.map((i) => i.toJson()).toList(),
      };
}

class ExpensesRepository {
  ExpensesRepository(this._api);
  final ApiClient _api;

  /// The endpoint returns everything at once; [Paged] treats it as one page.
  Future<Paged<Expense>> list({int page = 1, String? search, String? category, DateTime? from, DateTime? to}) =>
      _api.getPaged('/expenses', Expense.fromJson, page: page, query: {
        'search': search,
        'category': category,
        'from': from == null ? null : ymd(from),
        'to': to == null ? null : ymd(to),
      });

  Future<Expense> get(String id) async => Expense.fromJson(await _api.getMap('/expenses/$id'));

  Future<Expense> create(ExpenseDraft d) async => Expense.fromJson(asMap(await _api.post('/expenses', body: d.toJson())));

  Future<Expense> update(String id, ExpenseDraft d) async =>
      Expense.fromJson(asMap(await _api.put('/expenses/$id', body: d.toJson())));

  Future<void> cancel(String id, String reason) => _api.post('/expenses/$id/cancel', body: {'reason': reason.trim()});

  Future<List<ExpenseCategory>> categories() async {
    final res = await _api.get('/expense-categories');
    final rows = res is List ? asMapList(res) : asMapList(asMap(res)['data']);
    return rows.map(ExpenseCategory.fromJson).toList()..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Future<ExpenseCategory> createCategory(String name, {String description = ''}) async => ExpenseCategory.fromJson(
      asMap(await _api.post('/expense-categories', body: {'name': name.trim(), 'description': description.trim(), 'is_active': true})));

  Future<void> updateCategory(ExpenseCategory c, {required String name, required bool isActive}) =>
      _api.put('/expense-categories/${c.id}', body: {'name': name.trim(), 'description': c.description, 'is_active': isActive});

  Future<void> deleteCategory(String id) => _api.delete('/expense-categories/$id');
}

final expensesRepositoryProvider = Provider((ref) => ExpensesRepository(ref.watch(apiClientProvider)));

final expenseProvider = FutureProvider.autoDispose.family<Expense, String>((ref, id) {
  ref.watch(activeStoreIdProvider);
  ref.watch(dataRevisionProvider);
  return ref.watch(expensesRepositoryProvider).get(id);
});

final expenseCategoriesProvider = FutureProvider.autoDispose<List<ExpenseCategory>>((ref) {
  ref.watch(activeStoreIdProvider);
  ref.watch(dataRevisionProvider);
  return ref.watch(expensesRepositoryProvider).categories();
});
