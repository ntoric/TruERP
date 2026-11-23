import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/json.dart';
import '../../../core/api/paged.dart';
import '../../../core/api/revision.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/models/party.dart';

class PartiesRepository {
  PartiesRepository(this._api);
  final ApiClient _api;

  /// [type] = customer | vendor; [balance] = to_collect | to_pay.
  Future<Paged<Party>> list({int page = 1, String? search, String? type, String? balance, String? category}) =>
      _api.getPaged('/parties', Party.fromJson, key: 'parties', page: page, query: {
        'search': search,
        'party_type': type,
        'balance': balance,
        'category': category,
      });

  Future<PartyStats> stats() async => PartyStats.fromJson(await _api.getMap('/parties/stats'));

  Future<Party> get(String id) async => Party.fromJson(await _api.getMap('/parties/$id'));

  Future<Party> create(Party p) async => Party.fromJson(asMap(await _api.post('/parties', body: p.toJson())));

  Future<Party> update(String id, Party p) async => Party.fromJson(asMap(await _api.put('/parties/$id', body: p.toJson())));

  Future<void> delete(String id) => _api.delete('/parties/$id');

  Future<PartyLedger> ledger(String id, {DateTime? from, DateTime? to}) async => PartyLedger.fromJson(
        await _api.getMap('/parties/$id/ledger', query: {
          'from_date': from == null ? null : ymd(from),
          'to_date': to == null ? null : ymd(to),
        }),
      );

  /// Distinct categories in use (paged list response carries them).
  Future<List<String>> categories() async {
    final res = asMap(await _api.get('/parties', query: {'page': 1, 'per_page': 1}));
    final list = (res['categories'] as List?)?.map(asString).where((s) => s.isNotEmpty).toSet() ?? <String>{};
    return {...list, 'Retail', 'Wholesale'}.toList()..sort();
  }
}

final partiesRepositoryProvider = Provider((ref) => PartiesRepository(ref.watch(apiClientProvider)));

final partyProvider = FutureProvider.autoDispose.family<Party, String>((ref, id) {
  ref.watch(activeStoreIdProvider);
  ref.watch(dataRevisionProvider);
  return ref.watch(partiesRepositoryProvider).get(id);
});

final partyStatsProvider = FutureProvider.autoDispose<PartyStats>((ref) {
  ref.watch(activeStoreIdProvider);
  return ref.watch(partiesRepositoryProvider).stats();
});

final partyCategoriesProvider = FutureProvider.autoDispose<List<String>>((ref) {
  ref.watch(activeStoreIdProvider);
  return ref.watch(partiesRepositoryProvider).categories();
});
