import 'package:flutter_test/flutter_test.dart';
import 'package:truerp_mobile/core/models/invoice.dart';
import 'package:truerp_mobile/core/models/party.dart';
import 'package:truerp_mobile/core/models/payment.dart';
import 'package:truerp_mobile/core/models/product.dart';
import 'package:truerp_mobile/features/invoices/data/invoice_math.dart';
import 'package:truerp_mobile/features/invoices/data/invoices_repository.dart';
import 'package:truerp_mobile/features/payments/data/payments_repository.dart';

void main() {
  group('InvoiceTotals mirrors backend CreateInvoice', () {
    test('percentage line discount, tax ignored', () {
      final t = InvoiceTotals.compute([
        InvoiceLine(
          description: 'A',
          quantity: 2,
          unitPrice: 100,
          discountPct: 10,
          taxRate: 18,
        ),
        InvoiceLine(description: 'B', quantity: 1, unitPrice: 50),
      ]);
      expect(t.subTotal, 250);
      expect(t.lineDiscounts, 20);
      // 18% tax must NOT be added — the server bills tax-free.
      expect(t.total, 230);
    });

    test('invoice discount and charges', () {
      final t = InvoiceTotals.compute(
        [InvoiceLine(description: 'A', quantity: 3, unitPrice: 33.33)],
        invoiceDiscount: 9.99,
        additionalCharges: 50,
      );
      // 3 × 33.33 = 99.99, − 9.99 discount, + 50 charges.
      expect(t.total, 140);
    });

    test('rounds to paise; POS rounds to rupees', () {
      final lines = [
        InvoiceLine(description: 'A', quantity: 3, unitPrice: 10.333),
      ];
      expect(InvoiceTotals.compute(lines).total, 31.0);
      expect(
        InvoiceTotals.compute([
          InvoiceLine(description: 'A', quantity: 1, unitPrice: 10.6),
        ], pos: true).total,
        11,
      );
    });
  });

  group('InvoiceDraft payload', () {
    InvoiceDraft draft({double received = 0, String mode = 'cash'}) =>
        InvoiceDraft(
          partyId: 'p1',
          date: DateTime(2026, 11, 1),
          lines: [
            InvoiceLine(
              productId: 'x',
              description: 'Item',
              quantity: 2,
              unitPrice: 100,
            ),
          ],
          amountReceived: received,
          paymentMode: mode,
        );

    test('fully paid is marked paid with a split', () {
      final j = draft(received: 200).toJson(clientSaleId: 'c1');
      expect(j['status'], 'paid');
      expect(j['amount_paid'], 200);
      expect(j['client_sale_id'], 'c1');
      expect((j['payment_splits'] as List).single['mode'], 'cash');
      expect(j['customer_id'], 'p1');
    });

    test('partial stays sent; overpayment is capped', () {
      expect(draft(received: 50).toJson()['status'], 'sent');
      expect(draft(received: 999).toJson()['amount_paid'], 200);
    });

    test('unpaid sends no splits', () {
      final j = draft(received: 200, mode: 'unpaid').toJson();
      expect(j['payment_mode'], 'unpaid');
      expect(j['amount_paid'], 0);
      expect(j['payment_splits'], isEmpty);
      expect(j['status'], 'sent');
    });
  });

  test('payment-in never sends a bank account for cash', () {
    final j = PaymentInDraft(
      partyId: 'p',
      amount: 10,
      date: DateTime(2026),
      bankAccountId: 'b',
    ).toJson();
    expect(j['bank_account_id'], isNull);
    final upi = PaymentInDraft(
      partyId: 'p',
      amount: 10,
      date: DateTime(2026),
      mode: 'upi',
      bankAccountId: 'b',
    ).toJson();
    expect(upi['bank_account_id'], 'b');
  });

  group('round-tripped fields the backend overwrites on update', () {
    test('product keeps tax-inclusive and batching flags', () {
      final p = Product.fromJson({
        'id': '1',
        'name': 'X',
        'sale_price_with_tax': false,
        'enable_batching': true,
      });
      final j = p.toJson();
      expect(j['sale_price_with_tax'], false);
      expect(j['enable_batching'], true);
      expect(
        j['purchase_price_with_tax'],
        true,
        reason: 'missing flag defaults to backend default (true)',
      );
    });

    test('party keeps TAN', () {
      expect(
        Party.fromJson({
          'id': '1',
          'name': 'A',
          'tan': 'blra12345b',
        }).toJson()['tan'],
        'BLRA12345B',
      );
    });
  });

  test('party balance sign', () {
    expect(Party.fromJson({'balance': 10}).toCollect, isTrue);
    expect(Party.fromJson({'balance': -10}).toPay, isTrue);
    expect(PartyStats.fromJson({'to_pay': -500}).toPay, 500);
  });

  test('invoice balance due', () {
    final inv = Invoice.fromJson({
      'id': '1',
      'total_amount': 100,
      'amount_paid': 40,
      'status': 'partial',
    });
    expect(inv.balanceDue, 60);
    expect(
      Invoice.fromJson({'total_amount': 100, 'status': 'cancelled'}).balanceDue,
      0,
    );
  });

  test('payment mode labels', () {
    expect(PaymentMode.labelOf('bank_transfer'), 'Bank Transfer');
    expect(PaymentMode.labelOf('unpaid'), 'Unpaid');
    expect(PaymentMode.labelOf(null), '—');
  });
}
