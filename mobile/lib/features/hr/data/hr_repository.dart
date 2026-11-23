import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/json.dart';
import '../../../core/api/revision.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/models/hr.dart';

/// A payout's money side, shared by payroll, payments, advances and extras.
class Payout {
  const Payout({
    this.mode = 'cash',
    this.bankAccountId,
    this.reference = '',
    this.notes = '',
  });
  final String mode;
  final String? bankAccountId;
  final String reference;
  final String notes;

  JsonMap toJson() => {
    'payment_mode': mode,
    'bank_account_id': mode == 'cash' ? null : bankAccountId,
    'reference': reference.trim(),
    'notes': notes.trim(),
  };
}

class HrRepository {
  HrRepository(this._api);
  final ApiClient _api;

  List<JsonMap> _rows(dynamic res) =>
      res is List ? asMapList(res) : asMapList(asMap(res)['data']);

  // ── Staff ────────────────────────────────────────────────────────────
  Future<List<Staff>> staff({String? search}) async => _rows(
    await _api.get('/staff', query: {'search': search}),
  ).map(Staff.fromJson).toList();

  Future<Staff> staffMember(String id) async =>
      Staff.fromJson(await _api.getMap('/staff/$id'));
  Future<Staff> createStaff(Staff s) async =>
      Staff.fromJson(asMap(await _api.post('/staff', body: s.toJson())));
  Future<void> updateStaff(String id, Staff s) =>
      _api.put('/staff/$id', body: s.toJson());
  Future<void> deleteStaff(String id) => _api.delete('/staff/$id');

  Future<StaffBalance> balance(String id) async =>
      StaffBalance.fromJson(await _api.getMap('/staff/$id/balance'));

  /// staff id → balance owed (positive = owed to staff).
  Future<Map<String, double>> balances() async => asMap(
    await _api.get('/staff/balances'),
  ).map((k, v) => MapEntry(k, asDouble(v)));

  // ── Attendance ───────────────────────────────────────────────────────
  Future<List<Attendance>> attendance({
    required DateTime from,
    required DateTime to,
    String? staffId,
  }) async => _rows(
    await _api.get(
      '/attendance',
      query: {
        'start_date': ymd(from),
        'end_date': ymd(to),
        'staff_id': staffId,
      },
    ),
  ).map(Attendance.fromJson).toList();

  Future<AttendanceStats> attendanceStats(DateTime day) async =>
      AttendanceStats.fromJson(
        await _api.getMap('/attendance/stats', query: {'date': ymd(day)}),
      );

  /// Marks (or re-marks) a day for several staff at once.
  Future<void> markBulk(DateTime day, Map<String, String> statusByStaff) =>
      _api.post(
        '/attendance/bulk',
        body: {
          'date': ymd(day),
          'attendance': [
            for (final e in statusByStaff.entries)
              {'staff_id': e.key, 'status': e.value},
          ],
        },
      );

  Future<void> deleteAttendance(String id) => _api.delete('/attendance/$id');

  // ── Payroll ──────────────────────────────────────────────────────────
  Future<List<Payroll>> payrolls({String? staffId}) async => _rows(
    await _api.get('/payroll', query: {'staff_id': staffId}),
  ).map(Payroll.fromJson).toList();

  Future<Payroll> payroll(String id) async =>
      Payroll.fromJson(await _api.getMap('/payroll/$id'));

  Future<JsonMap> payrollStats() => _api.getMap('/payroll/stats');

  Future<PayrollCalc> calculate(
    String staffId,
    DateTime from,
    DateTime to,
  ) async => PayrollCalc.fromJson(
    await _api.getMap(
      '/payroll/calculate',
      query: {
        'staff_id': staffId,
        'start_date': ymd(from),
        'end_date': ymd(to),
      },
    ),
  );

  /// [status]: paid (pay [paidAmount] now, full net when 0) or pending (pay later).
  Future<Payroll> createPayroll({
    required String staffId,
    required DateTime paymentDate,
    DateTime? from,
    DateTime? to,
    bool payAllDue = false,
    double deductions = 0,
    double bonus = 0,
    String status = 'paid',
    double paidAmount = 0,
    Payout payout = const Payout(),
  }) async => Payroll.fromJson(
    asMap(
      await _api.post(
        '/payroll',
        body: {
          'staff_id': staffId,
          'payment_date': apiDate(paymentDate),
          if (!payAllDue && from != null) 'start_date': apiDate(from),
          if (!payAllDue && to != null) 'end_date': apiDate(to),
          'pay_all_due': payAllDue,
          'deductions': deductions,
          'bonus': bonus,
          'status': status,
          'paid_amount': status == 'pending' ? 0 : paidAmount,
          ...payout.toJson(),
        },
      ),
    ),
  );

