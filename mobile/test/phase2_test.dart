import 'package:flutter_test/flutter_test.dart';
import 'package:truerp_mobile/core/models/expense.dart';
import 'package:truerp_mobile/core/models/line_item.dart';
import 'package:truerp_mobile/core/models/purchase.dart';
import 'package:truerp_mobile/features/expenses/data/expenses_repository.dart';
import 'package:truerp_mobile/features/payments/data/payments_repository.dart';
import 'package:truerp_mobile/features/purchases/data/purchase_math.dart';
import 'package:truerp_mobile/features/purchases/data/purchases_repository.dart';

void main() {
  group('PurchaseTotals matches the web purchase form', () {
    final lines = [
      LineItem(description: 'Rice', quantity: 10, unitPrice: 100, discountPct: 5, taxRate: 5),
      LineItem(description: 'Oil', quantity: 2, unitPrice: 149.5, taxRate: 18),
    ];

    test('discount before GST, then rounded to the rupee', () {
      final t = PurchaseTotals.compute(lines);
      expect(t.subTotal, 1299);
      expect(t.lineDiscounts, 50);
      // 950 × 5% + 299 × 18% = 47.5 + 53.82
      expect(t.taxTotal, closeTo(101.32, 1e-9));
      expect(t.total, 1350); // 1350.32 → 1350
      expect(t.roundOff, closeTo(-0.32, 1e-9));
    });

    test('bill discount, charges, no rounding', () {
      final t = PurchaseTotals.compute(lines, billDiscount: 20.32, charges: 70, roundOff: false);
      expect(t.total, closeTo(1400, 1e-9));
    });

    test('tax exempt drops GST everywhere', () {
      final t = PurchaseTotals.compute(lines, taxExempt: true);
      expect(t.taxTotal, 0);
      expect(t.total, 1249);
      expect(lines.first.toPurchaseJson(taxExempt: true)['tax_rate'], 0);
    });

    test('status rule', () {
      expect(purchaseStatusFor(100, 100), 'paid');
      expect(purchaseStatusFor(40, 100), 'partial');
      expect(purchaseStatusFor(0, 100), 'unpaid');
    });
  });

  group('PurchaseBillDraft payload', () {
    PurchaseBillDraft draft({double paid = 0, String mode = 'unpaid'}) => PurchaseBillDraft(
          partyId: 'v1',
          number: ' VB-77 ',
          date: DateTime(2026, 11, 1),
          lines: [LineItem(productId: 'p', description: 'Rice', quantity: 2, unitPrice: 50, taxRate: 5, mrp: 60, salePrice: 55)],
          amountPaid: paid,
          paymentMode: mode,
          bankAccountId: 'b1',
        );

    test('unpaid bill', () {
      final j = draft().toJson(clientBillId: 'c1');
      expect(j['bill_number'], 'VB-77');
      expect(j['total_amount'], 105);
      expect(j['paid_amount'], 0);
      expect(j['balance_due'], 105);
      expect(j['status'], 'unpaid');
      expect(j['payment_mode'], 'unpaid');
      expect(j['bank_account_id'], isNull);
      expect(j['client_bill_id'], 'c1');
      final item = (j['items'] as List).single as Map;
      expect(item['mrp'], 60);
      expect(item['sale_price'], 55);
      expect(item['is_new_item'], false);
    });

    test('partly paid by UPI keeps the bank account', () {
      final j = draft(paid: 40, mode: 'upi').toJson(clientBillId: 'c1');
      expect(j['status'], 'partial');
      expect(j['bank_account_id'], 'b1');
      expect((j['payment_splits'] as List).single['amount'], 40);
    });

    test('cash never carries a bank account; overpayment capped', () {
      final j = draft(paid: 999, mode: 'cash').toJson(clientBillId: 'c1');
      expect(j['paid_amount'], 105);
      expect(j['status'], 'paid');
      expect(j['bank_account_id'], isNull);
    });
  });

  test('expense total matches server (GST per item on subtotal)', () {
    final d = ExpenseDraft(
      category: 'Rent',
      date: DateTime(2026),
      items: [ExpenseItem(description: 'Rent', unitPrice: 10000), ExpenseItem(description: 'Maint', quantity: 2, unitPrice: 500)],
      withGst: true,
      taxRate: 18,
      bankAccountId: 'b',
    );
    expect(d.subTotal, 11000);
    expect(d.total, 12980);
    final j = d.toJson();
    expect(j['bank_account_id'], isNull, reason: 'cash expense');
    expect((j['items'] as List).length, 2);
  });

  test('payment-out payload', () {
    final j = PaymentOutDraft(partyId: 'v', amount: 500, date: DateTime(2026), mode: 'bank_transfer', bankAccountId: 'b', purchaseBillId: 'pb')
        .toJson();
    expect(j['amount_paid'], 500);
    expect(j['purchase_bill_id'], 'pb');
    expect(j['bank_account_id'], 'b');
  });

  test('models parse backend shapes', () {
    final bill = PurchaseBill.fromJson({
      'id': 'b', 'bill_number': 'VB-1', 'status': 'partial', 'party': {'id': 'v', 'name': 'Acme'},
      'items': [{'id': 'i', 'description': 'Rice', 'quantity': 2, 'unit_price': 100, 'discount': 10}],
      'total_amount': 180, 'paid_amount': 80, 'balance_due': 100,
    });
    expect(bill.vendorName, 'Acme');
    expect(bill.lineDiscounts, 20);
    expect(PurchaseReturn.refundLabel('credit_note'), 'Debit note');
    expect(Expense.fromJson({'items': [{'description': 'Tea'}, {'description': 'Snacks'}]}).title, 'Tea +1');
  });
}
