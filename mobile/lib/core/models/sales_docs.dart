import '../api/json.dart';
import 'party.dart';
import 'purchase.dart';

Party? _party(JsonMap j) {
  final p = asMap(j['party']);
  return asString(p['id']).isEmpty ? null : Party.fromJson(p);
}

/// Estimate / quotation. Status: draft, sent, accepted, rejected, expired, converted.
class Quotation {
  const Quotation({
    required this.id,
    required this.number,
    required this.status,
    required this.date,
    required this.partyId,
    this.party,
    this.validUntil,
    this.items = const [],
    this.subTotal = 0,
    this.discountTotal = 0,
    this.quotationDiscount = 0,
    this.additionalCharges = 0,
    this.hasChargeItems = false,
    this.roundOff = 0,
    this.totalAmount = 0,
    this.notes = '',
    this.terms = '',
    this.paymentTerms = 0,
    this.isInterState = false,
    this.placeOfSupply = '',
    this.reverseCharge = false,
    this.signature = '',
    this.convertedInvoiceId,
    this.version = 1,
  });

  final String id;
  final String number;
  final String status;
  final DateTime? date;
  final DateTime? validUntil;
  final String partyId;
  final Party? party;
  final List<DocLine> items;
  final double subTotal;
  final double discountTotal;
  final double quotationDiscount;
  final double additionalCharges;

  /// When the web added itemised charges, mobile keeps the charge amount fixed.
  final bool hasChargeItems;
  final double roundOff;
  final double totalAmount;
  final String notes;
  final String terms;

  // Round-tripped on edit: the backend overwrites these on every update.
  final int paymentTerms;
  final bool isInterState;
  final String placeOfSupply;
  final bool reverseCharge;
  final String signature;

  final String? convertedInvoiceId;
  final int version;

  String get partyName => party?.name ?? 'Customer';
  bool get isConverted => status == 'converted' || convertedInvoiceId != null;

  /// Server rule: accepted or converted estimates can't be edited.
  bool get canEdit => status != 'accepted' && !isConverted;

  bool get isExpired =>
      validUntil != null &&
      !isConverted &&
      status != 'accepted' &&
      validUntil!.isBefore(DateTime.now().subtract(const Duration(days: 1)));

  factory Quotation.fromJson(JsonMap j) => Quotation(
    id: asString(j['id']),
    number: asString(j['quotation_number']),
    status: asString(j['status'], 'draft'),
    date: asDate(j['date']),
    validUntil: asDate(j['valid_until']),
    partyId: asString(j['party_id']),
    party: _party(j),
    items: asMapList(j['items']).map(DocLine.fromJson).toList(),
    subTotal: asDouble(j['sub_total']),
    discountTotal: asDouble(j['discount_total']),
    quotationDiscount: asDouble(j['quotation_discount']),
    additionalCharges: asDouble(j['additional_charges']),
    hasChargeItems: asMapList(j['additional_charge_items']).isNotEmpty,
    roundOff: asDouble(j['round_off']),
    totalAmount: asDouble(j['total_amount']),
    notes: asString(j['notes']),
    terms: asString(j['terms']),
    paymentTerms: asInt(j['payment_terms']),
    isInterState: asBool(j['is_inter_state']),
    placeOfSupply: asString(j['place_of_supply']),
    reverseCharge: asBool(j['reverse_charge']),
    signature: asString(j['signature']),
    convertedInvoiceId: asStringOrNull(j['converted_to_invoice_id']),
    version: asInt(j['version'], 1),
  );
}

/// Delivery challan. Status: draft, delivered, cancelled.
class DeliveryChallan {
  const DeliveryChallan({
    required this.id,
    required this.number,
    required this.status,
    required this.date,
    required this.partyId,
    this.party,
    this.dueDate,
    this.invoiceId,
    this.invoiceNumber,
    this.items = const [],
    this.subTotal = 0,
    this.totalQuantity = 0,
    this.notes = '',
    this.terms = '',
    this.signature = '',
    this.vehicleNumber = '',
    this.transportMode = '',
  });

  final String id;
  final String number;
  final String status;
  final DateTime? date;
  final DateTime? dueDate;
  final String partyId;
  final Party? party;
  final String? invoiceId;
  final String? invoiceNumber;
  final List<DocLine> items;
  final double subTotal;
  final double totalQuantity;
  final String notes;
  final String terms;
  final String signature;
  final String vehicleNumber;
  final String transportMode;

  bool get isDraft => status == 'draft';

  factory DeliveryChallan.fromJson(JsonMap j) => DeliveryChallan(
    id: asString(j['id']),
    number: asString(j['challan_number']),
    status: asString(j['status'], 'draft'),
    date: asDate(j['date']),
    dueDate: asDate(j['due_date']),
    partyId: asString(j['party_id']),
    party: _party(j),
    invoiceId: asStringOrNull(j['invoice_id']),
    invoiceNumber: asStringOrNull(pick(j, 'invoice.invoice_number')),
    items: asMapList(j['items']).map(DocLine.fromJson).toList(),
    subTotal: asDouble(j['sub_total']),
    totalQuantity: asDouble(j['total_quantity']),
    notes: asString(j['notes']),
    terms: asString(j['terms']),
    signature: asString(j['signature']),
    vehicleNumber: asString(j['vehicle_number']),
    transportMode: asString(j['transport_mode']),
  );

  /// Header-only update body; the backend overwrites every one of these.
  JsonMap headerJson({String? status}) => {
    'status': status ?? this.status,
    'notes': notes,
    'terms': terms,
    'signature': signature,
    'vehicle_number': vehicleNumber,
    'transport_mode': transportMode,
    'due_date': apiDateOrNull(dueDate),
  };

