import '../api/json.dart';
import 'payment.dart';

String _staffName(JsonMap j) => asString(pick(j, 'staff.name'));

class Staff {
  const Staff({
    required this.id,
    required this.name,
    this.phone = '',
    this.email = '',
    this.address = '',
    this.designation = '',
    this.department = '',
    this.joiningDate,
    this.salary = 0,
    this.salaryType = 'monthly',
    this.bankName = '',
    this.accountNumber = '',
    this.ifscCode = '',
    this.aadharNumber = '',
    this.panNumber = '',
    this.isActive = true,
    this.notes = '',
  });

  final String id;
  final String name;
  final String phone;
  final String email;
  final String address;
  final String designation;
  final String department;
  final DateTime? joiningDate;
  final double salary;

  /// monthly | daily | hourly
  final String salaryType;
  final String bankName;
  final String accountNumber;
  final String ifscCode;
  final String aadharNumber;
  final String panNumber;
  final bool isActive;
  final String notes;

  String get role =>
      [designation, department].where((s) => s.isNotEmpty).join(' · ');
  String get salaryLabel => switch (salaryType) {
    'daily' => '/ day',
    'hourly' => '/ hour',
    _ => '/ month',
  };

  static const salaryTypes = [
    ('monthly', 'Monthly'),
    ('daily', 'Daily'),
    ('hourly', 'Hourly'),
  ];

  factory Staff.fromJson(JsonMap j) => Staff(
    id: asString(j['id']),
    name: asString(j['name']),
    phone: asString(j['phone']),
    email: asString(j['email']),
    address: asString(j['address']),
    designation: asString(j['designation']),
    department: asString(j['department']),
    joiningDate: asDate(j['joining_date']),
    salary: asDouble(j['salary']),
    salaryType: asString(j['salary_type'], 'monthly'),
    bankName: asString(j['bank_name']),
    accountNumber: asString(j['account_number']),
    ifscCode: asString(j['ifsc_code']),
    aadharNumber: asString(j['aadhar_number']),
    panNumber: asString(j['pan_number']),
    isActive: asBool(j['is_active'], true),
    notes: asString(j['notes']),
  );

  /// Every field is sent: the backend's update rewrites all of them.
  JsonMap toJson() => {
    'name': name.trim(),
    'phone': phone.trim(),
    'email': email.trim(),
    'address': address.trim(),
    'designation': designation.trim(),
    'department': department.trim(),
    // joining_date is a non-null time on the server; default to today.
    'joining_date': (joiningDate ?? DateTime.now()).toUtc().toIso8601String(),
    'salary': salary,
    'salary_type': salaryType,
    'bank_name': bankName.trim(),
    'account_number': accountNumber.trim(),
    'ifsc_code': ifscCode.trim().toUpperCase(),
    'aadhar_number': aadharNumber.trim(),
    'pan_number': panNumber.trim().toUpperCase(),
    'is_active': isActive,
    'notes': notes.trim(),
  };
}

/// What the business owes a staff member right now (positive = owed to staff).
class StaffBalance {
  const StaffBalance({
    this.balance = 0,
    this.payableFromPayrolls = 0,
    this.earnedUnpaid = 0,
    this.uncoveredDays = 0,
    this.salaryPaid = 0,
    this.advancesPending = 0,
    this.deductionsPending = 0,
    this.extrasAddPending = 0,
    this.extrasDeductPending = 0,
  });

  final double balance;
  final double payableFromPayrolls;
  final double earnedUnpaid;
  final double uncoveredDays;
  final double salaryPaid;
  final double advancesPending;
  final double deductionsPending;
  final double extrasAddPending;
  final double extrasDeductPending;

  factory StaffBalance.fromJson(JsonMap j) => StaffBalance(
    balance: asDouble(j['balance']),
    payableFromPayrolls: asDouble(j['payable_from_payrolls']),
    earnedUnpaid: asDouble(j['earned_unpaid']),
    uncoveredDays: asDouble(j['uncovered_payable_days']),
    salaryPaid: asDouble(j['salary_paid']),
    advancesPending: asDouble(j['advances_pending']),
    deductionsPending: asDouble(j['deductions_pending']),
    extrasAddPending: asDouble(j['extras_add_pending']),
    extrasDeductPending: asDouble(j['extras_deduct_pending']),
  );
}

