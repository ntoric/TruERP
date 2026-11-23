import 'package:flutter_test/flutter_test.dart';
import 'package:truerp_mobile/core/models/line_item.dart';
import 'package:truerp_mobile/core/models/sales_docs.dart';
import 'package:truerp_mobile/features/sales_docs/data/sales_docs_repository.dart';
import 'package:truerp_mobile/features/sales_docs/ui/returns_screens.dart';

void main() {
  group('estimate payload', () {
    final draft = QuotationDraft(
      partyId: 'p1',
      date: DateTime(2026, 11, 1),
      lines: [
        LineItem(
          description: 'Rice',
          quantity: 2,
          unitPrice: 100,
          discountPct: 10,
          taxRate: 5,
        ),
      ],
      discount: 20,
      charges: 50,
    );

    test('totals follow the tax-free invoice rule', () {
      expect(draft.totals.total, 210); // 200 − 20 − 20 + 50
    });

    test('edit round-trips fields the backend overwrites', () {
      final existing = Quotation.fromJson({
        'id': 'q1',
        'quotation_number': 'EST-1',
        'party_id': 'p1',
        'signature': 'data:image/png;base64,AAAA',
        'place_of_supply': '29',
        'reverse_charge': true,
        'is_inter_state': true,
        'payment_terms': 15,
        'additional_charge_items': [
          {'label': 'Freight', 'amount': 50},
        ],
      });
      final j = draft.toJson(existing: existing);
      expect(j['signature'], 'data:image/png;base64,AAAA');
      expect(j['place_of_supply'], '29');
      expect(j['reverse_charge'], true);
      expect(j['is_inter_state'], true);
      expect(j['payment_terms'], 15);
      expect(
        j.containsKey('additional_charge_items'),
        isFalse,
        reason: 'absent = backend keeps itemised charges',
      );
      expect(existing.hasChargeItems, isTrue);
    });

    test('edit rules', () {
      expect(Quotation.fromJson({'status': 'accepted'}).canEdit, isFalse);
      expect(
        Quotation.fromJson({
          'status': 'sent',
          'converted_to_invoice_id': 'i1',
        }).canEdit,
        isFalse,
      );
      expect(Quotation.fromJson({'status': 'sent'}).canEdit, isTrue);
      final old = DateTime.now()
          .subtract(const Duration(days: 10))
          .toIso8601String();
      expect(
        Quotation.fromJson({'status': 'sent', 'valid_until': old}).isExpired,
        isTrue,
      );
    });
  });

  test('challan status change resends every header field', () {
    final c = DeliveryChallan.fromJson({
      'id': 'c1',
      'status': 'draft',
      'notes': 'Fragile',
      'terms': 'T',
      'signature': 'S',
      'vehicle_number': 'KA01AB1234',
      'transport_mode': 'road',
      'due_date': '2026-12-01T00:00:00Z',
    });
    final j = c.headerJson(status: 'delivered');
    expect(j['status'], 'delivered');
    expect(j['notes'], 'Fragile');
    expect(j['signature'], 'S');
    expect(j['vehicle_number'], 'KA01AB1234');
    expect(j['due_date'], isNotNull);
  });

  test('return documents parse all three shapes', () {
    final sr = ReturnDoc.salesReturn({
      'return_number': 'SR-1',
      'amount': 90,
      'invoice': {'invoice_number': 'INV-1'},
      'deduction_total': 10,
    });
    final cn = ReturnDoc.creditNote({
      'credit_note_number': 'CN-1',
      'total_amount': 50,
      'status': 'issued',
    });
    final dn = ReturnDoc.debitNote({
      'debit_note_number': 'DN-1',
      'total_amount': 70,
      'purchase_bill': {'bill_number': 'B-9'},
    });
    expect(sr.sourceNumber, 'INV-1');
    expect(sr.deductionTotal, 10);
    expect(cn.amount, 50);
    expect(dn.sourceNumber, 'B-9');
    expect(RefundModes.label('original_payment'), 'Original payment');
  });

  test('return kinds', () {
    expect(ReturnKind.salesReturn.finalStatus, 'processed');
    expect(ReturnKind.creditNote.finaliseLabel, 'Issue credit note');
    expect(ReturnKind.debitNote.fromBill, isTrue);
    expect(ReturnKind.fromKey('credit-note'), ReturnKind.creditNote);
    expect(ReturnKind.debitNote.refundModes.last.$1, 'debit_note');
  });

  test('discount types', () {
    final t = DiscountTxn.fromJson({
      'type': 'sale_invoice',
      'type_label': 'Sale Invoice',
      'total_discount': 25,
    });
    expect(t.totalDiscount, 25);
    expect(DiscountTxn.types.first.$1, 'sale_invoice');
  });
}
