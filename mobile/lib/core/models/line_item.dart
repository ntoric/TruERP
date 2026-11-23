/// One editable line on a sales invoice, purchase bill or purchase order.
///
/// Discount is a percentage. Tax is applied only where the backend applies
/// it (purchase bills and orders); sales invoices ignore [taxRate].
class LineItem {
  LineItem({
    this.productId,
    required this.description,
    this.quantity = 1,
    this.unitPrice = 0,
    this.discountPct = 0,
    this.unit = '',
    this.hsnCode = '',
    this.taxRate = 0,
    this.itemCode = '',
    this.mrp = 0,
    this.salePrice = 0,
    this.stockQty,
  });

  String? productId;
  String description;
  double quantity;
  double unitPrice;
  double discountPct;
  String unit;
  String hsnCode;
  double taxRate;

  /// Purchase-only extras, copied onto the product by the backend.
  String itemCode;
  double mrp;
  double salePrice;

  /// Stock when the product was picked (low-stock hint on sales).
  double? stockQty;

  double get gross => quantity * unitPrice;
  double get discountAmount => gross * (discountPct / 100);
  double get net => gross - discountAmount;

  /// Tax on the discounted amount (0 when [exempt]).
  double taxAmount({bool exempt = false}) => exempt ? 0 : net * (taxRate / 100);

  /// Sales invoice line (`POST /invoices`).
  Map<String, dynamic> toInvoiceJson() => {
        if (productId != null) 'product_id': productId,
        'description': description.trim(),
        'quantity': quantity,
        'unit_price': unitPrice,
        'discount': discountPct,
        'tax_rate': taxRate,
        'unit': unit,
        'hsn_code': hsnCode,
      };

  /// Purchase bill line (`POST /purchase/bills`), mirroring the web form.
  Map<String, dynamic> toPurchaseJson({bool taxExempt = false}) => {
        'product_id': productId,
        'item_code': itemCode,
        'description': description.trim().isEmpty ? 'Item' : description.trim(),
        'quantity': quantity,
        'unit': unit,
        'unit_price': unitPrice,
        'discount': discountPct,
        'tax_rate': taxExempt ? 0 : taxRate,
        'mrp': mrp,
        'sale_price': salePrice,
        'hsn_code': hsnCode,
        'batch_no': '',
        'is_new_item': false,
      };

  /// Purchase order line (`POST /purchase/orders`).
  Map<String, dynamic> toOrderJson() => {
        if (productId != null) 'product_id': productId,
        'description': description.trim(),
        'quantity': quantity,
        'unit_price': unitPrice,
        'tax_rate': taxRate,
      };
}
