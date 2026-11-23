import 'package:flutter_test/flutter_test.dart';
import 'package:truerp_mobile/core/models/inventory.dart';

void main() {
  test('stock row reads the preloaded product and computes value', () {
    final s = StockRow.fromJson({
      'id': 's1',
      'product_id': 'p1',
      'product': {'name': 'Rice', 'unit': 'BAG'},
      'outlet_id': 'w1',
      'outlet_name': 'Main',
      'available_qty': 4,
      'average_cost': 2100,
      'exp_date': DateTime.now()
          .add(const Duration(days: 10))
          .toIso8601String(),
    });
    expect(s.productName, 'Rice');
    expect(s.unit, 'BAG');
    expect(s.value, 8400);
    expect(s.isExpiringSoon, isTrue);
  });

  test('low stock shortfall never negative', () {
    expect(
      LowStockRow.fromJson({'current_stock': 3, 'min_stock': 10}).shortBy,
      7,
    );
    expect(
      LowStockRow.fromJson({'current_stock': 12, 'min_stock': 10}).shortBy,
      0,
    );
  });

  test('stock entry falls back to product name and defaults to approved', () {
    final e = StockEntry.fromJson({
      'product': {'name': 'Oil'},
      'quantity': -2,
    });
    expect(e.itemName, 'Oil');
    expect(e.status, 'approved');
    expect(
      StockEntry.fromJson({
        'item_name': 'X',
        'approval_status': 'pending',
      }).status,
      'pending',
    );
  });

  test('movement direction and summary', () {
    expect(Movement.fromJson({'qty_in': 5}).isIn, isTrue);
    expect(Movement.fromJson({'qty_out': 5}).isIn, isFalse);
    final s = MovementSummary.fromJson({
      'summary': {
        'opening_qty': 10,
        'in_qty': 5,
        'out_qty': 3,
        'closing_qty': 12,
      },
    });
    expect(s.closingQty, 12);
  });

  test('warehouse body uppercases the code and keeps flags', () {
    final j = Warehouse.fromJson({
      'name': ' Main ',
      'code': 'main',
      'is_default': true,
      'is_active': false,
    }).toJson();
    expect(j['code'], 'MAIN');
    expect(j['name'], 'Main');
    expect(j['is_default'], true);
    expect(j['is_active'], false);
  });

  test('transfer parses items', () {
    final t = StockTransfer.fromJson({
      'id': 't1',
      'from_outlet_id': 'a',
      'to_outlet_id': 'b',
      'status': 'submitted',
      'items': [
        {'product_id': 'p1', 'quantity': 5, 'sent_quantity': 5},
      ],
    });
    expect(t.items.single.sent, 5);
    expect(t.status, 'submitted');
  });
}