  Future<void> payPayroll(
    String id, {
    required double amount,
    required DateTime date,
    Payout payout = const Payout(),
  }) => _api.post(
    '/payroll/$id/payments',
    body: {'amount': amount, 'payment_date': apiDate(date), ...payout.toJson()},
  );

  Future<void> cancelPayroll(String id) => _api.post('/payroll/$id/cancel');

  // ── Advances ─────────────────────────────────────────────────────────
  Future<List<StaffAdvance>> advances({
    String? staffId,
    String? status,
  }) async => _rows(
    await _api.get(
      '/staff/advances',
      query: {'staff_id': staffId, 'status': status},
    ),
  ).map(StaffAdvance.fromJson).toList();

  Future<void> createAdvance({
    required String staffId,
    required double amount,
    required DateTime date,
    String reason = '',
    DateTime? expectedRecovery,
    Payout payout = const Payout(),
  }) => _api.post(
    '/staff/advances',
    body: {
      'staff_id': staffId,
      'amount': amount,
      'reason': reason.trim(),
      'advance_date': apiDate(date),
      'expected_recovery_date': apiDateOrNull(expectedRecovery),
      ...payout.toJson(),
    },
  );

  Future<void> recoverAdvance(String id, double amount, {String notes = ''}) =>
      _api.post(
        '/staff/advances/$id/recover',
        body: {'recovery_amount': amount, 'notes': notes.trim()},
      );

  // ── Deductions ───────────────────────────────────────────────────────
  Future<List<StaffDeduction>> deductions({String? staffId}) async => _rows(
    await _api.get('/staff/deductions', query: {'staff_id': staffId}),
  ).map(StaffDeduction.fromJson).toList();

  Future<void> createDeduction({
    required String staffId,
    required String type,
    required double amount,
    required DateTime date,
    String description = '',
    bool recurring = false,
    int installments = 0,
  }) => _api.post(
    '/staff/deductions',
    body: {
      'staff_id': staffId,
      'deduction_type': type,
      'amount': amount,
      'description': description.trim(),
      'deduction_date': apiDate(date),
      'is_recurring': recurring,
      'recurring_period': recurring ? 'monthly' : '',
      'total_installments': recurring ? installments : 0,
    },
  );

  Future<void> deleteDeduction(String id) =>
      _api.delete('/staff/deductions/$id');

  // ── Extra amounts ────────────────────────────────────────────────────
  Future<List<StaffExtra>> extras({String? staffId}) async => _rows(
    await _api.get('/staff/extras', query: {'staff_id': staffId}),
  ).map(StaffExtra.fromJson).toList();

  Future<void> createExtra({
    required String staffId,
    required String direction,
    required double amount,
    required DateTime date,
    String reason = '',
    bool payNow = false,
    Payout payout = const Payout(),
  }) => _api.post(
    '/staff/extras',
    body: {
      'staff_id': staffId,
      'direction': direction,
      'amount': amount,
      'reason': reason.trim(),
      'entry_date': apiDate(date),
      'redeem_now': payNow,
      ...payout.toJson(),
    },
  );

  Future<void> redeemExtra(
    String id, {
    required DateTime date,
    Payout payout = const Payout(),
  }) => _api.post(
    '/staff/extras/$id/redeem',
    body: {'payment_date': apiDate(date), ...payout.toJson()},
  );

  // ── Reminder ─────────────────────────────────────────────────────────
  Future<AttendanceReminder> reminder() async => AttendanceReminder.fromJson(
    await _api.getMap('/settings/attendance-reminder'),
  );
  Future<void> saveReminder(AttendanceReminder r) =>
      _api.put('/settings/attendance-reminder', body: r.toJson());
}

final hrRepositoryProvider = Provider(
  (ref) => HrRepository(ref.watch(apiClientProvider)),
);

final staffListProvider = FutureProvider.autoDispose<List<Staff>>((ref) {
  ref.watch(activeStoreIdProvider);
  ref.watch(dataRevisionProvider);
  return ref.watch(hrRepositoryProvider).staff();
});

final staffBalancesProvider = FutureProvider.autoDispose<Map<String, double>>((
  ref,
) {
  ref.watch(activeStoreIdProvider);
  ref.watch(dataRevisionProvider);
  return ref.watch(hrRepositoryProvider).balances();
});

final staffMemberProvider = FutureProvider.autoDispose.family<Staff, String>((
  ref,
  id,
) {
  ref.watch(dataRevisionProvider);
  return ref.watch(hrRepositoryProvider).staffMember(id);
});

final staffBalanceProvider = FutureProvider.autoDispose
    .family<StaffBalance, String>((ref, id) {
      ref.watch(dataRevisionProvider);
      return ref.watch(hrRepositoryProvider).balance(id);
    });
