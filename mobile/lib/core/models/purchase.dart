import '../api/json.dart';
import 'party.dart';
import 'payment.dart';

Party? _party(JsonMap j) {
  final p = asMap(j['party']);
  return asString(p['id']).isEmpty ? null : Party.fromJson(p);
}

/// A saved line on a purchase bill, return or order (read-only view).
class DocLine {
  const DocLine({
    required this.description,
    this.id = '',
    this.productId,
    this.quantity = 0,
    this.receivedQty = 0,
    this.unit = '',
    this.unitPrice = 0,
    this.discount = 0,
    this.taxRate = 0,
    this.taxAmount = 0,
    this.total = 0,
  });

  final String id;
  final String? productId;
  final String description;
  final double quantity;
  final double receivedQty;
  final String unit;
  final double unitPrice;
  final double discount;
  final double taxRate;
  final double taxAmount;
  final double total;

  factory DocLine.fromJson(JsonMap j) => DocLine(
        id: asString(j['id']),
        productId: asStringOrNull(j['product_id']),
        description: asStringOrNull(j['description']) ?? asString(pick(j, 'product.name'), 'Item'),
        quantity: asDouble(j['quantity']),
        receivedQty: asDouble(j['received_qty']),
        unit: asString(j['unit']),
        unitPrice: asDouble(j['unit_price']),
        discount: asDouble(j['discount']),
        taxRate: asDouble(j['tax_rate']),
        taxAmount: asDouble(j['tax_amount']),
        total: asDouble(j['total']),
      );
}

class PurchaseBill {
  const PurchaseBill({
    required this.id,
    required this.number,
    required this.status,
    required this.date,
    required this.partyId,
    this.party,
    this.dueDate,
    this.stockStatus = 'none',
    this.items = const [],
    this.subTotal = 0,
    this.taxTotal = 0,
    this.invoiceDiscount = 0,
    this.additionalCharges = 0,
    this.totalAmount = 0,
    this.paidAmount = 0,
    this.balanceDue = 0,
    this.paymentMode = '',
    this.taxExempt = false,
    this.notes = '',
  });

  final String id;
  final String number;
  final String status;
  final DateTime? date;
  final DateTime? dueDate;
  final String partyId;
  final Party? party;
  final String stockStatus;
  final List<DocLine> items;
  final double subTotal;
  final double taxTotal;
  final double invoiceDiscount;
  final double additionalCharges;
  final double totalAmount;
  final double paidAmount;
  final double balanceDue;
  final String paymentMode;
  final bool taxExempt;
  final String notes;

  String get vendorName => party?.name ?? 'Vendor';
  bool get isDraft => status == 'draft';
  double get lineDiscounts => items.fold(0, (s, l) => s + l.quantity * l.unitPrice * l.discount / 100);

  factory PurchaseBill.fromJson(JsonMap j) => PurchaseBill(
        id: asString(j['id']),
        number: asString(j['bill_number']),
        status: asString(j['status'], 'unpaid'),
        date: asDate(j['bill_date']),
        dueDate: asDate(j['due_date']),
        partyId: asString(j['party_id']),
        party: _party(j),
        stockStatus: asString(j['stock_status'], 'none'),
        items: asMapList(j['items']).map(DocLine.fromJson).toList(),
        subTotal: asDouble(j['sub_total']),
        taxTotal: asDouble(j['tax_total']),
        invoiceDiscount: asDouble(j['invoice_discount']),
        additionalCharges: asDouble(j['additional_charges']),
        totalAmount: asDouble(j['total_amount']),
        paidAmount: asDouble(j['paid_amount']),
        balanceDue: asDouble(j['balance_due']),
        paymentMode: asString(j['payment_mode']),
        taxExempt: asBool(j['tax_exempt']),
        notes: asString(j['notes']),
      );
}

class PurchaseStats {
  const PurchaseStats({this.total = 0, this.paid = 0, this.unpaid = 0});
  final double total;
  final double paid;
  final double unpaid;

  factory PurchaseStats.fromJson(JsonMap j) => PurchaseStats(
        total: asDouble(j['total_purchase']),
        paid: asDouble(j['paid']),
        unpaid: asDouble(j['unpaid']),
      );
}

/// Payment Out (money paid to a vendor, or a refund to a customer).
class PaymentOut {
  const PaymentOut({
    required this.id,
    required this.number,
    required this.amount,
    required this.mode,
    required this.date,
    this.party,
    this.discount = 0,
    this.purchaseBillId,
    this.purchaseBillNumber,
    this.reference = '',
    this.notes = '',
    this.status = 'active',
    this.cancelReason = '',
    this.bankAccountLabel,
  });

