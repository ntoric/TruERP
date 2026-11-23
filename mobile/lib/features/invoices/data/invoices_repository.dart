import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/json.dart';
import '../../../core/api/paged.dart';
import '../../../core/api/revision.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/models/invoice.dart';
import 'invoice_math.dart';

/// Everything the create/edit form submits.
class InvoiceDraft {
  InvoiceDraft({
    required this.partyId,
    required this.date,
    required this.lines,
    this.number = '',
    this.dueDate,
    this.invoiceDiscount = 0,
    this.additionalCharges = 0,
    this.amountReceived = 0,
    this.paymentMode = 'cash',
    this.bankAccountId,
    this.notes = '',
    this.terms = '',
  });

  String partyId;
  String number;
  DateTime date;
  DateTime? dueDate;
  List<InvoiceLine> lines;
  double invoiceDiscount;
  double additionalCharges;
  double amountReceived;
  String paymentMode;
  String? bankAccountId;
  String notes;
  String terms;

  InvoiceTotals get totals =>
      InvoiceTotals.compute(lines, invoiceDiscount: invoiceDiscount, additionalCharges: additionalCharges);

  /// Same shape as the web SaleForm payload.
  JsonMap toJson({String? clientSaleId}) {
    final total = totals.total;
    final split = amountReceived > 0 && paymentMode != 'unpaid';
    // "Unpaid" wins over any leftover amount, so status and amount agree.
    final paid = split ? amountReceived.clamp(0, total).toDouble() : 0.0;
    return {
      if (clientSaleId != null) 'client_sale_id': clientSaleId,
      'invoice_number': number.trim(),
      'party_id': partyId,
      'customer_id': partyId,
      'date': date.toUtc().toIso8601String(),
      'due_date': dueDate?.toUtc().toIso8601String(),
      'payment_terms': dueDate == null ? 0 : dueDate!.difference(date).inDays.clamp(0, 3650),
      'status': total > 0 && paid + 0.01 >= total ? 'paid' : 'sent',
      'is_inter_state': false,
      'payment_mode': split ? paymentMode : 'unpaid',
      'amount_paid': paid,
      'bank_account_id': split ? bankAccountId : null,
      'payment_splits': split
          ? [
              {'mode': paymentMode, 'amount': paid, 'bank_account_id': bankAccountId}
            ]
          : [],
      'notes': notes.trim(),
      'terms': terms.trim(),
      'invoice_discount': invoiceDiscount,
      'additional_charges': additionalCharges,
      'items': lines.map((l) => l.toJson()).toList(),
    };
  }
}

class InvoicesRepository {
  InvoicesRepository(this._api);
  final ApiClient _api;
  static const _uuid = Uuid();

  Future<Paged<Invoice>> list({
    int page = 1,
    String? search,
    String? status,
    String? partyId,
    DateTime? from,
    DateTime? to,
  }) =>
      _api.getPaged('/invoices', Invoice.fromJson, key: 'invoices', page: page, query: {
        'search': search,
        'status': status,
        'party_id': partyId,
        'from': from == null ? null : ymd(from),
        'to': to == null ? null : ymd(to),
        'sort': 'date',
        'order': 'desc',
      });

  Future<InvoiceStats> stats() async => InvoiceStats.fromJson(await _api.getMap('/invoices/stats'));

  Future<Invoice> get(String id) async => Invoice.fromJson(await _api.getMap('/invoices/$id'));

  Future<String> nextNumber() async {
    final res = await _api.getMap('/invoices/next-number');
    return asString(res['invoice_number'] ?? res['next_number'] ?? res['number']);
  }

  /// Idempotent create: a fresh client_sale_id per submit attempt, so a
  /// retry after a dropped response returns the same invoice.
  Future<Invoice> create(InvoiceDraft d, {String? clientSaleId}) async {
    final id = clientSaleId ?? _uuid.v4();
    return Invoice.fromJson(asMap(await _api.post('/invoices',
        body: d.toJson(clientSaleId: id), headers: {'Idempotency-Key': id})));
  }

  // No update(): PUT /invoices/:id rewrites fields the mobile form doesn't
  // carry (custom fields, template, charge items, signature). Editing stays
  // on the web until the form round-trips all of them.

  Future<void> cancel(String id, String reason) =>
      _api.patch('/invoices/$id/status', body: {'status': 'cancelled', 'note': reason.trim()});

  Future<List<StatusHistoryEntry>> history(String id) async {
    final res = await _api.get('/invoices/$id/status-history');
    final rows = res is List ? asMapList(res) : asMapList(asMap(res)['history'] ?? asMap(res)['data']);
    return rows.map(StatusHistoryEntry.fromJson).toList();
  }

  Future<void> sendWhatsApp(String id, {String? phone}) =>
      _api.post('/invoices/$id/whatsapp', body: {if (phone != null) 'phone': phone});
}

final invoicesRepositoryProvider = Provider((ref) => InvoicesRepository(ref.watch(apiClientProvider)));

final invoiceProvider = FutureProvider.autoDispose.family<Invoice, String>((ref, id) {
  ref.watch(activeStoreIdProvider);
  ref.watch(dataRevisionProvider);
  return ref.watch(invoicesRepositoryProvider).get(id);
});

final invoiceStatsProvider = FutureProvider.autoDispose<InvoiceStats>((ref) {
  ref.watch(activeStoreIdProvider);
  return ref.watch(invoicesRepositoryProvider).stats();
});

final invoiceHistoryProvider = FutureProvider.autoDispose.family<List<StatusHistoryEntry>, String>((ref, id) {
  ref.watch(dataRevisionProvider);
  return ref.watch(invoicesRepositoryProvider).history(id);
});
