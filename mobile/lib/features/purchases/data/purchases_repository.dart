import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/json.dart';
import '../../../core/api/paged.dart';
import '../../../core/api/revision.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/models/line_item.dart';
import '../../../core/models/purchase.dart';
import 'purchase_math.dart';

class PurchaseBillDraft {
  PurchaseBillDraft({
    required this.partyId,
    required this.number,
    required this.date,
    required this.lines,
    this.dueDate,
    this.billDiscount = 0,
    this.charges = 0,
    this.taxExempt = false,
    this.roundOff = true,
    this.amountPaid = 0,
    this.paymentMode = 'cash',
    this.bankAccountId,
    this.notes = '',
  });

  String partyId;
  String number;
  DateTime date;
  DateTime? dueDate;
  List<LineItem> lines;
  double billDiscount;
  double charges;
  bool taxExempt;
  bool roundOff;
  double amountPaid;
  String paymentMode;
  String? bankAccountId;
  String notes;

  PurchaseTotals get totals => PurchaseTotals.compute(lines,
      billDiscount: billDiscount, charges: charges, taxExempt: taxExempt, roundOff: roundOff);

  /// Same shape as the web purchase form's payload.
  JsonMap toJson({required String clientBillId}) {
    final total = totals.total;
    final unpaid = paymentMode == 'unpaid' || amountPaid <= 0;
    final paid = unpaid ? 0.0 : amountPaid.clamp(0, total).toDouble();
    final mode = unpaid ? 'unpaid' : paymentMode;
    final bank = unpaid || mode == 'cash' ? null : bankAccountId;
    return {
      'party_id': partyId,
      'bill_number': number.trim().isEmpty ? 'PINV-${DateTime.now().millisecondsSinceEpoch}' : number.trim(),
      'bill_date': date.toUtc().toIso8601String(),
      'due_date': dueDate?.toUtc().toIso8601String(),
      'warehouse_id': null,
      'total_amount': total,
      'paid_amount': paid,
      'balance_due': (total - paid).clamp(0, double.infinity),
      'payment_mode': mode,
      'bank_account_id': bank,
      'payment_splits': [
        {'mode': mode, 'amount': paid, 'bank_account_id': bank}
      ],
      'status': purchaseStatusFor(paid, total),
      'notes': notes.trim(),
      'tax_exempt': taxExempt,
      'invoice_discount': billDiscount,
      'additional_charges': charges,
      'client_bill_id': clientBillId,
      'items': lines.map((l) => l.toPurchaseJson(taxExempt: taxExempt)).toList(),
    };
  }
}

class PurchasesRepository {
  PurchasesRepository(this._api);
  final ApiClient _api;

  // ── Bills ────────────────────────────────────────────────────────────
  Future<Paged<PurchaseBill>> bills({
    int page = 1,
    String? search,
    String? status,
    String? partyId,
    DateTime? from,
    DateTime? to,
  }) =>
      _api.getPaged('/purchase/bills', PurchaseBill.fromJson, key: 'bills', page: page, query: {
        'search': search,
        'status': status,
        'party_id': partyId,
        'from_date': from == null ? null : ymd(from),
        'to_date': to == null ? null : ymd(to),
      });

  Future<PurchaseStats> stats() async => PurchaseStats.fromJson(await _api.getMap('/purchase/bills/stats'));

  Future<PurchaseBill> bill(String id) async => PurchaseBill.fromJson(await _api.getMap('/purchase/bills/$id'));

  /// Idempotent: one client_bill_id per form, also sent as Idempotency-Key.
  Future<PurchaseBill> createBill(PurchaseBillDraft d, {required String clientBillId}) async => PurchaseBill.fromJson(
      asMap(await _api.post('/purchase/bills',
          body: d.toJson(clientBillId: clientBillId), headers: {'Idempotency-Key': clientBillId})));

  Future<void> deleteBill(String id) => _api.delete('/purchase/bills/$id');