  final String id;
  final String number;
  final double amount;
  final double discount;
  final String mode;
  final DateTime? date;
  final Party? party;
  final String? purchaseBillId;
  final String? purchaseBillNumber;
  final String reference;
  final String notes;
  final String status;
  final String cancelReason;
  final String? bankAccountLabel;

  bool get isCancelled => status == 'cancelled';

  factory PaymentOut.fromJson(JsonMap j) {
    final bank = asMap(j['bank_account']);
    return PaymentOut(
      id: asString(j['id']),
      number: asString(j['payment_out_number']),
      amount: asDouble(j['amount_paid']),
      discount: asDouble(j['payment_out_discount']),
      mode: asString(j['mode']),
      date: asDate(j['date']),
      party: _party(j),
      purchaseBillId: asStringOrNull(j['purchase_bill_id']),
      purchaseBillNumber: asStringOrNull(pick(j, 'purchase_bill.bill_number')),
      reference: asString(j['reference']),
      notes: asString(j['notes']),
      status: asString(j['status'], 'active'),
      cancelReason: asString(j['cancel_reason']),
      bankAccountLabel: bank.isEmpty ? null : BankAccount.fromJson(bank).label,
    );
  }
}

class PurchaseReturn {
  const PurchaseReturn({
    required this.id,
    required this.number,
    required this.status,
    required this.date,
    required this.amount,
    this.party,
    this.partyId = '',
    this.purchaseBillId,
    this.purchaseBillNumber,
    this.reason = '',
    this.refundMode = '',
    this.notes = '',
    this.items = const [],
  });

  final String id;
  final String number;
  final String status;
  final DateTime? date;
  final double amount;
  final Party? party;
  final String partyId;
  final String? purchaseBillId;
  final String? purchaseBillNumber;
  final String reason;
  final String refundMode;
  final String notes;
  final List<DocLine> items;

  bool get isDraft => status == 'draft';

  factory PurchaseReturn.fromJson(JsonMap j) => PurchaseReturn(
        id: asString(j['id']),
        number: asString(j['return_number']),
        status: asString(j['status'], 'draft'),
        date: asDate(j['date']),
        amount: asDouble(j['amount']),
        party: _party(j),
        partyId: asString(j['party_id']),
        purchaseBillId: asStringOrNull(j['purchase_bill_id']),
        purchaseBillNumber: asStringOrNull(pick(j, 'purchase_bill.bill_number')),
        reason: asString(j['reason']),
        refundMode: asString(j['refund_mode']),
        notes: asString(j['notes']),
        items: asMapList(j['items']).map(DocLine.fromJson).toList(),
      );

  /// Refund modes offered by the web form.
  static const refundModes = <(String, String)>[
    ('cash', 'Cash'),
    ('bank', 'Bank'),
    ('upi', 'UPI'),
    ('credit_note', 'Debit note'),
  ];

  static String refundLabel(String mode) =>
      refundModes.where((m) => m.$1 == mode).map((m) => m.$2).firstOrNull ?? PaymentMode.labelOf(mode);
}

class PurchaseOrder {
  const PurchaseOrder({
    required this.id,
    required this.number,
    required this.status,
    required this.date,
    this.party,
    this.partyId = '',
    this.expectedDate,
    this.subTotal = 0,
    this.taxTotal = 0,
    this.totalAmount = 0,
    this.notes = '',
    this.terms = '',
    this.items = const [],
  });

  final String id;
  final String number;
  final String status;
  final DateTime? date;
  final DateTime? expectedDate;
  final Party? party;
  final String partyId;
  final double subTotal;
  final double taxTotal;
  final double totalAmount;
  final String notes;
  final String terms;
  final List<DocLine> items;

  bool get isDraft => status == 'draft';

  factory PurchaseOrder.fromJson(JsonMap j) => PurchaseOrder(
        id: asString(j['id']),
        number: asString(j['order_number']),
        status: asString(j['status'], 'draft'),
        date: asDate(j['order_date']),
        expectedDate: asDate(j['expected_date']),
        party: _party(j),
        partyId: asString(j['party_id']),
        subTotal: asDouble(j['sub_total']),
        taxTotal: asDouble(j['tax_total']),
        totalAmount: asDouble(j['total_amount']),
        notes: asString(j['notes']),
        terms: asString(j['terms']),
        items: asMapList(j['items']).map(DocLine.fromJson).toList(),
      );
}
