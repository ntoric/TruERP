import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/json.dart';
import '../../../core/api/paged.dart';
import '../../../core/api/revision.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/models/invoice.dart';
import '../../../core/models/purchase.dart';
import '../../../core/models/sales_docs.dart';
import '../../invoices/data/invoice_math.dart';

/// Estimate create/edit body. Totals follow the invoice rule (tax-free).
class QuotationDraft {
  QuotationDraft({
    required this.partyId,
    required this.date,
    required this.lines,
    this.number = '',
    this.validUntil,
    this.discount = 0,
    this.charges = 0,
    this.notes = '',
    this.terms = '',
  });

  String partyId;
  String number;
  DateTime date;
  DateTime? validUntil;
  List<LineItem> lines;
  double discount;
  double charges;
  String notes;
  String terms;

  InvoiceTotals get totals => InvoiceTotals.compute(
    lines,
    invoiceDiscount: discount,
    additionalCharges: charges,
  );

  /// [existing] carries the fields the backend overwrites on update but the
  /// mobile form doesn't edit (signature, place of supply, reverse charge…).
  JsonMap toJson({Quotation? existing}) => {
    'quotation_number': number.trim(),
    'party_id': partyId,
    'date': apiDate(date),
    'valid_until': apiDateOrNull(validUntil),
    'payment_terms': existing?.paymentTerms ?? 0,
    'notes': notes.trim(),
    'terms': terms.trim(),
    'is_inter_state': existing?.isInterState ?? false,
    'place_of_supply': existing?.placeOfSupply ?? '',
    'reverse_charge': existing?.reverseCharge ?? false,
    'signature': existing?.signature ?? '',
    'quotation_discount': discount,
    'additional_charges': charges,
    // Omitted on purpose: the backend keeps itemised charges when absent.
    'items': lines.map((l) => l.toInvoiceJson()).toList(),
  };
}

class SalesDocsRepository {
  SalesDocsRepository(this._api);
  final ApiClient _api;

  // ── Estimates ────────────────────────────────────────────────────────
  Future<Paged<Quotation>> quotations({
    int page = 1,
    String? status,
    String? partyId,
  }) => _api.getPaged(
    '/quotations',
    Quotation.fromJson,
    page: page,
    query: {'status': status, 'party_id': partyId},
  );

  Future<Quotation> quotation(String id) async =>
      Quotation.fromJson(await _api.getMap('/quotations/$id'));

  Future<String> nextQuotationNumber() async => asString(
    (await _api.getMap('/quotations/next-number'))['quotation_number'],
  );

  Future<Quotation> createQuotation(QuotationDraft d) async =>
      Quotation.fromJson(
        asMap(await _api.post('/quotations', body: d.toJson())),
      );

  Future<Quotation> updateQuotation(
    Quotation existing,
    QuotationDraft d,
  ) async => Quotation.fromJson(
    asMap(
      await _api.put(
        '/quotations/${existing.id}',
        body: d.toJson(existing: existing),
      ),
    ),
  );

  Future<void> sendQuotation(String id) => _api.post('/quotations/$id/send');
  Future<void> acceptQuotation(String id) =>
      _api.post('/quotations/$id/accept');
  Future<void> rejectQuotation(String id, String reason) =>
      _api.post('/quotations/$id/reject', body: {'reason': reason.trim()});
  Future<void> deleteQuotation(String id) => _api.delete('/quotations/$id');

  /// Creates an invoice from the estimate; returns the new invoice.
  Future<Invoice> convertQuotation(
    String id, {
    String mode = 'unpaid',
    double amountPaid = 0,
    String? bankAccountId,
  }) async {
    final paid = mode == 'unpaid' ? 0.0 : amountPaid;
    return Invoice.fromJson(
      asMap(
        await _api.post(
          '/quotations/$id/convert',
          body: {
            'payment_mode': paid > 0 ? mode : 'unpaid',
            'amount_paid': paid,
            'bank_account_id': mode == 'cash' || paid <= 0
                ? null
                : bankAccountId,
            'payment_splits': paid > 0
                ? [
                    {
                      'mode': mode,
                      'amount': paid,
                      'bank_account_id': mode == 'cash' ? null : bankAccountId,
                    },
                  ]
                : [],
          },
        ),
      ),
    );
  }

