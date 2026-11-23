import 'dart:convert';

import '../../../core/api/json.dart';
import '../../../core/models/product.dart';
import '../../invoices/data/invoice_math.dart';

class PosSession {
  const PosSession({
    required this.id,
    required this.status,
    this.openingCash = 0,
    this.closingCash = 0,
    this.cashIn = 0,
    this.cashOut = 0,
    this.totalSales = 0,
    this.totalReturns = 0,
    this.totalInvoices = 0,
    this.notes = '',
    this.openedAt,
    this.closedAt,
  });

  final String id;

  /// open | closed
  final String status;
  final double openingCash;
  final double closingCash;
  final double cashIn;
  final double cashOut;

  /// All payment modes, not just cash (server keeps one running total).
  final double totalSales;
  final double totalReturns;
  final int totalInvoices;
  final String notes;
  final DateTime? openedAt;
  final DateTime? closedAt;

  bool get isOpen => status == 'open';

  /// What the drawer should hold if every sale was paid in cash — the same
  /// figure the web POS uses when it closes a session.
  double get expectedCash => openingCash + totalSales + cashIn - cashOut;

  factory PosSession.fromJson(JsonMap j) => PosSession(
    id: asString(j['id']),
    status: asString(j['status'], 'open'),
    openingCash: asDouble(j['opening_cash']),
    closingCash: asDouble(j['closing_cash']),
    cashIn: asDouble(j['cash_in_total']),
    cashOut: asDouble(j['cash_out_total']),
    totalSales: asDouble(j['total_sales']),
    totalReturns: asDouble(j['total_returns']),
    totalInvoices: asInt(j['total_invoices']),
    notes: asString(j['notes']),
    openedAt: asDate(j['opened_at'] ?? j['created_at']),
    closedAt: asDate(j['closed_at']),
  );
}

class CashMovement {
  const CashMovement({required this.type, required this.amount, this.reason = '', this.at});
  final String type;
  final double amount;
  final String reason;
  final DateTime? at;

  bool get isIn => type == 'cash_in';

  factory CashMovement.fromJson(JsonMap j) => CashMovement(
    type: asString(j['type']),
    amount: asDouble(j['amount']),
    reason: asString(j['reason']),
    at: asDate(j['created_at']),
  );
}

/// One product in the POS cart.
class CartLine {
  CartLine({required this.product, this.quantity = 1});
  final Product product;
  double quantity;

  double get price => product.salePrice;
  double get total => price * quantity;

  LineItem toLineItem() => LineItem(
    productId: product.id,
    description: product.name,
    quantity: quantity,
    unitPrice: price,
    unit: product.unit,
    hsnCode: product.hsnCode,
    taxRate: product.taxRate,
  );

  JsonMap toDraftJson() => {'product': product.toSnapshot(), 'quantity': quantity, 'total': total};
}

/// A bill on hold (`/pos/drafts`). `cart_data` is shared with the web POS:
/// either a list of lines or `{items: [...], discountValue, ...}`.
class HeldBill {
  const HeldBill({required this.id, required this.title, required this.lines, this.partyId, this.discount = 0, this.createdAt});
  final String id;
  final String title;
  final List<CartLine> lines;
  final String? partyId;
  final double discount;
  final DateTime? createdAt;

  double get total => lines.fold(0, (s, l) => s + l.total);
  int get itemCount => lines.length;

  factory HeldBill.fromJson(JsonMap j) {
    Object? data;
    try {
      data = jsonDecode(asString(j['cart_data'], '[]'));
    } catch (_) {
      data = const [];
    }
    final items = data is List ? data : asMap(data)['items'];
    final discount = data is Map && asString(data['discountType']) != 'percent' ? asDouble(data['discountValue']) : 0.0;
    return HeldBill(
      id: asString(j['id']),
      title: asString(j['title'], 'Held bill'),
      partyId: asStringOrNull(j['party_id']),
      discount: discount,
      createdAt: asDate(j['created_at']),
      lines: [
        for (final row in asMapList(items))
          if (asString(pick(row, 'product.id')).isNotEmpty)
            CartLine(product: Product.fromJson(asMap(row['product'])), quantity: asDouble(row['quantity'], 1)),
      ],
    );
  }

  static String encode(List<CartLine> lines, {double discount = 0}) => jsonEncode({
    'items': [for (final l in lines) l.toDraftJson()],
    if (discount > 0) 'discountType': 'amount',
    if (discount > 0) 'discountValue': discount.toString(),
  });
}

/// One tender in a (possibly split) POS payment.
class Tender {
  Tender({required this.mode, required this.amount, this.bankAccountId});
  String mode;
  double amount;
  String? bankAccountId;

  JsonMap toJson() => {'mode': mode, 'amount': amount, 'bank_account_id': mode == 'cash' ? null : bankAccountId};
}

/// Totals for the cart: invoice rule with whole-rupee rounding for POS.
InvoiceTotals posTotals(List<CartLine> lines, {double discount = 0}) =>
    InvoiceTotals.compute([for (final l in lines) l.toLineItem()], invoiceDiscount: discount, pos: true);
