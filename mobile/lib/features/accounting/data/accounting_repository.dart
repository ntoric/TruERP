import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/json.dart';
import '../../../core/api/paged.dart';
import '../../../core/api/revision.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/models/money.dart';

/// Read-only views of the books. Journal posting stays on the web.
class AccountingRepository {
  AccountingRepository(this._api);
  final ApiClient _api;

  Future<AccountingStats> stats() async => AccountingStats.fromJson(await _api.getMap('/accounting/stats'));

  Future<List<LedgerAccount>> accounts() async {
    final res = await _api.get('/accounting/accounts');
    return (res is List ? asMapList(res) : asMapList(asMap(res)['data'])).map(LedgerAccount.fromJson).toList();
  }

  Future<Paged<JournalEntry>> journal({int page = 1, DateTime? from, DateTime? to}) =>
      _api.getPaged('/accounting/journal', JournalEntry.fromJson, key: 'data', page: page, query: {
        'from_date': from == null ? null : ymd(from),
        'to_date': to == null ? null : ymd(to),
      });

  // Reports are requested without paging so every row comes back at once.
  Future<TrialBalance> trialBalance(DateTime asOf) async =>
      TrialBalance.fromJson(await _api.getMap('/accounting/trial-balance', query: {'as_of_date': ymd(asOf)}));

  Future<ProfitLossStatement> profitLoss(DateTime from, DateTime to) async => ProfitLossStatement.fromJson(
      await _api.getMap('/accounting/profit-loss', query: {'from_date': ymd(from), 'to_date': ymd(to)}));

  Future<BalanceSheet> balanceSheet(DateTime asOf) async =>
      BalanceSheet.fromJson(await _api.getMap('/accounting/balance-sheet', query: {'as_of_date': ymd(asOf)}));

  Future<GeneralLedger> ledger(String accountId, {DateTime? from, DateTime? to}) async =>
      GeneralLedger.fromJson(await _api.getMap('/accounting/general-ledger/$accountId', query: {
        'from_date': from == null ? null : ymd(from),
        'to_date': to == null ? null : ymd(to),
      }));
}

final accountingRepositoryProvider = Provider((ref) => AccountingRepository(ref.watch(apiClientProvider)));

final accountingStatsProvider = FutureProvider.autoDispose<AccountingStats>((ref) {
  ref.watch(activeStoreIdProvider);
  ref.watch(dataRevisionProvider);
  return ref.watch(accountingRepositoryProvider).stats();
});

final chartOfAccountsProvider = FutureProvider.autoDispose<List<LedgerAccount>>((ref) {
  ref.watch(activeStoreIdProvider);
  ref.watch(dataRevisionProvider);
  return ref.watch(accountingRepositoryProvider).accounts();
});
