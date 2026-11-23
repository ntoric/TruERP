import '../api/json.dart';

class InventoryStats {
  const InventoryStats({
    this.totalValue = 0,
    this.totalQty = 0,
    this.productCount = 0,
    this.outletCount = 0,
    this.lowStockCount = 0,
  });
  final double totalValue;
  final double totalQty;
  final int productCount;
  final int outletCount;
  final int lowStockCount;

  factory InventoryStats.fromJson(JsonMap j) => InventoryStats(
    totalValue: asDouble(j['total_value']),
    totalQty: asDouble(j['total_qty']),
    productCount: asInt(j['product_count']),
    outletCount: asInt(j['outlet_count']),
    lowStockCount: asInt(j['low_stock_count']),
  );
}

/// One stock position: product × warehouse × batch.
class StockRow {
  const StockRow({
    required this.id,
    required this.productId,
    required this.productName,
    required this.outletId,
    this.outletName = '',
    this.unit = '',
    this.batchNo = '',
    this.available = 0,
    this.reserved = 0,
    this.averageCost = 0,
    this.expDate,
  });

  final String id;
  final String productId;
  final String productName;
  final String outletId;
  final String outletName;
  final String unit;
  final String batchNo;
  final double available;
  final double reserved;
  final double averageCost;
  final DateTime? expDate;

  double get value => available * averageCost;
  bool get isExpiringSoon =>
      expDate != null && expDate!.difference(DateTime.now()).inDays <= 30;

  factory StockRow.fromJson(JsonMap j) {
    final p = asMap(j['product']);
    return StockRow(
      id: asString(j['id']),
      productId: asString(j['product_id']),
      productName: asString(p['name'], 'Product'),
      unit: asString(p['unit']),
      outletId: asString(j['outlet_id']),
      outletName: asString(j['outlet_name']),
      batchNo: asString(j['batch_no']),
      available: asDouble(j['available_qty']),
      reserved: asDouble(j['reserved_qty']),
      averageCost: asDouble(j['average_cost']),
      expDate: asDate(j['exp_date']),
    );
  }
}

class LowStockRow {
  const LowStockRow({
    required this.productId,
    required this.productName,
    this.sku = '',
    this.current = 0,
    this.min = 0,
    this.outletName = '',
  });

  final String productId;
  final String productName;
  final String sku;
  final double current;
  final double min;
  final String outletName;

  double get shortBy => (min - current).clamp(0, double.infinity);

  factory LowStockRow.fromJson(JsonMap j) => LowStockRow(
    productId: asString(j['product_id']),
    productName: asString(j['product_name']),
    sku: asString(j['sku']),
    current: asDouble(j['current_stock']),
    min: asDouble(j['min_stock']),
    outletName: asString(j['outlet_name']),
  );
}

/// A stock entry awaiting approval (or recently decided).
class StockEntry {
  const StockEntry({
    required this.id,
    required this.itemName,
    required this.entryType,
    required this.quantity,
    required this.status,
    this.outletName = '',
    this.batchNo = '',
    this.referenceType = '',
    this.notes = '',
    this.date,
  });

  final String id;
  final String itemName;
  final String entryType;
  final double quantity;

  /// pending | approved | rejected
  final String status;
  final String outletName;
  final String batchNo;
  final String referenceType;
  final String notes;
  final DateTime? date;

  factory StockEntry.fromJson(JsonMap j) => StockEntry(
    id: asString(j['id']),
    itemName:
        asStringOrNull(j['item_name']) ??
        asString(pick(j, 'product.name'), 'Item'),
    entryType: asString(j['entry_type']),
    quantity: asDouble(j['quantity']),
    status: asString(j['approval_status'], 'approved'),
    outletName: asString(j['outlet_name']),
    batchNo: asString(j['batch_no']),
    referenceType: asString(j['reference_type']),
    notes: asString(j['notes']),
    date: asDate(j['entry_date'] ?? j['created_at']),
  );
}

class Movement {
  const Movement({
    required this.id,
    required this.date,
    required this.productId,
    required this.productName,
    required this.type,
    required this.typeLabel,
    this.unit = '',
    this.outletName = '',
    this.documentNo = '',
    this.referenceType = '',
    this.referenceId = '',
    this.qtyIn = 0,
    this.qtyOut = 0,
    this.stockAfter = 0,
    this.notes = '',
  });

  final String id;
  final DateTime? date;
  final String productId;
  final String productName;

  /// purchase, sale, sales_return, purchase_return, opening, adjustment, transfer, untracked
  final String type;
  final String typeLabel;
  final String unit;
  final String outletName;
  final String documentNo;
  final String referenceType;
  final String referenceId;
  final double qtyIn;
  final double qtyOut;
  final double stockAfter;
  final String notes;

  bool get isIn => qtyIn > 0;

  factory Movement.fromJson(JsonMap j) => Movement(
    id: asString(j['id']),
    date: asDate(j['date']),
    productId: asString(j['product_id']),
    productName: asString(j['product_name']),
    type: asString(j['transaction_type']),
    typeLabel: asString(j['type_label'], asString(j['transaction_type'])),
    unit: asString(j['unit']),
    outletName: asString(j['outlet_name']),
    documentNo: asString(j['document_no']),
    referenceType: asString(j['reference_type']),
    referenceId: asString(j['reference_id']),
    qtyIn: asDouble(j['qty_in']),
    qtyOut: asDouble(j['qty_out']),
    stockAfter: asDouble(j['stock']),
    notes: asString(j['notes']),
  );

