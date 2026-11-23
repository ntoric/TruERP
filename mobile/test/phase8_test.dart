import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:truerp_mobile/core/api/api_client.dart';
import 'package:truerp_mobile/core/api/api_exception.dart';
import 'package:truerp_mobile/core/config/app_config.dart';
import 'package:truerp_mobile/core/models/party.dart';
import 'package:truerp_mobile/core/models/product.dart';
import 'package:truerp_mobile/features/pos/data/pos_models.dart';
import 'package:truerp_mobile/features/pos/data/pos_repository.dart';

/// Records posts; never touches the network.
class _RecordingApi extends ApiClient {
  _RecordingApi(super.config, super.tokens);
  String? path;
  Map<String, dynamic>? body;
  Map<String, String>? headers;
  Object? getError;

  @override
  Future<dynamic> post(String path, {Object? body, Map<String, dynamic>? query, Map<String, String>? headers}) async {
    this.path = path;
    this.body = body as Map<String, dynamic>?;
    this.headers = headers;
    return {'id': 'inv1', 'invoice_number': 'INV-1'};
  }

  @override
  Future<Map<String, dynamic>> getMap(String path, {Map<String, dynamic>? query}) async {
    if (getError != null) throw getError!;
    return {'id': 'ps1', 'status': 'open'};
  }
}

Product _p(String id, double price, {String code = ''}) =>
    Product.fromJson({'id': id, 'name': 'Item $id', 'sale_price': price, 'item_code': code, 'unit': 'PCS'});

void main() {
  late _RecordingApi api;
  late PosRepository repo;
  const session = PosSession(id: 'ps1', status: 'open', openingCash: 1500);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    api = _RecordingApi(AppConfig(await SharedPreferences.getInstance()), AuthTokenHolder());
    repo = PosRepository(api);
  });

  test('POS totals round to the whole rupee', () {
    final t = posTotals([CartLine(product: _p('a', 10.40), quantity: 3)]);
    expect(t.subTotal, closeTo(31.2, 0.001));
    expect(t.total, 31);
    expect(t.roundOff, closeTo(-0.2, 0.001));
    expect(posTotals([CartLine(product: _p('a', 10.5))]).total, 11);
  });

  test('bill discount comes off before rounding', () {
    final t = posTotals([CartLine(product: _p('a', 100), quantity: 2)], discount: 15.4);
    expect(t.total, 185);
  });

  test('expected drawer cash = opening + sales + in − out', () {
    final s = PosSession.fromJson({
      'id': 'x',
      'status': 'closed',
      'opening_cash': 2000,
      'total_sales': 9000,
      'cash_in_total': 500,
      'cash_out_total': 200,
    });
    expect(s.isOpen, isFalse);
    expect(s.expectedCash, 11300);
  });

  test('held bill round-trips in the web cart_data format', () {
    final lines = [CartLine(product: _p('a', 50, code: 'A1'), quantity: 2), CartLine(product: _p('b', 20))];
    final encoded = HeldBill.encode(lines, discount: 10);
    final decoded = jsonDecode(encoded) as Map<String, dynamic>;
    expect(decoded['discountType'], 'amount');
    expect((decoded['items'] as List).first['product']['id'], 'a');

    final bill = HeldBill.fromJson({'id': 'd1', 'title': 'T', 'cart_data': encoded});
    expect(bill.itemCount, 2);
    expect(bill.lines.first.quantity, 2);
    expect(bill.lines.first.product.itemCode, 'A1');
    expect(bill.discount, 10);
    expect(bill.total, 120);
  });

  test('held bill reads the plain-list format and ignores junk', () {
    final list = HeldBill.fromJson({
      'id': 'd2',
      'cart_data': '[{"product":{"id":"p","sale_price":5},"quantity":4},{"quantity":1}]',
    });
    expect(list.itemCount, 1);
    expect(list.total, 20);
    expect(HeldBill.fromJson({'id': 'd3', 'cart_data': 'not json'}).itemCount, 0);
    // A percent discount from the web isn't applied as an amount.
    final pct = HeldBill.fromJson({
      'id': 'd4',
      'cart_data': '{"items":[],"discountType":"percent","discountValue":"10"}',
    });
    expect(pct.discount, 0);
  });

  test('walk-in cash sale: paid, POS flags, no party, idempotency key', () async {
    await repo.sell(
      clientSaleId: 'sale-1',
      session: session,
      lines: [CartLine(product: _p('a', 99.6))],
      tenders: [Tender(mode: 'cash', amount: 100)],
    );
    final b = api.body!;
    expect(api.path, '/invoices');
    expect(api.headers?['Idempotency-Key'], 'sale-1');
    expect(b['client_sale_id'], 'sale-1');
    expect(b.containsKey('party_id'), isFalse, reason: 'server picks the walk-in customer');
    expect(b['is_pos'], isTrue);
    expect(b['pos_session_id'], 'ps1');
    expect(b['session_opening_cash'], 1500);
    expect(b['status'], 'paid');
    expect(b['payment_mode'], 'cash');
    expect(b['amount_paid'], 100, reason: 'capped at the rounded total');
    expect(b['bank_account_id'], isNull);
    expect((b['items'] as List).single['product_id'], 'a');
  });

  test('split sale with credit balance for a customer', () async {
    await repo.sell(
      clientSaleId: 'sale-2',
      session: session,
      lines: [CartLine(product: _p('a', 500), quantity: 2)],
      tenders: [Tender(mode: 'cash', amount: 300), Tender(mode: 'upi', amount: 400, bankAccountId: 'b1'), Tender(mode: 'card', amount: 0)],
      party: const Party(id: 'p1', name: 'Ravi'),
      discount: 50,
    );
    final b = api.body!;
    expect(b['party_id'], 'p1');
    expect(b['status'], 'sent', reason: '950 billed, 700 paid');
    expect(b['amount_paid'], 700);
    expect(b['bank_account_id'], 'b1');
    expect(b['invoice_discount'], 50);
    final splits = b['payment_splits'] as List;
    expect(splits, hasLength(2), reason: 'zero tenders dropped');
    expect(splits.first['bank_account_id'], isNull);
  });

  test('no active session is a 404, not an error', () async {
    api.getError = ApiException('Not found.', statusCode: 404);
    expect(await repo.activeSession(), isNull);
    api.getError = ApiException('boom', statusCode: 500);
    expect(repo.activeSession(), throwsA(isA<ApiException>()));
  });
}
