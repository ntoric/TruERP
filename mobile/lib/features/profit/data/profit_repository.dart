import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/json.dart';
import '../../../core/api/paged.dart';
import '../../../core/api/revision.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/models/money.dart';

class ProfitRepository {
  ProfitRepository(this._api);
  final ApiClient _api;

  Future<List<Partner>> partners() async {
    final res = await _api.get('/partners');
    return (res is List ? asMapList(res) : asMapList(asMap(res)['data']))
        .map(Partner.fromJson)
        .toList();
  }

  Future<Partner> createPartner(Partner p) async =>
      Partner.fromJson(asMap(await _api.post('/partners', body: p.toJson())));

  Future<void> updatePartner(String id, Partner p) =>
      _api.put('/partners/$id', body: p.toJson());

  Future<void> deletePartner(String id) => _api.delete('/partners/$id');

  /// The endpoint returns every row; [Paged] treats it as one page.
  Future<Paged<ProfitDistribution>> distributions({
    int page = 1,
    String? partnerId,
    DateTime? from,
    DateTime? to,
  }) => _api.getPaged(
    '/profit-distributions',
    ProfitDistribution.fromJson,
    page: page,
    query: {
      'partner_id': partnerId,
      'start_date': from == null ? null : ymd(from),
      'end_date': to == null ? null : ymd(to),
    },
  );

  Future<ProfitDistribution> create({
    required String partnerId,
    required double amount,
    required DateTime date,
    String? accountId,
    String description = '',
    String reference = '',
    String notes = '',
  }) async => ProfitDistribution.fromJson(
    asMap(
      await _api.post(
        '/profit-distributions',
        body: {
          'partner_id': partnerId,
          'amount': amount,
          'date': apiDate(date),
          'account_id': accountId,
          'description': description.trim(),
          'reference': reference.trim(),
          'notes': notes.trim(),
        },
      ),
    ),
  );

  Future<void> delete(String id) => _api.delete('/profit-distributions/$id');
}

final profitRepositoryProvider = Provider(
  (ref) => ProfitRepository(ref.watch(apiClientProvider)),
);

final partnersProvider = FutureProvider.autoDispose<List<Partner>>((ref) {
  ref.watch(activeStoreIdProvider);
  ref.watch(dataRevisionProvider);
  return ref.watch(profitRepositoryProvider).partners();
});
