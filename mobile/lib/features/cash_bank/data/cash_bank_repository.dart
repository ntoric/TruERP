import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/json.dart';
import '../../../core/api/paged.dart';
import '../../../core/api/revision.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/models/money.dart';
import '../../../core/models/payment.dart';

/// Kind of manual money movement.
enum MoneyMove { add, reduce, transfer }

class CashBankRepository {
  CashBankRepository(this._api);
  final ApiClient _api;

  Future<CashBankSummary> summary() async => CashBankSummary.fromJson(await _api.getMap('/cash-bank/summary'));

  /// [accountId]: a bank account id, `cash` for cash in hand, or null for all.
  Future<Paged<CashTransaction>> transactions({
    int page = 1,
    String? accountId,
    String? type,
    String? search,
    DateTime? from,
    DateTime? to,
  }) =>
      _api.getPaged('/cash-bank/transactions', CashTransaction.fromJson, key: 'transactions', page: page, query: {
        'account_id': accountId,
        'transaction_type': type,
        'search': search,
        'start_date': from == null ? null : ymd(from),
        'end_date': to == null ? null : ymd(to),
      });

  /// Add or reduce: [accountId] null = cash in hand. Transfer: bank → bank.
  Future<void> move(
    MoneyMove kind, {
    required double amount,
    required DateTime date,
    String? accountId,
    String? fromAccountId,
    String? toAccountId,
    String description = '',
    String reference = '',
  }) {
    final common = {
      'amount': amount,
      'date': date.toUtc().toIso8601String(),
      'description': description.trim(),
      'reference': reference.trim(),
    };
    return switch (kind) {
      MoneyMove.add => _api.post('/cash-bank/transactions/add', body: {...common, 'account_id': accountId}),
      MoneyMove.reduce => _api.post('/cash-bank/transactions/reduce', body: {...common, 'account_id': accountId}),
      MoneyMove.transfer => _api.post('/cash-bank/transactions/transfer',
          body: {...common, 'from_account_id': fromAccountId, 'to_account_id': toAccountId}),
    };
  }

  Future<void> deleteTransaction(String id) => _api.delete('/cash-bank/transactions/$id');

  Future<BankAccount> createAccount({
    required String name,
    required String number,
    required String bank,
    String ifsc = '',
    String type = 'savings',
    double opening = 0,
    String notes = '',
  }) async =>
      BankAccount.fromJson(asMap(await _api.post('/cash-bank/accounts', body: {
        'account_name': name.trim(),
        'account_number': number.trim(),
        'bank_name': bank.trim(),
        'ifsc_code': ifsc.trim().toUpperCase(),
        'account_type': type,
        'opening_balance': opening,
        'notes': notes.trim(),
      })));

  /// The backend rewrites every field here (including is_active), so all
  /// are always sent. Opening balance can't be changed after creation.
  Future<void> updateAccount(
    String id, {
    required String name,
    required String number,
    required String bank,
    required String ifsc,
    required String type,
    required bool isActive,
    required String notes,
  }) =>
      _api.put('/cash-bank/accounts/$id', body: {
        'account_name': name.trim(),
        'account_number': number.trim(),
        'bank_name': bank.trim(),
        'ifsc_code': ifsc.trim().toUpperCase(),
        'account_type': type,
        'is_active': isActive,
        'notes': notes.trim(),
      });

  Future<void> setPrimary(String id) => _api.put('/cash-bank/accounts/$id/set-primary');

  Future<void> deleteAccount(String id) => _api.delete('/cash-bank/accounts/$id');

  Future<List<PaymentRouting>> routing() async {
    final res = asMap(await _api.get('/cash-bank/payment-method-mappings'));
    return asMapList(res['mappings']).map(PaymentRouting.fromJson).toList();
  }

  Future<void> saveRouting(Map<String, String?> accountByMethod) => _api.put('/cash-bank/payment-method-mappings', body: {
        'mappings': [
          for (final e in accountByMethod.entries) {'payment_method': e.key, 'bank_account_id': e.value},
        ],
      });
}

final cashBankRepositoryProvider = Provider((ref) => CashBankRepository(ref.watch(apiClientProvider)));

final cashBankSummaryProvider = FutureProvider.autoDispose<CashBankSummary>((ref) {
  ref.watch(activeStoreIdProvider);
  ref.watch(dataRevisionProvider);
  return ref.watch(cashBankRepositoryProvider).summary();
});

final paymentRoutingProvider = FutureProvider.autoDispose<List<PaymentRouting>>((ref) {
  ref.watch(activeStoreIdProvider);
  ref.watch(dataRevisionProvider);
  return ref.watch(cashBankRepositoryProvider).routing();
});
