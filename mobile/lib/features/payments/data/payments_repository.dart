import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/json.dart';
import '../../../core/api/paged.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/models/payment.dart';
import '../../../core/models/purchase.dart';

class PaymentInDraft {
  PaymentInDraft({
    required this.partyId,
    required this.amount,
    required this.date,
    this.mode = 'cash',
    this.invoiceId,
    this.bankAccountId,
    this.discount = 0,
    this.number = '',
    this.reference = '',
    this.notes = '',
  });

  String partyId;
  double amount;
  DateTime date;
  String mode;
  String? invoiceId;
  String? bankAccountId;
  double discount;
  String number;
  String reference;
  String notes;

  JsonMap toJson() => {
    'party_id': partyId,
    if (invoiceId != null) 'invoice_id': invoiceId,
    'amount_received': amount,
    'payment_in_discount': discount,
    'payment_in_number': number.trim(),
    'mode': mode,
    // Cash never goes to a bank account.
    'bank_account_id': mode == 'cash' ? null : bankAccountId,
    'date': apiDate(date),
    'reference': reference.trim(),
    'notes': notes.trim(),
  };
}

class PaymentOutDraft {
  PaymentOutDraft({
    required this.partyId,
    required this.amount,
    required this.date,
    this.mode = 'cash',
    this.purchaseBillId,
    this.bankAccountId,
    this.discount = 0,
    this.reference = '',
    this.notes = '',
  });

  String partyId;
  double amount;
  DateTime date;
  String mode;
  String? purchaseBillId;
  String? bankAccountId;
  double discount;
  String reference;
  String notes;

  JsonMap toJson() => {
    'party_id': partyId,
    if (purchaseBillId != null) 'purchase_bill_id': purchaseBillId,
    'amount_paid': amount,
    'payment_out_discount': discount,
    'mode': mode,
    'bank_account_id': mode == 'cash' ? null : bankAccountId,
    'date': apiDate(date),
    'reference': reference.trim(),
    'notes': notes.trim(),
  };
}

class PaymentsRepository {
  PaymentsRepository(this._api);
  final ApiClient _api;

  Future<Paged<PaymentIn>> list({
    int page = 1,
    String? search,
    String? partyId,
    String? invoiceId,
    String? mode,
    String? status,
  }) => _api.getPaged(
    '/payments',
    PaymentIn.fromJson,
    key: 'payments',
    page: page,
    query: {
      'search': search,
      'party_id': partyId,
      'invoice_id': invoiceId,
      'mode': mode,
      'status': status,
    },
  );

  Future<String> nextNumber() async => asString(
    (await _api.getMap('/payments/next-number'))['payment_in_number'],
  );

  Future<PaymentIn> create(PaymentInDraft d) async =>
      PaymentIn.fromJson(asMap(await _api.post('/payments', body: d.toJson())));

  Future<void> cancel(String id, String reason) =>
      _api.post('/payments/$id/cancel', body: {'reason': reason.trim()});

  Future<Paged<PaymentOut>> listOut({
    int page = 1,
    String? search,
    String? partyId,
    String? purchaseBillId,
    String? mode,
  }) => _api.getPaged(
    '/payment-outs',
    PaymentOut.fromJson,
    key: 'payment_outs',
    page: page,
    query: {
      'search': search,
      'party_id': partyId,
      'purchase_bill_id': purchaseBillId,
      'mode': mode,
    },
  );

  Future<PaymentOut> createOut(PaymentOutDraft d) async => PaymentOut.fromJson(
    asMap(await _api.post('/payment-outs', body: d.toJson())),
  );

  Future<void> cancelOut(String id, String reason) =>
      _api.post('/payment-outs/$id/cancel', body: {'reason': reason.trim()});

  Future<List<BankAccount>> bankAccounts() async {
    final res = await _api.get('/cash-bank/accounts');
    final rows = res is List
        ? asMapList(res)
        : asMapList(asMap(res)['data'] ?? asMap(res)['accounts']);
    return rows.map(BankAccount.fromJson).where((a) => a.isActive).toList();
  }
}

final paymentsRepositoryProvider = Provider(
  (ref) => PaymentsRepository(ref.watch(apiClientProvider)),
);

final bankAccountsProvider = FutureProvider.autoDispose<List<BankAccount>>((
  ref,
) {
  ref.watch(activeStoreIdProvider);
  return ref.watch(paymentsRepositoryProvider).bankAccounts();
});
