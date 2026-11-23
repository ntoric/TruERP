import '../api/json.dart';

class Product {
  const Product({
    required this.id,
    required this.name,
    this.sku = '',
    this.itemCode = '',
    this.category = '',
    this.itemType = 'product',
    this.unit = 'PCS',
    this.salePrice = 0,
    this.purchasePrice = 0,
    this.mrp = 0,
    this.taxRate = 0,
    this.hsnCode = '',
    this.description = '',
    this.minStock = 0,
    this.stockQty = 0,
    this.lowStockAlert = true,
    this.isActive = true,
    this.imageUrl = '',
    this.enableBatching = false,
    this.salePriceWithTax = true,
    this.purchasePriceWithTax = true,
  });

  final String id;
  final String name;
  final String sku;
  final String itemCode;
  final String category;
  final String itemType;
  final String unit;
  final double salePrice;
  final double purchasePrice;
  final double mrp;
  final double taxRate;
  final String hsnCode;
  final String description;
  final double minStock;
  final double stockQty;
  final bool lowStockAlert;
  final bool isActive;
  final String imageUrl;

  // The backend's update overwrites these on every save, so they must be
  // round-tripped even though the mobile form doesn't edit them.
  final bool enableBatching;
  final bool salePriceWithTax;
  final bool purchasePriceWithTax;

  Product withStock(double qty) => Product(
    id: id,
    name: name,
    sku: sku,
    itemCode: itemCode,
    category: category,
    itemType: itemType,
    unit: unit,
    salePrice: salePrice,
    purchasePrice: purchasePrice,
    mrp: mrp,
    taxRate: taxRate,
    hsnCode: hsnCode,
    description: description,
    minStock: minStock,
    stockQty: qty,
    lowStockAlert: lowStockAlert,
    isActive: isActive,
    imageUrl: imageUrl,
    enableBatching: enableBatching,
    salePriceWithTax: salePriceWithTax,
    purchasePriceWithTax: purchasePriceWithTax,
  );

  bool get isService => itemType == 'service';
  bool get isLowStock => !isService && lowStockAlert && stockQty <= minStock;
  bool get isOutOfStock => !isService && stockQty <= 0;

  factory Product.fromJson(JsonMap j) => Product(
    id: asString(j['id']),
    name: asString(j['name']),
    sku: asString(j['sku']),
    itemCode: asString(j['item_code']),
    category: asString(j['category']),
    itemType: asString(j['item_type'], 'product'),
    unit: asString(j['unit'], 'PCS'),
    salePrice: asDouble(j['sale_price']),
    purchasePrice: asDouble(j['purchase_price']),
    mrp: asDouble(j['mrp']),
    taxRate: asDouble(j['tax_rate']),
    hsnCode: asString(j['hsn_code']),
    description: asString(j['description']),
    minStock: asDouble(j['min_stock']),
    stockQty: asDouble(j['stock_qty']),
    lowStockAlert: asBool(j['low_stock_alert'], true),
    isActive: asBool(j['is_active'], true),
    imageUrl: asString(j['image_url']),
    enableBatching: asBool(j['enable_batching']),
    salePriceWithTax: asBool(j['sale_price_with_tax'], true),
    purchasePriceWithTax: asBool(j['purchase_price_with_tax'], true),
  );

  /// Compact copy stored inside POS held bills (same keys as the API, so
  /// the web POS can read bills held on mobile and vice versa).
  JsonMap toSnapshot() => {
    'id': id,
    'name': name,
    'sku': sku,
    'item_code': itemCode,
    'category': category,
    'item_type': itemType,
    'unit': unit,
    'sale_price': salePrice,
    'purchase_price': purchasePrice,
    'mrp': mrp,
    'tax_rate': taxRate,
    'hsn_code': hsnCode,
    'stock_qty': stockQty,
  };

  /// Body for create/update. [openingStock] is only honoured on create.
  JsonMap toJson({double openingStock = 0}) => {
    'name': name.trim(),
    if (sku.trim().isNotEmpty) 'sku': sku.trim(),
    'item_code': itemCode.trim(),
    'category': category.trim(),
    'item_type': itemType,
    'unit': unit.trim().isEmpty ? 'PCS' : unit.trim().toUpperCase(),
    'sale_price': salePrice,
    'purchase_price': purchasePrice,
    'mrp': mrp,
    'tax_rate': taxRate,
    'gst_enabled': taxRate > 0,
    'hsn_code': hsnCode.trim(),
    'description': description.trim(),
    'min_stock': minStock,
    'low_stock_alert': lowStockAlert,
    'is_active': isActive,
    'enable_batching': enableBatching,
    'sale_price_with_tax': salePriceWithTax,
    'purchase_price_with_tax': purchasePriceWithTax,
    if (openingStock > 0)
      'inventory': {'quantity': openingStock, 'cost_price': purchasePrice},
  };
}
