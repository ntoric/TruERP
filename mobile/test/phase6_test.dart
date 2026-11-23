import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:truerp_mobile/core/models/reports.dart';
import 'package:truerp_mobile/features/reports/data/report_period.dart';

void main() {
  setUpAll(() => initializeDateFormatting('en_IN'));

  group('ReportPeriod', () {
    test('query matches the backend params', () {
      final p = ReportPeriod(
        kind: PeriodKind.monthly,
        anchor: DateTime(2026, 11, 23),
      );
      expect(p.toQuery(), {'period': 'monthly', 'date': '2026-11-23'});
      final c = p.custom(DateTime(2026, 4, 1), DateTime(2026, 6, 30));
      expect(c.toQuery(), {
        'period': 'custom',
        'date': '2026-06-30',
        'start_date': '2026-04-01',
        'end_date': '2026-06-30',
      });
    });

    test('month steps never skip short months', () {
      final jan31 = ReportPeriod(
        kind: PeriodKind.monthly,
        anchor: DateTime(2026, 1, 31),
      );
      expect(jan31.shift(1).anchor, DateTime(2026, 2, 1));
      expect(jan31.shift(-1).anchor, DateTime(2025, 12, 1));
    });

    test('day, week and year steps', () {
      final d = ReportPeriod(
        kind: PeriodKind.daily,
        anchor: DateTime(2026, 3, 1),
      );
      expect(d.shift(-1).anchor, DateTime(2026, 2, 28));
      expect(
        d.withKind(PeriodKind.weekly).shift(1).anchor,
        DateTime(2026, 3, 8),
      );
      expect(d.withKind(PeriodKind.yearly).shift(-1).anchor.year, 2025);
    });

    test('current period cannot step forward; custom never steps', () {
      expect(ReportPeriod.thisMonth().isCurrent, isTrue);
      expect(ReportPeriod.thisMonth().shift(-1).isCurrent, isFalse);
      final c = ReportPeriod.thisMonth().custom(
        DateTime(2026, 1, 1),
        DateTime(2026, 1, 31),
      );
      expect(c.canShift, isFalse);
    });

    test('labels', () {
      expect(
        ReportPeriod(
          kind: PeriodKind.monthly,
          anchor: DateTime(2026, 11, 5),
        ).label,
        'November 2026',
      );
      expect(
        ReportPeriod(
          kind: PeriodKind.weekly,
          anchor: DateTime(2026, 11, 25),
        ).label,
        '23 Nov – 29 Nov 2026',
      );
    });
  });

  group('report parsing', () {
    test('period report metrics and modes', () {
      final r = PeriodReport.fromJson({
        'label': 'November 2026',
        'sales': {'total_amount': 1000, 'count': 3},
        'payments_by_method': [
          {
            'method': 'upi',
            'label': 'UPI',
            'in': {'total_amount': 700, 'count': 2},
            'out': {'total_amount': 50, 'count': 1},
          },
        ],
        'daily_profit': 250,
      });
      expect(r.sales.amount, 1000);
      expect(r.sales.count, 3);
      expect(r.byMode.single.inAmount, 700);
      expect(r.byMode.single.outAmount, 50);
      expect(r.expenses.amount, 0, reason: 'missing metric is zero');
      expect(r.header.label, 'November 2026');
    });

    test('payments analytics folds in/out rows per mode', () {
      final a = PaymentsAnalytics.fromJson({
        'summary': {'total_in': 900, 'total_out': 300},
        'by_mode': [
          {'mode': 'cash', 'direction': 'in', 'total': 500},
          {'mode': 'upi', 'direction': 'in', 'total': 400},
          {'mode': 'cash', 'direction': 'out', 'total': 300},
        ],
      });
      expect(a.net, 600);
      final cash = a.byMode.firstWhere((m) => m.label == 'cash');
      expect(cash.inAmount, 500);
      expect(cash.outAmount, 300);
    });

    test('aging buckets total', () {
      final b = AgingBuckets.fromJson({
        'current': 10,
        'days_1_30': 20,
        'days_31_60': 30,
        'days_61_90': 40,
        'days_90_plus': 50,
      });
      expect(b.total, 150);
      expect(b.buckets.last, ('90+ days', 50.0));
    });

    test('party balance payable shown as a positive amount', () {
      final r = PartyBalanceReport.fromJson({
        'closing_receivable': 1000,
        'closing_payable': -400,
        'net_closing': 600,
      });
      expect(r.payable, 400);
    });

    test('GST rows accept both GSTR-1 and GSTR-2 keys', () {
      final g1 = GstReturnRow.fromJson({
        'invoice_number': 'INV-1',
        'invoice_date': '2026-11-01',
        'cgst': 9,
        'sgst': 9,
      });
      final g2 = GstReturnRow.fromJson({
        'bill_number': 'B-1',
        'receipt_date': '2026-11-02',
        'igst': 18,
      });
      expect(g1.number, 'INV-1');
      expect(g1.tax, 18);
      expect(g2.number, 'B-1');
      expect(g2.date, isNotNull);
    });

    test('GST summary reads summary and details', () {
      final s = GstSummary.fromJson({
        'summary': {'total_tax': 100, 'liability': 40},
        'details': {
          'purchases': {
            'taxable_value': 1000,
            'cgst': 30,
            'sgst': 30,
            'igst': 0,
          },
          'itc': {'total_itc': 60},
        },
      });
      expect(s.purchaseTax, 60);
      expect(s.itc, 60);
      expect(s.liability, 40);
    });
  });
}
