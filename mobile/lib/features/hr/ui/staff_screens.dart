import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/revision.dart';
import '../../../core/models/hr.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/utils/share_utils.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/form_widgets.dart';
import '../../../shared/widgets/paged_list.dart';
import '../data/hr_repository.dart';
import 'hr_widgets.dart';
import 'staff_money_sheets.dart';

// ── List ────────────────────────────────────────────────────────────────

class StaffScreen extends ConsumerStatefulWidget {
  const StaffScreen({super.key});

  @override
  ConsumerState<StaffScreen> createState() => _ListState();
}

class _ListState extends ConsumerState<StaffScreen> {
  String _q = '';
  bool _showInactive = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(staffListProvider);
    final balances =
        ref.watch(staffBalancesProvider).asData?.value ??
        const <String, double>{};
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff'),
        actions: [
          IconButton(
            tooltip: 'Attendance',
            icon: const Icon(Icons.event_available_rounded),
            onPressed: () => context.push('/attendance'),
          ),
          IconButton(
            tooltip: 'Payroll',
            icon: const Icon(Icons.payments_rounded),
            onPressed: () => context.push('/payroll'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new-staff',
        onPressed: () => context.push('/staff/new'),
        icon: const Icon(Icons.person_add_alt_rounded),
        label: const Text('Add staff'),
      ),
      body: async.when(
        loading: () => const SkeletonList(),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(staffListProvider),
        ),
        data: (all) {
          final q = _q.toLowerCase();
          final list = all
              .where((s) => _showInactive || s.isActive)
              .where(
                (s) =>
                    q.isEmpty ||
                    s.name.toLowerCase().contains(q) ||
                    s.phone.contains(q) ||
                    s.role.toLowerCase().contains(q),
              )
              .toList();
          final owed = list.fold<double>(
            0,
            (sum, s) => sum + (balances[s.id] ?? 0).clamp(0, double.infinity),
          );
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(staffListProvider);
              ref.invalidate(staffBalancesProvider);
            },
            child: ContentWidth(
              maxWidth: 900,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 96),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Spacing.lg,
                      Spacing.sm,
                      Spacing.lg,
                      Spacing.sm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(Spacing.lg),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Salary owed to ${list.length} staff',
                                    style: context.text.bodyMedium,
                                  ),
                                ),
                                Text(
                                  money(owed),
                                  style: context.text.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: hrAccent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: Spacing.md),
                        SearchField(
                          hint: 'Search name, phone or role',
                          onChanged: (v) => setState(() => _q = v),
                        ),
                        if (all.any((s) => !s.isActive))
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Show inactive staff'),
                            value: _showInactive,
                            onChanged: (v) => setState(() => _showInactive = v),
                          ),
                      ],
                    ),
                  ),
                  if (list.isEmpty)
                    EmptyState(
                      icon: Icons.people_alt_rounded,
                      title: all.isEmpty ? 'No staff yet' : 'No matching staff',
                      message: all.isEmpty
                          ? 'Add your team to track attendance and pay salaries.'
                          : null,
                    ),
                  for (final s in list)
                    ListTile(
                      onTap: () => context.push('/staff/${s.id}'),
                      leading: InitialsAvatar(
                        s.name,
                        color: s.isActive ? null : StatusColors.neutral,
                      ),
                      title: Text(
                        s.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        [
                          if (s.role.isNotEmpty) s.role,
                          '${moneyShort(s.salary)} ${s.salaryLabel}',
                          if (!s.isActive) 'Inactive',
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: (balances[s.id] ?? 0).abs() < 0.5
                          ? null
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  money((balances[s.id] ?? 0).abs()),
                                  style: context.text.labelLarge?.copyWith(
                                    color: (balances[s.id] ?? 0) > 0
                                        ? hrAccent
                                        : StatusColors.success,
                                  ),
                                ),
                                Text(
                                  (balances[s.id] ?? 0) > 0
                                      ? 'owed'
                                      : 'advance',
                                  style: context.text.labelSmall,
                                ),
                              ],
                            ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Detail ──────────────────────────────────────────────────────────────

typedef _MonthKey = (String, DateTime);

final _monthAttendanceProvider = FutureProvider.autoDispose
    .family<List<Attendance>, _MonthKey>((ref, k) {
      ref.watch(dataRevisionProvider);
      final m = k.$2;
      return ref
          .watch(hrRepositoryProvider)
          .attendance(
            from: m,
            to: DateTime(m.year, m.month + 1, 0),
            staffId: k.$1,
          );
    });

final _staffMoneyProvider = FutureProvider.autoDispose
    .family<
      (
        List<Payroll>,
        List<StaffAdvance>,
        List<StaffDeduction>,
        List<StaffExtra>,
      ),
      String
    >((ref, id) async {
      ref.watch(dataRevisionProvider);
      final repo = ref.watch(hrRepositoryProvider);
      final r = await Future.wait<Object>([
        repo.payrolls(staffId: id),
        repo.advances(staffId: id),
        repo.deductions(staffId: id),
        repo.extras(staffId: id),
      ]);
      return (
        r[0] as List<Payroll>,
        r[1] as List<StaffAdvance>,
        r[2] as List<StaffDeduction>,
        r[3] as List<StaffExtra>,
      );
    });

class StaffDetailScreen extends ConsumerStatefulWidget {
  const StaffDetailScreen({super.key, required this.staffId});
  final String staffId;

  @override
  ConsumerState<StaffDetailScreen> createState() => _DetailState();
}

class _DetailState extends ConsumerState<StaffDetailScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  Future<void> _delete(Staff s) async {
    final ok = await confirmSheet(
      context,
      title: 'Delete ${s.name}?',
      message:
          'Consider marking them inactive instead to keep their history visible.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(hrRepositoryProvider).deleteStaff(s.id);
      ref.read(dataRevisionProvider.notifier).bump();
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(staffMemberProvider(widget.staffId));
    final s = async.asData?.value;
    return Scaffold(
      appBar: AppBar(
        title: Text(s?.name ?? 'Staff'),
        actions: [
          if (s != null) ...[
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push('/staff/${s.id}/edit'),
            ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(s),
            ),
          ],
        ],
      ),
      bottomNavigationBar: s == null
          ? null
          : SaveBar(
              label: 'Pay salary',
              onPressed: () => context.push('/payroll/new?staff=${s.id}'),
            ),
      body: async.when(
        loading: () => const SkeletonList(count: 6),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(staffMemberProvider(widget.staffId)),
        ),
        data: (s) => RefreshIndicator(
          onRefresh: () async => ref.read(dataRevisionProvider.notifier).bump(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              Spacing.lg,
              Spacing.sm,
              Spacing.lg,
              Spacing.xxl,
            ),
            children: [
              ContentWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(staff: s),
                    const SizedBox(height: Spacing.md),
                    _BalanceCard(staffId: s.id),
                    const SizedBox(height: Spacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => showAdvanceSheet(context, s),
                            icon: const Icon(
                              Icons.north_east_rounded,
                              size: 18,
                            ),
                            label: const Text('Advance'),
                          ),
                        ),
                        const SizedBox(width: Spacing.sm),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => showExtraSheet(context, s),
                            icon: const Icon(Icons.add_card_rounded, size: 18),
                            label: const Text('Extra'),
                          ),
                        ),
                        const SizedBox(width: Spacing.sm),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => showDeductionSheet(context, s),
                            icon: const Icon(
                              Icons.remove_circle_outline_rounded,
                              size: 18,
                            ),
                            label: const Text('Deduct'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Spacing.lg),
                    _AttendanceCard(
                      staffId: s.id,
                      month: _month,
                      onMonth: (m) => setState(() => _month = m),
                    ),
                    const SizedBox(height: Spacing.lg),
                    _MoneyHistory(staffId: s.id),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.staff});
  final Staff staff;

  @override
  Widget build(BuildContext context) {
    final s = staff;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                InitialsAvatar(s.name, size: 52),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name, style: context.text.titleMedium),
                      if (s.role.isNotEmpty)
                        Text(s.role, style: context.text.bodySmall),
                      const SizedBox(height: 4),
                      Text(
                        '${money(s.salary)} ${s.salaryLabel}',
                        style: context.text.labelLarge,
                      ),
                    ],
                  ),
                ),
                if (!s.isActive)
                  const StatusChip('inactive', label: 'Inactive'),
              ],
            ),
            if (s.phone.isNotEmpty) ...[
              const SizedBox(height: Spacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => callPhone(context, s.phone),
                      icon: const Icon(Icons.call_outlined, size: 18),
                      label: const Text('Call'),
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => openWhatsApp(context, s.phone),
                      icon: const Icon(Icons.chat_outlined, size: 18),
                      label: const Text('WhatsApp'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BalanceCard extends ConsumerWidget {
  const _BalanceCard({required this.staffId});
  final String staffId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(staffBalanceProvider(staffId));
    return async.when(
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(Spacing.lg),
          child: LinearProgressIndicator(),
        ),
      ),
      error: (e, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Text(errorMessage(e)),
        ),
      ),
      data: (b) => SectionCard(
        title: b.balance >= 0 ? 'Owed to staff' : 'Staff owes you',
        trailing: Text(
          money(b.balance.abs()),
          style: context.text.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: b.balance >= 0 ? hrAccent : StatusColors.success,
          ),
        ),
        child: Column(
          children: [
            if (b.payableFromPayrolls > 0)
              KeyValueRow('Unpaid payroll', money(b.payableFromPayrolls)),
            if (b.earnedUnpaid > 0)
              KeyValueRow(
                'Earned, not yet on a payroll',
                '${money(b.earnedUnpaid)} · ${qty(b.uncoveredDays)} days',
              ),
            if (b.extrasAddPending > 0)
              KeyValueRow('Pending extras', money(b.extrasAddPending)),
            if (b.advancesPending > 0)
              KeyValueRow(
                'Advances to recover',
                '− ${money(b.advancesPending)}',
              ),
            if (b.deductionsPending > 0)
              KeyValueRow(
                'Pending deductions',
                '− ${money(b.deductionsPending)}',
              ),
            if (b.extrasDeductPending > 0)
              KeyValueRow(
                'Extra payouts to recover',
                '− ${money(b.extrasDeductPending)}',
              ),
            KeyValueRow('Salary paid so far', money(b.salaryPaid)),
          ],
        ),
      ),
    );
  }
}