  static const transportModes = [
    ('road', 'Road'),
    ('rail', 'Rail'),
    ('air', 'Air'),
    ('sea', 'Sea'),
  ];
}

/// Shared shape of sales returns, credit notes and debit notes.
class ReturnDoc {
  const ReturnDoc({
    required this.id,
    required this.number,
    required this.status,
    required this.date,
    required this.amount,
    this.party,
    this.partyId = '',
    this.sourceId,
    this.sourceNumber,
    this.reason = '',
    this.refundMode = '',
    this.notes = '',
    this.deductionTotal = 0,
    this.refundAmount = 0,
    this.cancelReason = '',
    this.items = const [],
  });

  final String id;
  final String number;

  /// draft | processed | issued | cancelled
  final String status;
  final DateTime? date;
  final double amount;
  final Party? party;
  final String partyId;

  /// The invoice (sales return, credit note) or bill (debit note) it came from.
  final String? sourceId;
  final String? sourceNumber;
  final String reason;
  final String refundMode;
  final String notes;
  final double deductionTotal;
  final double refundAmount;
  final String cancelReason;
  final List<DocLine> items;

  bool get isDraft => status == 'draft';
  bool get isCancelled => status == 'cancelled';
  String get partyName => party?.name ?? 'Party';

  factory ReturnDoc.salesReturn(JsonMap j) => ReturnDoc(
    id: asString(j['id']),
    number: asString(j['return_number']),
    status: asString(j['status'], 'draft'),
    date: asDate(j['date']),
    amount: asDouble(j['amount']),
    party: _party(j),
    partyId: asString(j['party_id']),
    sourceId: asStringOrNull(j['invoice_id']),
    sourceNumber: asStringOrNull(pick(j, 'invoice.invoice_number')),
    reason: asString(j['reason']),
    refundMode: asString(j['refund_mode']),
    notes: asString(j['notes']),
    deductionTotal: asDouble(j['deduction_total']),
    refundAmount: asDouble(j['refund_amount']),
    items: asMapList(j['items']).map(DocLine.fromJson).toList(),
  );

  factory ReturnDoc.creditNote(JsonMap j) => ReturnDoc(
    id: asString(j['id']),
    number: asString(j['credit_note_number']),
    status: asString(j['status'], 'draft'),
    date: asDate(j['date']),
    amount: asDouble(j['total_amount']),
    party: _party(j),
    partyId: asString(j['party_id']),
    sourceId: asStringOrNull(j['invoice_id']),
    sourceNumber: asStringOrNull(pick(j, 'invoice.invoice_number')),
    reason: asString(j['reason']),
    refundMode: asString(j['refund_mode']),
    cancelReason: asString(j['cancel_reason']),
    items: asMapList(j['items']).map(DocLine.fromJson).toList(),
  );

  factory ReturnDoc.debitNote(JsonMap j) => ReturnDoc(
    id: asString(j['id']),
    number: asString(j['debit_note_number']),
    status: asString(j['status'], 'draft'),
    date: asDate(j['date']),
    amount: asDouble(j['total_amount']),
    party: _party(j),
    partyId: asString(j['party_id']),
    sourceId: asStringOrNull(j['purchase_bill_id']),
    sourceNumber: asStringOrNull(pick(j, 'purchase_bill.bill_number')),
    reason: asString(j['reason']),
    refundMode: asString(j['refund_mode']),
    cancelReason: asString(j['cancel_reason']),
    items: asMapList(j['items']).map(DocLine.fromJson).toList(),
  );
}

/// Settlement choices, matching each web form.
abstract final class RefundModes {
  static const salesReturn = [
    ('cash', 'Cash'),
    ('bank', 'Bank'),
    ('upi', 'UPI'),
    ('credit_note', 'Credit note'),
  ];
  static const creditNote = [
    ('cash', 'Cash'),
    ('original_payment', 'Original payment'),
    ('credit_note', 'Keep as credit'),
  ];
  static const debitNote = [
    ('cash', 'Cash'),
    ('original_payment', 'Original payment'),
    ('debit_note', 'Adjust against dues'),
  ];

  static String label(String mode) {
    for (final list in [salesReturn, creditNote, debitNote]) {
      for (final (v, l) in list) {
        if (v == mode) return l;
      }
    }
    return mode.isEmpty ? '—' : mode.replaceAll('_', ' ');
  }
}

/// One row of the discount history log.
class DiscountTxn {
  const DiscountTxn({
    required this.id,
    required this.type,
    required this.typeLabel,
    required this.reference,
    required this.date,
    required this.partyName,
    this.itemDiscount = 0,
    this.documentDiscount = 0,
    this.totalDiscount = 0,
    this.documentTotal = 0,
  });

  final String id;

  /// sale_invoice | estimate | purchase_bill | payment_in | payment_out
  final String type;
  final String typeLabel;
  final String reference;
  final DateTime? date;
  final String partyName;
  final double itemDiscount;
  final double documentDiscount;
  final double totalDiscount;
  final double documentTotal;

  factory DiscountTxn.fromJson(JsonMap j) => DiscountTxn(
    id: asString(j['id']),
    type: asString(j['type']),
    typeLabel: asString(j['type_label'], asString(j['type'])),
    reference: asString(j['reference']),
    date: asDate(j['date']),
    partyName: asString(j['party_name']),
    itemDiscount: asDouble(j['item_discount']),
    documentDiscount: asDouble(j['document_discount']),
    totalDiscount: asDouble(j['total_discount']),
    documentTotal: asDouble(j['document_total']),
  );

  static const types = [
    ('sale_invoice', 'Invoices'),
    ('estimate', 'Estimates'),
    ('purchase_bill', 'Purchases'),
    ('payment_in', 'Payment in'),
    ('payment_out', 'Payment out'),
  ];
}
