import '../../../core/models/line_item.dart';

/// Purchase bill totals, mirroring the web purchase form
/// (`frontend/app/(app)/purchase-invoices/create/page.tsx`).
///
/// Unlike sales invoices, the backend stores the client's `total_amount`
/// as-is and moves the vendor balance by it — so this must match the web
/// formula exactly: line amount − line discount + GST − bill discount +
/// charges, rounded to the rupee when [roundOff] is on (the web default).
class PurchaseTotals {
  const PurchaseTotals({
    required this.subTotal,
    required this.lineDiscounts,
    required this.taxTotal,
    required this.billDiscount,
    required this.charges,
    required this.roundOff,
    required this.total,
  });

  final double subTotal;
  final double lineDiscounts;
  final double taxTotal;
  final double billDiscount;
  final double charges;
  final double roundOff;
  final double total;

  static PurchaseTotals compute(
    List<LineItem> lines, {
    double billDiscount = 0,
    double charges = 0,
    bool taxExempt = false,
    bool roundOff = true,
  }) {
    var sub = 0.0, disc = 0.0, tax = 0.0;
    for (final l in lines) {
      sub += l.gross;
      disc += l.discountAmount;
      tax += l.taxAmount(exempt: taxExempt);
    }
    final raw = sub - disc + tax - billDiscount + charges;
    // JS Math.round rounds .5 up (towards +∞); Dart's round() rounds away
    // from zero. They agree for the positive totals bills have.
    final total = roundOff ? raw.roundToDouble() : raw;
    return PurchaseTotals(
      subTotal: sub,
      lineDiscounts: disc,
      taxTotal: tax,
      billDiscount: billDiscount,
      charges: charges,
      roundOff: total - raw,
      total: total,
    );
  }
}

/// Status the web form sends for a non-draft bill.
String purchaseStatusFor(double paid, double total) {
  if (paid >= total) return 'paid';
  if (paid > 0) return 'partial';
  return 'unpaid';
}
