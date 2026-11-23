import '../api/json.dart';
import 'party.dart';

class InvoiceItem {
  const InvoiceItem({
    this.id = '',
    this.productId,
    required this.description,
    this.quantity = 1,
    this.unit = '',
    this.unitPrice = 0,
    this.discount = 0,
    this.taxRate = 0,
    this.hsnCode = '',
    this.total = 0,
  });

  /// Line id — returns and credit notes reference it.
  final String id;
  final String? productId;
  final String description;
  final double quantity;
  final String unit;
  final double unitPrice;

  /// Percentage discount on the line.
  final double discount;
  final double taxRate;
  final String hsnCode;

  /// Server-computed line total (read-only).
  final double total;

  factory InvoiceItem.fromJson(JsonMap j) => InvoiceItem(
        id: asString(j['id']),
        productId: asStringOrNull(j['product_id']),
        description: asStringOrNull(j['description']) ?? asString(pick(j, 'product.name')),
        quantity: asDouble(j['quantity'], 1),
        unit: asString(j['unit']),
        unitPrice: asDouble(j['unit_price']),
        discount: asDouble(j['discount']),
        taxRate: asDouble(j['tax_rate']),
        hsnCode: asString(j['hsn_code']),
        total: asDouble(j['total']),
      );
}

class PaymentSplit {
  const PaymentSplit({required this.mode, required this.amount, this.bankAccountId});
  final String mode;
  final double amount;
  final String? bankAccountId;

  factory PaymentSplit.fromJson(JsonMap j) => PaymentSplit(
        mode: asString(j['mode']),
        amount: asDouble(j['amount']),
        bankAccountId: asStringOrNull(j['bank_account_id']),
      );

  JsonMap toJson() => {'mode': mode, 'amount': amount, 'bank_account_id': bankAccountId};
}

class Invoice {
  const Invoice({
    required this.id,
    required this.number,
    required this.status,
    required this.date,
    required this.party,
    required this.partyId,
    this.dueDate,
    this.items = const [],
    this.subTotal = 0,
    this.discountTotal = 0,
    this.invoiceDiscount = 0,
    this.additionalCharges = 0,
    this.taxTotal = 0,
    this.roundOff = 0,
    this.totalAmount = 0,
    this.amountPaid = 0,
    this.loyaltyDiscount = 0,
    this.paymentMode = '',
    this.paymentSplits = const [],
    this.notes = '',
    this.terms = '',
    this.cancelReason = '',
    this.isPos = false,
    this.createdAt,
  });

  final String id;
  final String number;
  final String status;
  final DateTime? date;
  final DateTime? dueDate;
  final Party? party;
  final String partyId;
  final List<InvoiceItem> items;
  final double subTotal;
  final double discountTotal;
  final double invoiceDiscount;
  final double additionalCharges;
  final double taxTotal;
  final double roundOff;
  final double totalAmount;
  final double amountPaid;
  final double loyaltyDiscount;
  final String paymentMode;
  final List<PaymentSplit> paymentSplits;
  final String notes;
  final String terms;
  final String cancelReason;
  final bool isPos;
  final DateTime? createdAt;

  double get balanceDue => status == 'cancelled' ? 0 : (totalAmount - amountPaid).clamp(0, double.infinity);
  bool get isCancelled => status == 'cancelled';
  bool get isPaid => status == 'paid';
  String get partyName => party?.name ?? 'Walk-in customer';

  factory Invoice.fromJson(JsonMap j) {
    final party = asMap(j['party']);
    return Invoice(
      id: asString(j['id']),
      number: asString(j['invoice_number']),
      status: asString(j['status'], 'draft'),
      date: asDate(j['date']),
      dueDate: asDate(j['due_date']),
      party: asString(party['id']).isEmpty ? null : Party.fromJson(party),
      partyId: asString(j['party_id']),
      items: asMapList(j['items']).map(InvoiceItem.fromJson).toList(),
      subTotal: asDouble(j['sub_total']),
      discountTotal: asDouble(j['discount_total']),
      invoiceDiscount: asDouble(j['invoice_discount']),
      additionalCharges: asDouble(j['additional_charges']),
      taxTotal: asDouble(j['tax_total']),
      roundOff: asDouble(j['round_off']),
      totalAmount: asDouble(j['total_amount']),
      amountPaid: asDouble(j['amount_paid']),
      loyaltyDiscount: asDouble(j['loyalty_discount']),
      paymentMode: asString(j['payment_mode']),
      paymentSplits: asMapList(j['payment_splits']).map(PaymentSplit.fromJson).toList(),
      notes: asString(j['notes']),
      terms: asString(j['terms']),
      cancelReason: asString(j['cancel_reason']),
      isPos: asBool(j['is_pos']),
      createdAt: asDate(j['created_at']),
    );
  }
}

class InvoiceStats {
  const InvoiceStats({this.totalSales = 0, this.paid = 0, this.unpaid = 0, this.cancelled = 0});
  final double totalSales;
  final double paid;
  final double unpaid;
  final double cancelled;

  factory InvoiceStats.fromJson(JsonMap j) => InvoiceStats(
        totalSales: asDouble(j['total_sales']),
        paid: asDouble(j['paid']),
        unpaid: asDouble(j['unpaid']),
        cancelled: asDouble(j['cancelled']),
      );
}

class StatusHistoryEntry {
  const StatusHistoryEntry({required this.from, required this.to, required this.note, required this.by, required this.at});
  final String from;
  final String to;
  final String note;
  final String by;
  final DateTime? at;

  factory StatusHistoryEntry.fromJson(JsonMap j) => StatusHistoryEntry(
        from: asString(j['from_status']),
        to: asString(j['to_status']),
        note: asString(j['note']),
        by: asString(j['changed_by']),
        at: asDate(j['created_at']),
      );
}