/// Attendance statuses with short labels for the roll-call sheet.
abstract final class AttendanceStatus {
  static const present = 'present';
  static const absent = 'absent';
  static const halfDay = 'half_day';
  static const paidLeave = 'paid_leave';
  static const weeklyOff = 'weekly_off';

  static const all = [
    (present, 'Present', 'P'),
    (absent, 'Absent', 'A'),
    (halfDay, 'Half day', 'H'),
    (paidLeave, 'Paid leave', 'L'),
    (weeklyOff, 'Week off', 'W'),
  ];

  static String label(String s) =>
      all.where((a) => a.$1 == s).map((a) => a.$2).firstOrNull ?? s;
  static String letter(String s) =>
      all.where((a) => a.$1 == s).map((a) => a.$3).firstOrNull ?? '?';
}

class Attendance {
  const Attendance({
    required this.id,
    required this.staffId,
    required this.date,
    required this.status,
    this.notes = '',
    this.workHours = 0,
  });
  final String id;
  final String staffId;
  final DateTime? date;
  final String status;
  final String notes;
  final double workHours;

  factory Attendance.fromJson(JsonMap j) => Attendance(
    id: asString(j['id']),
    staffId: asString(j['staff_id']),
    date: asDate(j['date']),
    status: asString(j['status']),
    notes: asString(j['notes']),
    workHours: asDouble(j['work_hours']),
  );
}

class AttendanceStats {
  const AttendanceStats({
    this.total = 0,
    this.present = 0,
    this.absent = 0,
    this.halfDay = 0,
    this.paidLeave = 0,
    this.weeklyOff = 0,
  });
  final int total;
  final int present;
  final int absent;
  final int halfDay;
  final int paidLeave;
  final int weeklyOff;

  int get marked => present + absent + halfDay + paidLeave + weeklyOff;

  factory AttendanceStats.fromJson(JsonMap j) => AttendanceStats(
    total: asInt(j['total_staff']),
    present: asInt(j['present']),
    absent: asInt(j['absent']),
    halfDay: asInt(j['half_day']),
    paidLeave: asInt(j['paid_leave']),
    weeklyOff: asInt(j['weekly_off']),
  );
}

class PayrollPayment {
  const PayrollPayment({
    required this.number,
    required this.amount,
    required this.date,
    this.mode = '',
    this.bankLabel,
  });
  final String number;
  final double amount;
  final DateTime? date;
  final String mode;
  final String? bankLabel;

  factory PayrollPayment.fromJson(JsonMap j) {
    final bank = asMap(j['bank_account']);
    return PayrollPayment(
      number: asString(j['payment_number']),
      amount: asDouble(j['amount']),
      date: asDate(j['payment_date']),
      mode: asString(j['payment_mode']),
      bankLabel: bank.isEmpty ? null : BankAccount.fromJson(bank).label,
    );
  }
}

class Payroll {
  const Payroll({
    required this.id,
    required this.number,
    required this.staffId,
    required this.staffName,
    required this.status,
    this.paymentDate,
    this.startDate,
    this.endDate,
    this.basicSalary = 0,
    this.workingDays = 0,
    this.presentDays = 0,
    this.absentDays = 0,
    this.halfDays = 0,
    this.paidLeaveDays = 0,
    this.weeklyOffDays = 0,
    this.deductions = 0,
    this.bonus = 0,
    this.netSalary = 0,
    this.paidAmount = 0,
    this.isSettlement = false,
    this.notes = '',
    this.payments = const [],
  });

  final String id;
  final String number;
  final String staffId;
  final String staffName;

  /// paid | partial | pending | cancelled
  final String status;
  final DateTime? paymentDate;
  final DateTime? startDate;
  final DateTime? endDate;
  final double basicSalary;
  final double workingDays;
  final double presentDays;
  final double absentDays;
  final double halfDays;
  final double paidLeaveDays;
  final double weeklyOffDays;
  final double deductions;
  final double bonus;
  final double netSalary;
  final double paidAmount;
  final bool isSettlement;
  final String notes;
  final List<PayrollPayment> payments;

