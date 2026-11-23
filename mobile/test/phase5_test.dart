import 'package:flutter_test/flutter_test.dart';
import 'package:truerp_mobile/core/models/money.dart';
import 'package:truerp_mobile/core/router/modules.dart';
import 'package:truerp_mobile/features/accounting/ui/accounting_screen.dart';

void main() {
  test('cash transaction direction follows the backend totals rule', () {
    for (final t in ['add', 'transfer_in']) {
      expect(CashTransaction.fromJson({'transaction_type': t}).isInflow, isTrue, reason: t);
    }
    for (final t in ['reduce', 'transfer_out', 'expense', 'payroll', 'profit_distribution']) {
      expect(CashTransaction.fromJson({'transaction_type': t}).isInflow, isFalse, reason: t);
    }
  });

  test('cash transaction without account is cash in hand', () {
    final t = CashTransaction.fromJson({'transaction_type': 'add', 'amount': 10});
    expect(t.accountId, isNull);
    expect(t.where, 'Cash in hand');
    expect(CashTransaction.fromJson({'transaction_type': 'weird_type'}).typeLabel, 'weird type');
  });

  test('summary sums only active bank accounts', () {
    final s = CashBankSummary.fromJson({
      'cash_in_hand': 100,
      'bank_accounts': [
        {'id': 'a', 'balance': 500, 'is_active': true},
        {'id': 'b', 'balance': 900, 'is_active': false},
      ],
    });
    expect(s.bankTotal, 500);
  });

  test('routing marks owner equity', () {
    expect(PaymentRouting.fromJson({'payment_method': 'initial_investment'}).isOwnerEquity, isTrue);
    expect(PaymentRouting.fromJson({'payment_method': 'upi', 'bank_account_id': 'x'}).bankAccountId, 'x');
  });

  test('accounting rows read both account and report field names', () {
    expect(LedgerAccount.fromJson({'account_id': 'a', 'account_code': '1000', 'account_name': 'Cash'}).name, 'Cash');
    expect(LedgerAccount.fromJson({'id': 'a', 'code': '1000', 'name': 'Cash'}).code, '1000');
    final tb = TrialBalance.fromJson({'items': [], 'total_debit': 10, 'total_credit': 10});
    expect(tb.isBalanced, isTrue);
  });

  test('journal line shows code and name', () {
    final l = JournalLine.fromJson({'account': {'code': '4000', 'name': 'Sales'}, 'credit': 5});
    expect(l.accountName, '4000 · Sales');
  });

  test('Indian financial year starts 1 April', () {
    expect(fyStart(DateTime(2026, 11, 23)), DateTime(2026, 4, 1));
    expect(fyStart(DateTime(2027, 2, 10)), DateTime(2026, 4, 1));
    expect(fyStart(DateTime(2026, 4, 1)), DateTime(2026, 4, 1));
  });

  test('phase 5 modules are built while 3 and 4 are not', () {
    expect(moduleById('cash-bank')!.isBuilt, isTrue);
    expect(moduleById('accounting')!.isBuilt, isTrue);
    expect(moduleById('estimates')!.isBuilt, isFalse);
    expect(moduleById('stock')!.isBuilt, isFalse);
  });
}