  static const types = [
    ('purchase', 'Purchase'),
    ('sale', 'Sale'),
    ('sales_return', 'Sales return'),
    ('purchase_return', 'Purchase return'),
    ('adjustment', 'Adjustment'),
    ('opening', 'Opening'),
    ('transfer', 'Transfer'),
  ];
}

class MovementSummary {
  const MovementSummary({
    this.openingQty = 0,
    this.openingValue = 0,
    this.inQty = 0,
    this.outQty = 0,
    this.closingQty = 0,
    this.closingValue = 0,
  });

  final double openingQty;
  final double openingValue;
  final double inQty;
  final double outQty;
  final double closingQty;
  final double closingValue;

  factory MovementSummary.fromJson(JsonMap j) {
    final s = asMap(j['summary']);
    return MovementSummary(
      openingQty: asDouble(s['opening_qty']),
      openingValue: asDouble(s['opening_value']),
      inQty: asDouble(s['in_qty']),
      outQty: asDouble(s['out_qty']),
      closingQty: asDouble(s['closing_qty']),
      closingValue: asDouble(s['closing_value']),
    );
  }
}

class Warehouse {
  const Warehouse({
    required this.id,
    required this.name,
    this.code = '',
    this.address = '',
    this.city = '',
    this.state = '',
    this.pincode = '',
    this.contactPerson = '',
    this.contactPhone = '',
    this.contactEmail = '',
    this.notes = '',
    this.isActive = true,
    this.isDefault = false,
  });

  final String id;
  final String name;
  final String code;
  final String address;
  final String city;
  final String state;
  final String pincode;
  final String contactPerson;
  final String contactPhone;
  final String contactEmail;
  final String notes;
  final bool isActive;
  final bool isDefault;

  String get place => [city, state].where((s) => s.isNotEmpty).join(', ');

  factory Warehouse.fromJson(JsonMap j) => Warehouse(
    id: asString(j['id']),
    name: asString(j['name']),
    code: asString(j['code']),
    address: asString(j['address']),
    city: asString(j['city']),
    state: asString(j['state']),
    pincode: asString(j['pincode']),
    contactPerson: asString(j['contact_person']),
    contactPhone: asString(j['contact_phone']),
    contactEmail: asString(j['contact_email']),
    notes: asString(j['notes']),
    isActive: asBool(j['is_active'], true),
    isDefault: asBool(j['is_default']),
  );

  JsonMap toJson() => {
    'name': name.trim(),
    'code': code.trim().toUpperCase(),
    'address': address.trim(),
    'city': city.trim(),
    'state': state.trim(),
    'pincode': pincode.trim(),
    'contact_person': contactPerson.trim(),
    'contact_phone': contactPhone.trim(),
    'contact_email': contactEmail.trim(),
    'notes': notes.trim(),
    'is_active': isActive,
    'is_default': isDefault,
  };
}

class WarehouseStockItem {
  const WarehouseStockItem(this.name, this.qty, this.cost, this.value);
  final String name;
  final double qty;
  final double cost;
  final double value;

  factory WarehouseStockItem.fromJson(JsonMap j) => WarehouseStockItem(
    asString(j['item_name']),
    asDouble(j['stock_qty']),
    asDouble(j['cost_price']),
    asDouble(j['value']),
  );
}

class ProductCategory {
  const ProductCategory({
    required this.id,
    required this.name,
    this.description = '',
    this.parentId,
    this.isActive = true,
  });
  final String id;
  final String name;
  final String description;
  final String? parentId;
  final bool isActive;

  factory ProductCategory.fromJson(JsonMap j) => ProductCategory(
    id: asString(j['id']),
    name: asString(j['name']),
    description: asString(j['description']),
    parentId: asStringOrNull(j['parent_id']),
    isActive: asBool(j['is_active'], true),
  );
}

class TransferItem {
  const TransferItem({
    required this.productId,
    this.quantity = 0,
    this.sent = 0,
    this.received = 0,
  });
  final String productId;
  final double quantity;
  final double sent;
  final double received;

  factory TransferItem.fromJson(JsonMap j) => TransferItem(
    productId: asString(j['product_id']),
    quantity: asDouble(j['quantity']),
    sent: asDouble(j['sent_quantity']),
    received: asDouble(j['received_quantity']),
  );
}

/// Warehouse-to-warehouse transfer. Status: draft, submitted, received, cancelled.
class StockTransfer {
  const StockTransfer({
    required this.id,
    required this.fromId,
    required this.toId,
    required this.status,
    this.totalItems = 0,
    this.totalQuantity = 0,
    this.notes = '',
    this.sentDate,
    this.receivedDate,
    this.createdAt,
    this.items = const [],
  });

  final String id;
  final String fromId;
  final String toId;
  final String status;
  final int totalItems;
  final double totalQuantity;
  final String notes;
  final DateTime? sentDate;
  final DateTime? receivedDate;
  final DateTime? createdAt;
  final List<TransferItem> items;

  factory StockTransfer.fromJson(JsonMap j) => StockTransfer(
    id: asString(j['id']),
    fromId: asString(j['from_outlet_id']),
    toId: asString(j['to_outlet_id']),
    status: asString(j['status'], 'draft'),
    totalItems: asInt(j['total_items']),
    totalQuantity: asDouble(j['total_quantity']),
    notes: asString(j['notes']),
    sentDate: asDate(j['sent_date']),
    receivedDate: asDate(j['received_date']),
    createdAt: asDate(j['created_at']),
    items: asMapList(j['items']).map(TransferItem.fromJson).toList(),
  );
}