  double get due => status == 'cancelled'
      ? 0
      : (netSalary - paidAmount).clamp(0, double.infinity);
  bool get isCancelled => status == 'cancelled';

  factory Payroll.fromJson(JsonMap j) => Payroll(
    id: asString(j['id']),
    number: asString(j['payment_number']),
    staffId: asString(j['staff_id']),
    staffName: _staffName(j),
    status: asString(j['status'], 'pending'),
    paymentDate: asDate(j['payment_date']),
    startDate: asDate(j['start_date']),
    endDate: asDate(j['end_date']),
    basicSalary: asDouble(j['basic_salary']),
    workingDays: asDouble(j['working_days']),
    presentDays: asDouble(j['present_days']),
    absentDays: asDouble(j['absent_days']),
    halfDays: asDouble(j['half_days']),
    paidLeaveDays: asDouble(j['paid_leave_days']),
    weeklyOffDays: asDouble(j['weekly_off_days']),
    deductions: asDouble(j['deductions']),
    bonus: asDouble(j['bonus']),
    netSalary: asDouble(j['net_salary']),
    paidAmount: asDouble(j['paid_amount']),
    isSettlement: asBool(j['is_settlement']),
    notes: asString(j['notes']),
    payments: asMapList(j['payments']).map(PayrollPayment.fromJson).toList(),
  );
}

/// Server preview from `/payroll/calculate` for a staff member and period.
class PayrollCalc {
  const PayrollCalc({
    this.salary = 0,
    this.salaryType = 'monthly',
    this.workingDays = 0,
    this.presentDays = 0,
    this.absentDays = 0,
    this.halfDays = 0,
    this.paidLeaveDays = 0,
    this.weeklyOffDays = 0,
    this.payableDays = 0,
    this.calculatedSalary = 0,
    this.periodDeductions = 0,
    this.advanceRecovery = 0,
    this.extraAdd = 0,
    this.extraDeduct = 0,
    this.estimatedNet = 0,
  });

  final double salary;
  final String salaryType;
  final double workingDays;
  final double presentDays;
  final double absentDays;
  final double halfDays;
  final double paidLeaveDays;
  final double weeklyOffDays;
  final double payableDays;
  final double calculatedSalary;
  final double periodDeductions;
  final double advanceRecovery;
  final double extraAdd;
  final double extraDeduct;
  final double estimatedNet;

  /// Net after the extra deduction and bonus typed in the form, floored at 0
  /// like the server.
  double netWith({double deduction = 0, double bonus = 0}) =>
      (estimatedNet - deduction + bonus).clamp(0, double.infinity);

  factory PayrollCalc.fromJson(JsonMap j) => PayrollCalc(
    salary: asDouble(j['salary']),
    salaryType: asString(j['salary_type'], 'monthly'),
    workingDays: asDouble(j['working_days']),
    presentDays: asDouble(j['present_days']),
    absentDays: asDouble(j['absent_days']),
    halfDays: asDouble(j['half_days']),
    paidLeaveDays: asDouble(j['paid_leave_days']),
    weeklyOffDays: asDouble(j['weekly_off_days']),
    payableDays: asDouble(j['payable_days']),
    calculatedSalary: asDouble(j['calculated_salary']),
    periodDeductions: asDouble(j['period_deductions']),
    advanceRecovery: asDouble(j['advance_recovery']),
    extraAdd: asDouble(j['extra_add']),
    extraDeduct: asDouble(j['extra_deduct']),
    estimatedNet: asDouble(j['estimated_net']),
  );
}

class StaffAdvance {
  const StaffAdvance({
    required this.id,
    required this.number,
    required this.staffId,
    required this.staffName,
    required this.amount,
    required this.date,
    this.recovered = 0,
    this.pending = 0,
    this.status = 'pending',
    this.reason = '',
    this.mode = '',
  });

  final String id;
  final String number;
  final String staffId;
  final String staffName;
  final double amount;
  final DateTime? date;
  final double recovered;
  final double pending;

  /// pending | partial | recovered
  final String status;
  final String reason;
  final String mode;

