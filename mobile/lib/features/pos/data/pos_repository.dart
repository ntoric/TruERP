import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/api/json.dart';
import '../../../core/api/paged.dart';
import '../../../core/api/revision.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/models/invoice.dart';
import '../../../core/models/party.dart';
import '../../../core/models/product.dart';
import 'pos_models.dart';

class PosRepository {
  PosRepository(this._api);
  final ApiClient _api;

  /// The open session, or null when none is open.
  Future<PosSession?> activeSession() async {
    try {
      return PosSession.fromJson(await _api.getMap('/pos/sessions/active'));
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<PosSession> openSession(double openingCash) async =>
      PosSession.fromJson(asMap(await _api.post('/pos/sessions', body: {'opening_cash': openingCash})));

  Future<PosSession> closeSession(String id, {required double closingCash, String notes = ''}) async =>
      PosSession.fromJson(asMap(await _api.post('/pos/sessions/$id/close', body: {'closing_cash': closingCash, 'notes': notes.trim()})));

  Future<List<PosSession>> sessions({String? status}) async {
    final res = await _api.get('/pos/sessions', query: {'status': status});
    return (res is List ? asMapList(res) : asMapList(asMap(res)['data'])).map(PosSession.fromJson).toList();
  }

  Future<PosSession> session(String id) async => PosSession.fromJson(await _api.getMap('/pos/sessions/$id'));

  Future<List<CashMovement>> movements(String sessionId) async {
    final res = await _api.get('/pos/sessions/$sessionId/cash-movements');
    return (res is List ? asMapList(res) : asMapList(asMap(res)['data'])).map(CashMovement.fromJson).toList();
  }

  Future<void> addMovement(String sessionId, {required bool cashIn, required double amount, String reason = ''}) =>
      _api.post('/pos/sessions/$sessionId/cash-movements', body: {'type': cashIn ? 'cash_in' : 'cash_out', 'amount': amount, 'reason': reason.trim()});

  /// Products for the billing grid (active only), by name or code.
  Future<Paged<Product>> products({int page = 1, String? search, String? category}) => _api.getPaged(
    '/products',
    Product.fromJson,
    key: 'products',
    page: page,
    perPage: 40,
    query: {'search': search, 'category': category, 'sort': 'name', 'order': 'asc'},
  );

  /// Exact match for a scanned barcode / item code / SKU / PLU, else null.
  Future<Product?> byCode(String code) async {
    final c = code.trim();
    if (c.isEmpty) return null;
    final page = await products(search: c);
    final lc = c.toLowerCase();
    return page.items.where((p) => p.itemCode.toLowerCase() == lc || p.sku.toLowerCase() == lc).firstOrNull ??
        (page.items.length == 1 ? page.items.single : null);
  }

  /// POS sale through `POST /invoices`. One [clientSaleId] per checkout
  /// (also the Idempotency-Key) so a retry after a dropped response can't
  /// charge twice. No party = the server's "Walk-in Customer".
  Future<Invoice> sell({
    required String clientSaleId,
    required PosSession session,
    required List<CartLine> lines,
    required List<Tender> tenders,
    Party? party,
    double discount = 0,
  }) async {
    final totals = posTotals(lines, discount: discount);
    final paid = tenders.fold<double>(0, (s, t) => s + t.amount).clamp(0, totals.total).toDouble();
    final paying = tenders.where((t) => t.amount > 0).toList();
    final body = {
      'client_sale_id': clientSaleId,
      if (party != null) 'party_id': party.id,
      if (party != null) 'customer_id': party.id,
      'date': DateTime.now().toUtc().toIso8601String(),
      'status': totals.total > 0 && paid + 0.01 >= totals.total ? 'paid' : 'sent',
      'payment_mode': paying.isEmpty ? 'unpaid' : paying.first.mode,
      'amount_paid': paid,
      'bank_account_id': paying.where((t) => t.mode != 'cash').firstOrNull?.bankAccountId,
      'payment_splits': [for (final t in paying) t.toJson()],
      'is_pos': true,
      'pos_session_id': session.id,
      'session_opening_cash': session.openingCash,
      if (discount > 0) 'invoice_discount': discount,
      'items': [
        for (final l in lines) {...l.toLineItem().toInvoiceJson(), 'total': l.total},
      ],
    };
    return Invoice.fromJson(asMap(await _api.post('/invoices', body: body, headers: {'Idempotency-Key': clientSaleId})));
  }

  static String newSaleId() => const Uuid().v4();

  // ── Held bills ───────────────────────────────────────────────────────
  Future<List<HeldBill>> held({String? sessionId}) async {
    final res = await _api.get('/pos/drafts', query: {'session_id': sessionId});
    return (res is List ? asMapList(res) : asMapList(asMap(res)['data'])).map(HeldBill.fromJson).toList();
  }

  Future<void> hold({required String title, required List<CartLine> lines, String? partyId, String? sessionId, double discount = 0}) =>
      _api.post('/pos/drafts', body: {
        'title': title,
        'cart_data': HeldBill.encode(lines, discount: discount),
        'party_id': partyId,
        'session_id': sessionId,
      });

  Future<void> deleteHeld(String id) => _api.delete('/pos/drafts/$id');
}

final posRepositoryProvider = Provider((ref) => PosRepository(ref.watch(apiClientProvider)));

final activeSessionProvider = FutureProvider.autoDispose<PosSession?>((ref) {
  ref.watch(activeStoreIdProvider);
  ref.watch(dataRevisionProvider);
  return ref.watch(posRepositoryProvider).activeSession();
});

final heldBillsProvider = FutureProvider.autoDispose<List<HeldBill>>((ref) {
  ref.watch(activeStoreIdProvider);
  ref.watch(dataRevisionProvider);
  return ref.watch(posRepositoryProvider).held();
});
