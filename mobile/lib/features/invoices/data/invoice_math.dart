import '../../../core/models/line_item.dart';

export '../../../core/models/line_item.dart';

/// Kept as an alias so sales code reads naturally.
typedef InvoiceLine = LineItem;

/// Mirrors `CreateInvoice` in backend/controllers/invoice.go so the form's
/// preview matches what the server will save.
///
/// The backend currently bills tax-free: item tax rates are ignored. Line
/// discount is a percentage. The total is rounded to paise (to whole rupees
/// for POS sales).
class InvoiceTotals {
  const InvoiceTotals({
    required this.subTotal,
    required this.lineDiscounts,
    required this.invoiceDiscount,
    required this.additionalCharges,
    required this.roundOff,
    required this.total,
  });

  final double subTotal;
  final double lineDiscounts;
  final double invoiceDiscount;
  final double additionalCharges;
  final double roundOff;
  final double total;

  static InvoiceTotals compute(
    List<InvoiceLine> lines, {
    double invoiceDiscount = 0,
    double additionalCharges = 0,
    bool pos = false,
  }) {
    var sub = 0.0;
    var disc = 0.0;
    for (final l in lines) {
      sub += l.gross;
      disc += l.discountAmount;
    }
    final raw = sub - disc - invoiceDiscount + additionalCharges;
    var rounded = pos ? raw.roundToDouble() : (raw * 100).roundToDouble() / 100;
    if (pos && rounded < 0) rounded = 0;
    return InvoiceTotals(
      subTotal: sub,
      lineDiscounts: disc,
      invoiceDiscount: invoiceDiscount,
      additionalCharges: additionalCharges,
      roundOff: rounded - raw,
      total: rounded,
    );
  }
}