class _AttendanceCard extends ConsumerWidget {
  const _AttendanceCard({
    required this.staffId,
    required this.month,
    required this.onMonth,
  });
  final String staffId;
  final DateTime month;
  final ValueChanged<DateTime> onMonth;

  static Color _color(String status) => switch (status) {
    AttendanceStatus.present => StatusColors.success,
    AttendanceStatus.absent => StatusColors.danger,
    AttendanceStatus.halfDay => StatusColors.warning,
    AttendanceStatus.paidLeave => StatusColors.info,
    _ => StatusColors.neutral,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_monthAttendanceProvider((staffId, month)));
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading =
        DateTime(month.year, month.month, 1).weekday - 1; // Monday-first
    final now = DateTime.now();
    final isCurrent = month.year == now.year && month.month == now.month;
    return SectionCard(
      title: 'Attendance',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Previous month',
            onPressed: () => onMonth(DateTime(month.year, month.month - 1)),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Text(
            '${_monthName(month.month)} ${month.year}',
            style: context.text.labelLarge,
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Next month',
            onPressed: isCurrent
                ? null
                : () => onMonth(DateTime(month.year, month.month + 1)),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
      child: async.when(
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (e, _) => Text(errorMessage(e)),
        data: (rows) {
          final byDay = {
            for (final a in rows)
              if (a.date != null) a.date!.day: a.status,
          };
          int count(String s) => byDay.values.where((v) => v == s).length;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  for (final d in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                    Expanded(
                      child: Center(
                        child: Text(d, style: context.text.labelSmall),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                children: [
                  for (var i = 0; i < leading; i++) const SizedBox.shrink(),
                  for (var day = 1; day <= daysInMonth; day++)
                    Container(
                      decoration: BoxDecoration(
                        color: byDay[day] == null
                            ? context.colors.surfaceContainerHigh
                            : _color(byDay[day]!).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('$day', style: context.text.labelSmall),
                          if (byDay[day] != null)
                            Text(
                              AttendanceStatus.letter(byDay[day]!),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _color(byDay[day]!),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: Spacing.md),
              Wrap(
                spacing: Spacing.md,
                runSpacing: 4,
                children: [
                  for (final (s, label, _) in AttendanceStatus.all)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, size: 10, color: _color(s)),
                        const SizedBox(width: 4),
                        Text(
                          '$label ${count(s)}',
                          style: context.text.labelSmall,
                        ),
                      ],
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

String _monthName(int m) => const [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
][m - 1];

class _MoneyHistory extends ConsumerWidget {
  const _MoneyHistory({required this.staffId});
  final String staffId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_staffMoneyProvider(staffId));
    return async.when(
      loading: () => const SizedBox(height: 160, child: SkeletonList(count: 3)),
      error: (e, _) => ErrorView(
        error: e,
        onRetry: () => ref.invalidate(_staffMoneyProvider(staffId)),
      ),
      data: (d) {
        final (payrolls, advances, deductions, extras) = d;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionCard(
              title: 'Payroll',
              padding: const EdgeInsets.only(bottom: Spacing.xs),
              child: payrolls.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(Spacing.lg),
                      child: Text('No salary paid yet.'),
                    )
                  : Column(
                      children: [
                        for (final p in payrolls.take(12))
                          ListTile(
                            dense: true,
                            onTap: () => context.push('/payroll/${p.id}'),
                            title: Text(
                              p.isSettlement
                                  ? 'All dues'
                                  : '${dateShort(p.startDate)} – ${dateShort(p.endDate)}',
                            ),
                            subtitle: Text(
                              '${p.number} · ${dateText(p.paymentDate)}',
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  money(p.netSalary),
                                  style: context.text.labelLarge,
                                ),
                                StatusChip(p.status),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: Spacing.md),
            SectionCard(
              title: 'Advances',
              padding: const EdgeInsets.only(bottom: Spacing.xs),
              child: advances.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(Spacing.lg),
                      child: Text('No advances.'),
                    )
                  : Column(
                      children: [
                        for (final a in advances)
                          ListTile(
                            dense: true,
                            title: Text(a.reason.isEmpty ? a.number : a.reason),
                            subtitle: Text(
                              '${dateText(a.date)} · ${money(a.amount)} given · ${money(a.recovered)} recovered',
                            ),
                            trailing: a.pending > 0
                                ? TextButton(
                                    onPressed: () =>
                                        showRecoverSheet(context, a),
                                    child: Text(
                                      'Recover ${moneyShort(a.pending)}',
                                    ),
                                  )
                                : const StatusChip('recovered'),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: Spacing.md),
            SectionCard(
              title: 'Extras',
              padding: const EdgeInsets.only(bottom: Spacing.xs),
              child: extras.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(Spacing.lg),
                      child: Text('No extra amounts.'),
                    )
                  : Column(
                      children: [
                        for (final x in extras)
                          ListTile(
                            dense: true,
                            leading: Icon(
                              x.isAdd
                                  ? Icons.add_circle_outline
                                  : Icons.remove_circle_outline,
                              color: x.isAdd
                                  ? StatusColors.success
                                  : StatusColors.warning,
                            ),
                            title: Text(
                              x.reason.isEmpty
                                  ? (x.isAdd ? 'Incentive' : 'Extra payout')
                                  : x.reason,
                            ),
                            subtitle: Text(
                              '${dateText(x.date)} · ${x.isAdd ? 'owed to staff' : 'recovered from salary'}',
                            ),
                            trailing: x.isAdd && x.canRedeem
                                ? TextButton(
                                    onPressed: () =>
                                        showRedeemSheet(context, x),
                                    child: Text('Pay ${moneyShort(x.amount)}'),
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        money(x.amount),
                                        style: context.text.labelLarge,
                                      ),
                                      StatusChip(x.status),
                                    ],
                                  ),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: Spacing.md),
            SectionCard(
              title: 'Deductions',
              padding: const EdgeInsets.only(bottom: Spacing.xs),
              child: deductions.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(Spacing.lg),
                      child: Text('No deductions.'),
                    )
                  : Column(
                      children: [
                        for (final x in deductions)
                          ListTile(
                            dense: true,
                            title: Text(StaffDeduction.typeLabel(x.type)),
                            subtitle: Text(
                              [
                                dateText(x.date),
                                if (x.description.isNotEmpty) x.description,
                                if (x.isRecurring)
                                  '${x.installmentsPaid}/${x.installments} instalments',
                              ].join(' · '),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  money(x.amount),
                                  style: context.text.labelLarge,
                                ),
                                StatusChip(x.status),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ── Create / edit ───────────────────────────────────────────────────────

class StaffFormScreen extends ConsumerWidget {
  const StaffFormScreen({super.key, this.staffId});
  final String? staffId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (staffId == null) return const _Form();
    return ref
        .watch(staffMemberProvider(staffId!))
        .when(
          loading: () =>
              Scaffold(appBar: AppBar(), body: const SkeletonList(count: 5)),
          error: (e, _) => Scaffold(
            appBar: AppBar(),
            body: ErrorView(error: e),
          ),
          data: (s) => _Form(existing: s),
        );
  }
}

class _Form extends ConsumerStatefulWidget {
  const _Form({this.existing});
  final Staff? existing;

  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  final _form = GlobalKey<FormState>();
  late final Staff? _e = widget.existing;
  late final _name = TextEditingController(text: _e?.name);
  late final _phone = TextEditingController(text: _e?.phone);
  late final _email = TextEditingController(text: _e?.email);
  late final _address = TextEditingController(text: _e?.address);
  late final _designation = TextEditingController(text: _e?.designation);
  late final _department = TextEditingController(text: _e?.department);
  late final _salary = TextEditingController(
    text: NumberField.text(_e?.salary ?? 0),
  );
  late final _bank = TextEditingController(text: _e?.bankName);
  late final _account = TextEditingController(text: _e?.accountNumber);
  late final _ifsc = TextEditingController(text: _e?.ifscCode);
  late final _aadhar = TextEditingController(text: _e?.aadharNumber);
  late final _pan = TextEditingController(text: _e?.panNumber);
  late final _notes = TextEditingController(text: _e?.notes);
  late String _salaryType = _e?.salaryType ?? 'monthly';
  late DateTime _joined = _e?.joiningDate ?? DateTime.now();
  late bool _active = _e?.isActive ?? true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [
      _name,
      _phone,
      _email,
      _address,
      _designation,
      _department,
      _salary,
      _bank,
      _account,
      _ifsc,
      _aadhar,
      _pan,
      _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final s = Staff(
      id: _e?.id ?? '',
      name: _name.text,
      phone: _phone.text,
      email: _email.text,
      address: _address.text,
      designation: _designation.text,
      department: _department.text,
      joiningDate: _joined,
      salary: NumberField.parse(_salary),
      salaryType: _salaryType,
      bankName: _bank.text,
      accountNumber: _account.text,
      ifscCode: _ifsc.text,
      aadharNumber: _aadhar.text,
      panNumber: _pan.text,
      isActive: _active,
      notes: _notes.text,
    );
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = ref.read(hrRepositoryProvider);
      _e == null ? await repo.createStaff(s) : await repo.updateStaff(_e.id, s);
      ref.read(dataRevisionProvider.notifier).bump();
      if (!mounted) return;
      showSnack(context, _e == null ? '${s.name} added' : 'Changes saved');
      context.pop();
    } catch (e) {
      setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_e == null ? 'New staff member' : 'Edit staff'),
      ),
      bottomNavigationBar: SaveBar(
        label: _e == null ? 'Add staff' : 'Save changes',
        busy: _busy,
        onPressed: _save,
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(Spacing.lg),
          children: [
            ContentWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null) ErrorBanner(_error!),
                  FormSection(
                    title: 'Basic details',
                    children: [
                      TextFormField(
                        controller: _name,
                        autofocus: _e == null,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'Name *'),
                        validator: (v) => Validators.required(v, 'Name'),
                      ),
                      FieldRow(
                        children: [
                          TextFormField(
                            controller: _phone,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Phone',
                            ),
                            validator: Validators.optionalPhone,
                          ),
                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                            ),
                            validator: Validators.optionalEmail,
                          ),
                        ],
                      ),
                      FieldRow(
                        children: [
                          TextFormField(
                            controller: _designation,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Designation',
                            ),
                          ),
                          TextFormField(
                            controller: _department,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Department',
                            ),
                          ),
                        ],
                      ),
                      DateField(
                        label: 'Joining date',
                        value: _joined,
                        onChanged: (d) =>
                            setState(() => _joined = d ?? _joined),
                      ),
                      TextFormField(
                        controller: _address,
                        maxLines: 2,
                        minLines: 1,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(labelText: 'Address'),
                      ),
                    ],
                  ),
                  FormSection(
                    title: 'Salary',
                    children: [
                      SegmentedButton<String>(
                        showSelectedIcon: false,
                        segments: [
                          for (final (v, l) in Staff.salaryTypes)
                            ButtonSegment(value: v, label: Text(l)),
                        ],
                        selected: {_salaryType},
                        onSelectionChanged: (s) =>
                            setState(() => _salaryType = s.first),
                      ),
                      NumberField(
                        controller: _salary,
                        label: switch (_salaryType) {
                          'daily' => 'Daily wage *',
                          'hourly' => 'Hourly rate *',
                          _ => 'Monthly salary *',
                        },
                        validator: (v) => Validators.number(
                          v,
                          required: true,
                          field: 'Salary',
                        ),
                      ),
                    ],
                  ),
                  FormSection(
                    title: 'Bank & IDs',
                    children: [
                      TextFormField(
                        controller: _bank,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Bank name',
                        ),
                      ),
                      FieldRow(
                        children: [
                          TextFormField(
                            controller: _account,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Account number',
                            ),
                          ),
                          TextFormField(
                            controller: _ifsc,
                            textCapitalization: TextCapitalization.characters,
                            maxLength: 11,
                            decoration: const InputDecoration(
                              labelText: 'IFSC',
                              counterText: '',
                            ),
                          ),
                        ],
                      ),
                      FieldRow(
                        children: [
                          TextFormField(
                            controller: _aadhar,
                            keyboardType: TextInputType.number,
                            maxLength: 12,
                            decoration: const InputDecoration(
                              labelText: 'Aadhaar',
                              counterText: '',
                            ),
                          ),
                          TextFormField(
                            controller: _pan,
                            textCapitalization: TextCapitalization.characters,
                            maxLength: 10,
                            decoration: const InputDecoration(
                              labelText: 'PAN',
                              counterText: '',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  FormSection(
                    title: 'More',
                    children: [
                      TextFormField(
                        controller: _notes,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'Notes'),
                      ),
                      if (_e != null)
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Active'),
                          subtitle: const Text(
                            'Inactive staff are left out of attendance',
                          ),
                          value: _active,
                          onChanged: (v) => setState(() => _active = v),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