  // ── Returns ──────────────────────────────────────────────────────────
  Future<Paged<PurchaseReturn>> returns({int page = 1, String? status}) =>
      _api.getPaged('/purchase-returns', PurchaseReturn.fromJson, key: 'data', page: page, query: {'status': status});

  Future<PurchaseReturn> purchaseReturn(String id) async =>
      PurchaseReturn.fromJson(await _api.getMap('/purchase-returns/$id'));

  Future<PurchaseReturn> createReturn({
    required PurchaseBill bill,
    required Map<String, double> qtyByLineId,
    required DateTime date,
    required String refundMode,
    String reason = '',
    String notes = '',
  }) async {
    final items = [
      for (final l in bill.items)
        if ((qtyByLineId[l.id] ?? 0) > 0)
          {
            'purchase_bill_item_id': l.id,
            if (l.productId != null) 'product_id': l.productId,
            'description': l.description,
            'quantity': qtyByLineId[l.id],
            // Return at the effective (post-discount) unit price.
            'unit_price': l.unitPrice * (1 - l.discount / 100),
            'tax_rate': bill.taxExempt ? 0 : l.taxRate,
          }
    ];
    return PurchaseReturn.fromJson(asMap(await _api.post('/purchase-returns', body: {
      'party_id': bill.partyId,
      'purchase_bill_id': bill.id,
      'date': ymd(date),
      'reason': reason.trim(),
      'refund_mode': refundMode,
      'notes': notes.trim(),
      'items': items,
    })));
  }

  Future<PurchaseReturn> processReturn(String id) async =>
      PurchaseReturn.fromJson(asMap(await _api.post('/purchase-returns/$id/process')));

  Future<void> deleteReturn(String id) => _api.delete('/purchase-returns/$id');

  // ── Orders ───────────────────────────────────────────────────────────
  Future<Paged<PurchaseOrder>> orders({int page = 1, String? status}) =>
      _api.getPaged('/purchase/orders', PurchaseOrder.fromJson, key: 'data', page: page, query: {'status': status});

  Future<PurchaseOrder> order(String id) async => PurchaseOrder.fromJson(await _api.getMap('/purchase/orders/$id'));

  Future<PurchaseOrder> createOrder({
    required String partyId,
    required DateTime date,
    DateTime? expected,
    required List<LineItem> lines,
    String notes = '',
    String terms = '',
  }) async =>
      PurchaseOrder.fromJson(asMap(await _api.post('/purchase/orders', body: {
        'party_id': partyId,
        'order_date': date.toUtc().toIso8601String(),
        'expected_date': expected?.toUtc().toIso8601String(),
        'notes': notes.trim(),
        'terms': terms.trim(),
        'items': lines.map((l) => l.toOrderJson()).toList(),
      })));

  Future<void> submitOrder(String id) => _api.post('/purchase/orders/$id/submit');

  Future<void> deleteOrder(String id) => _api.delete('/purchase/orders/$id');

  static String newClientId() => const Uuid().v4();
}

final purchasesRepositoryProvider = Provider((ref) => PurchasesRepository(ref.watch(apiClientProvider)));

final purchaseBillProvider = FutureProvider.autoDispose.family<PurchaseBill, String>((ref, id) {
  ref.watch(activeStoreIdProvider);
  ref.watch(dataRevisionProvider);
  return ref.watch(purchasesRepositoryProvider).bill(id);
});

final purchaseStatsProvider = FutureProvider.autoDispose<PurchaseStats>((ref) {
  ref.watch(activeStoreIdProvider);
  ref.watch(dataRevisionProvider);
  return ref.watch(purchasesRepositoryProvider).stats();
});

final purchaseReturnProvider = FutureProvider.autoDispose.family<PurchaseReturn, String>((ref, id) {
  ref.watch(dataRevisionProvider);
  return ref.watch(purchasesRepositoryProvider).purchaseReturn(id);
});

final purchaseOrderProvider = FutureProvider.autoDispose.family<PurchaseOrder, String>((ref, id) {
  ref.watch(dataRevisionProvider);
  return ref.watch(purchasesRepositoryProvider).order(id);
});