  // ── Delivery challans ────────────────────────────────────────────────
  Future<Paged<DeliveryChallan>> challans({int page = 1, String? status}) =>
      _api.getPaged(
        '/delivery-challans',
        DeliveryChallan.fromJson,
        page: page,
        query: {'status': status},
      );

  Future<DeliveryChallan> challan(String id) async =>
      DeliveryChallan.fromJson(await _api.getMap('/delivery-challans/$id'));

  Future<String> nextChallanNumber() async => asString(
    (await _api.getMap('/delivery-challans/next-number'))['challan_number'],
  );

  Future<DeliveryChallan> createChallan({
    required String number,
    required String partyId,
    required DateTime date,
    required List<LineItem> lines,
    DateTime? dueDate,
    String? invoiceId,
    String vehicleNumber = '',
    String transportMode = 'road',
    String notes = '',
  }) async => DeliveryChallan.fromJson(
    asMap(
      await _api.post(
        '/delivery-challans',
        body: {
          'challan_number': number.trim(),
          'party_id': partyId,
          'invoice_id': invoiceId,
          'date': apiDate(date),
          'due_date': apiDateOrNull(dueDate),
          'status': 'draft',
          'notes': notes.trim(),
          'vehicle_number': vehicleNumber.trim().toUpperCase(),
          'transport_mode': transportMode,
          'items': [
            for (final l in lines)
              {
                'description': l.description.trim(),
                'quantity': l.quantity,
                'unit': l.unit,
                'unit_price': l.unitPrice,
                'batch_no': '',
              },
          ],
        },
      ),
    ),
  );

  /// Status change; every header field is resent because the backend overwrites them.
  Future<void> setChallanStatus(DeliveryChallan c, String status) => _api.put(
    '/delivery-challans/${c.id}',
    body: c.headerJson(status: status),
  );

  Future<void> deleteChallan(String id) =>
      _api.delete('/delivery-challans/$id');

  // ── Sales returns ────────────────────────────────────────────────────
  Future<Paged<ReturnDoc>> salesReturns({int page = 1, String? status}) =>
      _api.getPaged(
        '/sales-returns',
        ReturnDoc.salesReturn,
        key: 'data',
        page: page,
        query: {'status': status},
      );

  Future<ReturnDoc> salesReturn(String id) async =>
      ReturnDoc.salesReturn(await _api.getMap('/sales-returns/$id'));

  Future<ReturnDoc> createSalesReturn({
    required Invoice invoice,
    required Map<String, double> qtyByItemId,
    required DateTime date,
    required String refundMode,
    String? settleInvoiceId,
    String reason = '',
    String notes = '',
  }) async => ReturnDoc.salesReturn(
    asMap(
      await _api.post(
        '/sales-returns',
        body: {
          'party_id': invoice.partyId,
          'invoice_id': invoice.id,
          'settle_invoice_id': refundMode == 'credit_note'
              ? settleInvoiceId
              : null,
          'date': apiDate(date),
          'reason': reason.trim(),
          'refund_mode': refundMode,
          'notes': notes.trim(),
          'items': _invoiceLines(invoice, qtyByItemId),
        },
      ),
    ),
  );

  Future<void> processSalesReturn(String id) =>
      _api.post('/sales-returns/$id/process');
  Future<void> deleteSalesReturn(String id) =>
      _api.delete('/sales-returns/$id');

  // ── Credit notes ─────────────────────────────────────────────────────
  Future<Paged<ReturnDoc>> creditNotes({int page = 1, String? status}) =>
      _api.getPaged(
        '/credit-notes',
        ReturnDoc.creditNote,
        key: 'data',
        page: page,
        query: {'status': status},
      );

  Future<ReturnDoc> creditNote(String id) async =>
      ReturnDoc.creditNote(await _api.getMap('/credit-notes/$id'));

  Future<ReturnDoc> createCreditNote({
    required Invoice invoice,
    required Map<String, double> qtyByItemId,
    required DateTime date,
    required String refundMode,
    String reason = '',
  }) async => ReturnDoc.creditNote(
    asMap(
      await _api.post(
        '/credit-notes',
        body: {
          'invoice_id': invoice.id,
          'date': apiDate(date),
          'reason': reason.trim(),
          'refund_mode': refundMode,
          'items': _invoiceLines(invoice, qtyByItemId),
        },
      ),
    ),
  );