  factory StaffAdvance.fromJson(JsonMap j) => StaffAdvance(
    id: asString(j['id']),
    number: asString(j['advance_number']),
    staffId: asString(j['staff_id']),
    staffName: _staffName(j),
    amount: asDouble(j['amount']),
    date: asDate(j['advance_date']),
    recovered: asDouble(j['recovered_amount']),
    pending: asDouble(j['pending_amount']),
    status: asString(j['status'], 'pending'),
    reason: asString(j['reason']),
    mode: asString(j['payment_mode']),
  );
}

class StaffDeduction {
  const StaffDeduction({
    required this.id,
    required this.number,
    required this.staffId,
    required this.staffName,
    required this.type,
    required this.amount,
    required this.date,
    this.description = '',
    this.isRecurring = false,
    this.installments = 0,
    this.installmentsPaid = 0,
    this.status = 'active',
  });

  final String id;
  final String number;
  final String staffId;
  final String staffName;
  final String type;
  final double amount;
  final DateTime? date;
  final String description;
  final bool isRecurring;
  final int installments;
  final int installmentsPaid;

  /// active | completed | cancelled
  final String status;

  static const types = [
    ('penalty', 'Penalty'),
    ('loan', 'Loan repayment'),
    ('tax', 'Tax'),
    ('insurance', 'Insurance'),
    ('other', 'Other'),
  ];

  static String typeLabel(String t) =>
      types.where((x) => x.$1 == t).map((x) => x.$2).firstOrNull ??
      t.replaceAll('_', ' ');

  factory StaffDeduction.fromJson(JsonMap j) => StaffDeduction(
    id: asString(j['id']),
    number: asString(j['deduction_number']),
    staffId: asString(j['staff_id']),
    staffName: _staffName(j),
    type: asString(j['deduction_type']),
    amount: asDouble(j['amount']),
    date: asDate(j['deduction_date']),
    description: asString(j['description']),
    isRecurring: asBool(j['is_recurring']),
    installments: asInt(j['total_installments']),
    installmentsPaid: asInt(j['installments_paid']),
    status: asString(j['status'], 'active'),
  );
}

/// Extra amount beyond salary. `add` = owed to the staff (incentive,
/// reimbursement); `deduct` = extra payout already drawn, recovered later.
class StaffExtra {
  const StaffExtra({
    required this.id,
    required this.number,
    required this.staffId,
    required this.staffName,
    required this.direction,
    required this.amount,
    required this.date,
    this.reason = '',
    this.status = 'pending',
    this.isRedeemed = false,
  });

  final String id;
  final String number;
  final String staffId;
  final String staffName;
  final String direction;
  final double amount;
  final DateTime? date;
  final String reason;

  /// pending | settled | cancelled
  final String status;
  final bool isRedeemed;

  bool get isAdd => direction == 'add';

  /// Paying out now: settles an `add`; for `deduct` it's the draw itself.
  bool get canRedeem => status == 'pending' && !isRedeemed;

  factory StaffExtra.fromJson(JsonMap j) => StaffExtra(
    id: asString(j['id']),
    number: asString(j['extra_number']),
    staffId: asString(j['staff_id']),
    staffName: _staffName(j),
    direction: asString(j['direction'], 'add'),
    amount: asDouble(j['amount']),
    date: asDate(j['entry_date']),
    reason: asString(j['reason']),
    status: asString(j['status'], 'pending'),
    isRedeemed: asBool(j['is_redeemed']),
  );
}

class AttendanceReminder {
  const AttendanceReminder({
    this.enabled = false,
    this.time = '10:00',
    this.timezone = '',
    this.remindLaterMinutes = 30,
  });
  final bool enabled;

  /// HH:MM 24h.
  final String time;
  final String timezone;
  final int remindLaterMinutes;

  factory AttendanceReminder.fromJson(JsonMap j) => AttendanceReminder(
    enabled: asBool(j['enabled']),
    time: asString(j['reminder_time'], '10:00'),
    timezone: asString(j['timezone']),
    remindLaterMinutes: asInt(j['remind_later_minutes'], 30),
  );

  JsonMap toJson() => {
    'enabled': enabled,
    'reminder_time': time,
    'timezone': timezone,
    'remind_later_minutes': remindLaterMinutes,
  };
}
