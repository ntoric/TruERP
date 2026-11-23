import 'package:flutter_test/flutter_test.dart';
import 'package:truerp_mobile/core/models/hr.dart';
import 'package:truerp_mobile/features/hr/data/hr_repository.dart';

void main() {
  test('staff body always carries every field and a joining date', () {
    final j = Staff.fromJson({
      'name': ' Ravi ',
      'salary': 15000,
      'ifsc_code': 'hdfc0001234',
      'pan_number': 'abcde1234f',
    }).toJson();
    expect(j['name'], 'Ravi');
    expect(
      j['joining_date'],
      isNotNull,
      reason: 'server field is a non-null time',
    );
    expect(j['ifsc_code'], 'HDFC0001234');
    expect(j['pan_number'], 'ABCDE1234F');
    expect(j.containsKey('is_active'), isTrue);
    expect(Staff.fromJson({'salary_type': 'daily'}).salaryLabel, '/ day');
  });

  test('attendance status letters and labels', () {
    expect(AttendanceStatus.letter('half_day'), 'H');
    expect(AttendanceStatus.label('weekly_off'), 'Week off');
    expect(const AttendanceStats(present: 3, absent: 1, halfDay: 1).marked, 5);
  });

  test('payroll net preview never goes below zero (server rule)', () {
    const c = PayrollCalc(estimatedNet: 1000);
    expect(c.netWith(deduction: 200, bonus: 50), 850);
    expect(c.netWith(deduction: 5000), 0);
  });

  test('payroll due and settlement', () {
    final p = Payroll.fromJson({
      'net_salary': 12000,
      'paid_amount': 5000,
      'status': 'partial',
      'staff': {'name': 'Ravi'},
      'is_settlement': true,
    });
    expect(p.due, 7000);
    expect(p.staffName, 'Ravi');
    expect(p.isSettlement, isTrue);
    expect(Payroll.fromJson({'net_salary': 100, 'status': 'cancelled'}).due, 0);
  });

  test('cash payouts never send a bank account', () {
    expect(
      const Payout(bankAccountId: 'b1').toJson()['bank_account_id'],
      isNull,
    );
    expect(
      const Payout(
        mode: 'upi',
        bankAccountId: 'b1',
      ).toJson()['bank_account_id'],
      'b1',
    );
  });

  test('extra amounts', () {
    final add = StaffExtra.fromJson({'direction': 'add', 'status': 'pending'});
    expect(add.isAdd, isTrue);
    expect(add.canRedeem, isTrue);
    expect(
      StaffExtra.fromJson({'direction': 'add', 'status': 'settled'}).canRedeem,
      isFalse,
    );
    expect(StaffDeduction.typeLabel('loan'), 'Loan repayment');
  });
}