  Future<void> issueCreditNote(String id) =>
      _api.post('/credit-notes/$id/issue');
  Future<void> cancelCreditNote(String id, String reason) =>
      _api.post('/credit-notes/$id/cancel', body: {'reason': reason.trim()});

  // ── Debit notes ──────────────────────────────────────────────────────
  Future<Paged<ReturnDoc>> debitNotes({int page = 1, String? status}) =>
      _api.getPaged(
        '/debit-notes',
        ReturnDoc.debitNote,
        key: 'data',
        page: page,
        query: {'status': status},
      );

  Future<ReturnDoc> debitNote(String id) async =>
      ReturnDoc.debitNote(await _api.getMap('/debit-notes/$id'));

  Future<ReturnDoc> createDebitNote({
    required PurchaseBill bill,
    required Map<String, double> qtyByItemId,
    required DateTime date,
    required String refundMode,
    String reason = '',
  }) async => ReturnDoc.debitNote(
    asMap(
      await _api.post(
        '/debit-notes',
        body: {
          'purchase_bill_id': bill.id,
          'date': apiDate(date),
          'reason': reason.trim(),
          'refund_mode': refundMode,
          'items': [
            for (final l in bill.items)
              if ((qtyByItemId[l.id] ?? 0) > 0)
                {
                  'purchase_bill_item_id': l.id,
                  'description': l.description,
                  'quantity': qtyByItemId[l.id],
                  // Price actually paid (after the line discount).
                  'unit_price': l.unitPrice * (1 - l.discount / 100),
                  'tax_rate': l.taxRate,
                  'reason': reason.trim(),
                },
          ],
        },
      ),
    ),
  );

  Future<void> issueDebitNote(String id) => _api.post('/debit-notes/$id/issue');
  Future<void> cancelDebitNote(String id, String reason) =>
      _api.post('/debit-notes/$id/cancel', body: {'reason': reason.trim()});

  // ── Discount log ─────────────────────────────────────────────────────
  Future<Paged<DiscountTxn>> discounts({
    int page = 1,
    String? type,
    String? search,
  }) => _api.getPaged(
    '/discounts/transactions',
    DiscountTxn.fromJson,
    key: 'transactions',
    page: page,
    query: {'type': type, 'search': search},
  );

  Future<double> discountTotal({String? type, String? search}) async =>
      asDouble(
        pick(
          await _api.getMap(
            '/discounts/transactions',
            query: {'type': type, 'search': search, 'page': 1, 'per_page': 1},
          ),
          'summary.total_discount',
        ),
      );

  /// Invoice lines being returned/credited, at the price actually charged.
  static List<JsonMap> _invoiceLines(
    Invoice invoice,
    Map<String, double> qtyByItemId,
  ) => [
    for (final l in invoice.items)
      if (l.id.isNotEmpty && (qtyByItemId[l.id] ?? 0) > 0)
        {
          'invoice_item_id': l.id,
          if (l.productId != null) 'product_id': l.productId,
          'description': l.description,
          'quantity': qtyByItemId[l.id],
          'unit_price': l.unitPrice * (1 - l.discount / 100),
          'tax_rate': l.taxRate,
        },
  ];
}

final salesDocsRepositoryProvider = Provider(
  (ref) => SalesDocsRepository(ref.watch(apiClientProvider)),
);

final quotationProvider = FutureProvider.autoDispose.family<Quotation, String>((
  ref,
  id,
) {
  ref.watch(activeStoreIdProvider);
  ref.watch(dataRevisionProvider);
  return ref.watch(salesDocsRepositoryProvider).quotation(id);
});

final challanProvider = FutureProvider.autoDispose
    .family<DeliveryChallan, String>((ref, id) {
      ref.watch(activeStoreIdProvider);
      ref.watch(dataRevisionProvider);
      return ref.watch(salesDocsRepositoryProvider).challan(id);
    });

/// kind: sales-return | credit-note | debit-note
final returnDocProvider = FutureProvider.autoDispose
    .family<ReturnDoc, (String, String)>((ref, k) {
      ref.watch(activeStoreIdProvider);
      ref.watch(dataRevisionProvider);
      final repo = ref.watch(salesDocsRepositoryProvider);
      return switch (k.$1) {
        'sales-return' => repo.salesReturn(k.$2),
        'credit-note' => repo.creditNote(k.$2),
        _ => repo.debitNote(k.$2),
      };
    });
