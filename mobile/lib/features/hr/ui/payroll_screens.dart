import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/json.dart';
import '../../../core/api/revision.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/models/hr.dart';
import '../../../core/models/payment.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/doc_widgets.dart';
import '../../../shared/widgets/form_widgets.dart';
import '../data/hr_repository.dart';
import 'hr_widgets.dart';

final _payrollsProvider = FutureProvider.autoDispose<List<Payroll>>((ref) {
  ref.watch(activeStoreIdProvider);
  ref.watch(dataRevisionProvider);
  return ref.watch(hrRepositoryProvider).payrolls();
});

final _payrollStatsProvider = FutureProvider.autoDispose<JsonMap>((ref) {
  ref.watch(activeStoreIdProvider);
  ref.watch(dataRevisionProvider);
  return ref.watch(hrRepositoryProvider).payrollStats();
});

String payrollPeriod(Payroll p) => p.isSettlement
    ? 'All dues'
    : '${dateShort(p.startDate)} – ${dateShort(p.endDate)}';

// ── List ────────────────────────────────────────────────────────────────

class PayrollScreen extends ConsumerStatefulWidget {
  const PayrollScreen({super.key});

  @override
  ConsumerState<PayrollScreen> createState() => _ListState();
}

class _ListState extends ConsumerState<PayrollScreen> {
  String? _status;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_payrollsProvider);
    final stats = ref.watch(_payrollStatsProvider).asData?.value;
    return Scaffold(
      appBar: AppBar(title: const Text('Payroll')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new-payroll',
        onPressed: () => context.push('/payroll/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Pay salary'),
      ),
      body: async.when(
        loading: () => const SkeletonList(),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(_payrollsProvider),
        ),
        data: (all) {
          final list = _status == null
              ? all
              : all.where((p) => p.status == _status).toList();
          final due = all.fold<double>(0, (s, p) => s + p.due);
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_payrollsProvider),
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
                      0,
                    ),
                    child: SummaryStrip(
                      cells: [
                        (
                          'Paid this month',
                          asDouble(stats?['this_month']),
                          null,
                        ),
                        (
                          'Still due',
                          due,
                          due > 0 ? StatusColors.danger : null,
                        ),
                      ],
                    ),
                  ),
                  ChipsHeader(
                    chips: [
                      for (final (v, l) in const [
                        (null, 'All'),
                        ('pending', 'Pending'),
                        ('partial', 'Partial'),
                        ('paid', 'Paid'),
                        ('cancelled', 'Cancelled'),
                      ])
                        ChoiceChip(
                          label: Text(l),
                          selected: _status == v,
                          onSelected: (_) => setState(() => _status = v),
                        ),
                    ],
                  ),
                  if (list.isEmpty)
                    const EmptyState(
                      icon: Icons.payments_rounded,
                      title: 'No payroll yet',
                      message:
                          'Pay a salary from here or from a staff member\'s page.',
                    ),
                  for (final p in list)
                    MoneyTile(
                      icon: Icons.payments_rounded,
                      accent: hrAccent,
                      title: p.staffName.isEmpty ? p.number : p.staffName,
                      subtitle:
                          '${payrollPeriod(p)} · ${p.number}${p.due > 0 ? ' · due ${moneyShort(p.due)}' : ''}',
                      amount: p.netSalary,
                      status: p.status,
                      struck: p.isCancelled,
                      onTap: () => context.push('/payroll/${p.id}'),
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

final _payrollProvider = FutureProvider.autoDispose.family<Payroll, String>((
  ref,
  id,
) {
  ref.watch(dataRevisionProvider);
  return ref.watch(hrRepositoryProvider).payroll(id);
});

class PayrollDetailScreen extends ConsumerWidget {
  const PayrollDetailScreen({super.key, required this.payrollId});
  final String payrollId;

  Future<void> _cancel(BuildContext context, WidgetRef ref, Payroll p) async {
    final ok = await confirmSheet(
      context,
      title: 'Cancel ${p.number}?',
      message:
          'Its payments are reversed from cash/bank and any recovered advances or extras become pending again.',
      confirmLabel: 'Cancel payroll',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(hrRepositoryProvider).cancelPayroll(p.id);
      ref.read(dataRevisionProvider.notifier).bump();
      if (context.mounted) showSnack(context, '${p.number} cancelled');
    } catch (e) {
      if (context.mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_payrollProvider(payrollId));
    final p = async.asData?.value;
    return Scaffold(
      appBar: AppBar(
        title: Text(p?.number ?? 'Payroll'),
        actions: [
          if (p != null && !p.isCancelled)
            IconButton(
              tooltip: 'Cancel payroll',
              icon: const Icon(Icons.block_rounded),
              onPressed: () => _cancel(context, ref, p),
            ),
        ],
      ),
      bottomNavigationBar: p == null || p.isCancelled || p.due <= 0.005
          ? null
          : SaveBar(
              label: 'Pay ${money(p.due)}',
              onPressed: () => _showPay(context, p),
            ),
      body: async.when(
        loading: () => const SkeletonList(count: 5),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(_payrollProvider(payrollId)),
        ),
        data: (p) => ListView(
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
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(Spacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () =>
                                      context.push('/staff/${p.staffId}'),
                                  child: Text(
                                    p.staffName.isEmpty ? 'Staff' : p.staffName,
                                    style: context.text.titleMedium,
                                  ),
                                ),
                              ),
                              StatusChip(p.status),
                            ],
                          ),
                          Text(payrollPeriod(p), style: context.text.bodySmall),
                          const SizedBox(height: Spacing.sm),
                          Text(
                            money(p.netSalary),
                            style: context.text.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${money(p.paidAmount)} paid · ${money(p.due)} due',
                            style: context.text.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Spacing.lg),
                  if (!p.isSettlement)
                    SectionCard(
                      title: 'Attendance',
                      child: Column(
                        children: [
                          KeyValueRow('Working days', qty(p.workingDays)),
                          KeyValueRow('Present', qty(p.presentDays)),
                          if (p.halfDays > 0)
                            KeyValueRow('Half days', qty(p.halfDays)),
                          if (p.paidLeaveDays > 0)
                            KeyValueRow('Paid leave', qty(p.paidLeaveDays)),
                          if (p.weeklyOffDays > 0)
                            KeyValueRow('Weekly off', qty(p.weeklyOffDays)),
                          if (p.absentDays > 0)
                            KeyValueRow('Absent', qty(p.absentDays)),
                        ],
                      ),
                    ),
                  const SizedBox(height: Spacing.lg),
                  SectionCard(
                    title: 'Salary',
                    child: Column(
                      children: [
                        KeyValueRow('Basic salary', money(p.basicSalary)),
                        if (p.bonus > 0)
                          KeyValueRow('Bonus & extras', money(p.bonus)),
                        if (p.deductions > 0)
                          KeyValueRow(
                            'Deductions & recoveries',
                            '− ${money(p.deductions)}',
                          ),
                        KeyValueRow(
                          'Net salary',
                          money(p.netSalary),
                          bold: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Spacing.lg),
                  SectionCard(
                    title: 'Payments',
                    padding: const EdgeInsets.only(bottom: Spacing.xs),
                    child: p.payments.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(Spacing.lg),
                            child: Text('Nothing paid yet.'),
                          )
                        : Column(
                            children: [
                              for (final pay in p.payments)
                                ListTile(
                                  dense: true,
                                  title: Text(
                                    '${pay.number} · ${PaymentMode.labelOf(pay.mode)}',
                                  ),
                                  subtitle: Text(
                                    [
                                      dateText(pay.date),
                                      if (pay.bankLabel != null) pay.bankLabel!,
                                    ].join(' · '),
                                  ),
                                  trailing: Text(
                                    money(pay.amount),
                                    style: context.text.labelLarge,
                                  ),
                                ),
                            ],
                          ),
                  ),
                  if (p.notes.isNotEmpty) ...[
                    const SizedBox(height: Spacing.lg),
                    SectionCard(title: 'Notes', child: Text(p.notes)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPay(BuildContext context, Payroll p) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _PaySheet(payroll: p),
  );
}

class _PaySheet extends ConsumerStatefulWidget {
  const _PaySheet({required this.payroll});
  final Payroll payroll;

  @override
  ConsumerState<_PaySheet> createState() => _PayState();
}

class _PayState extends ConsumerState<_PaySheet> {
  final _form = GlobalKey<FormState>();
  late final _amount = TextEditingController(
    text: NumberField.text(widget.payroll.due),
  );
  DateTime _date = DateTime.now();
  Payout _payout = const Payout();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(hrRepositoryProvider)
          .payPayroll(
            widget.payroll.id,
            amount: NumberField.parse(_amount),
            date: _date,
            payout: _payout,
          );
      ref.read(dataRevisionProvider.notifier).bump();
      if (!mounted) return;
      Navigator.pop(context);
      showSnack(context, '${money(NumberField.parse(_amount))} paid');
    } catch (e) {
      setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      Spacing.xl,
      0,
      Spacing.xl,
      MediaQuery.viewInsetsOf(context).bottom + Spacing.xl,
    ),
    child: Form(
      key: _form,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Pay salary', style: context.text.titleMedium),
            Text(
              '${money(widget.payroll.due)} due on ${widget.payroll.number}',
              style: context.text.bodySmall,
            ),
            const SizedBox(height: Spacing.lg),
            if (_error != null) ErrorBanner(_error!),
            NumberField(
              controller: _amount,
              label: 'Amount',
              validator: (v) {
                final e = Validators.number(
                  v,
                  required: true,
                  allowZero: false,
                  field: 'Amount',
                );
                if (e != null) return e;
                return (double.tryParse(v!) ?? 0) > widget.payroll.due + 0.01
                    ? 'More than the amount due'
                    : null;
              },
            ),
            const SizedBox(height: Spacing.md),
            DateField(
              label: 'Date',
              value: _date,
              onChanged: (d) => setState(() => _date = d ?? _date),
            ),
            const SizedBox(height: Spacing.md),
            PayoutPicker(onChanged: (p) => _payout = p),
            const SizedBox(height: Spacing.lg),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: const Text('Record payment'),
            ),
          ],
        ),
      ),
    ),
  );
}

// ── Run payroll ─────────────────────────────────────────────────────────

typedef _CalcKey = (String, DateTime, DateTime);

final _calcProvider = FutureProvider.autoDispose.family<PayrollCalc, _CalcKey>(
  (ref, k) => ref.watch(hrRepositoryProvider).calculate(k.$1, k.$2, k.$3),
);

class PayrollFormScreen extends ConsumerStatefulWidget {
  const PayrollFormScreen({super.key, this.staffId});
  final String? staffId;

  @override
  ConsumerState<PayrollFormScreen> createState() => _FormState();
}

class _FormState extends ConsumerState<PayrollFormScreen> {
  final _form = GlobalKey<FormState>();
  final _deduction = TextEditingController();
  final _bonus = TextEditingController();
  final _paid = TextEditingController();
  late String? _staffId = widget.staffId;
  bool _allDues = false;
  late DateTimeRange _period = () {
    final n = DateTime.now();
    return DateTimeRange(
      start: DateTime(n.year, n.month, 1),
      end: DateTime(n.year, n.month, n.day),
    );
  }();
  String _when = 'full'; // full | part | later
  DateTime _payDate = DateTime.now();
  Payout _payout = const Payout();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_deduction, _bonus, _paid]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_staffId == null) {
      setState(() => _error = 'Choose a staff member.');
      return;
    }
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final p = await ref
          .read(hrRepositoryProvider)
          .createPayroll(
            staffId: _staffId!,
            paymentDate: _payDate,
            from: _period.start,
            to: _period.end,
            payAllDue: _allDues,
            deductions: NumberField.parse(_deduction),
            bonus: NumberField.parse(_bonus),
            status: _when == 'later' ? 'pending' : 'paid',
            paidAmount: _when == 'part' ? NumberField.parse(_paid) : 0,
            payout: _payout,
          );
      ref.read(dataRevisionProvider.notifier).bump();
      if (!mounted) return;
      showSnack(context, 'Payroll ${p.number} saved');
      context.pushReplacement('/payroll/${p.id}');
    } catch (e) {
      setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final staff =
        ref
            .watch(staffListProvider)
            .asData
            ?.value
            .where((s) => s.isActive || s.id == _staffId)
            .toList() ??
        const <Staff>[];
    final calc = _staffId == null || _allDues
        ? null
        : ref.watch(_calcProvider((_staffId!, _period.start, _period.end)));
    final balance = _staffId == null
        ? null
        : ref.watch(staffBalanceProvider(_staffId!)).asData?.value;
    final net = calc?.asData?.value.netWith(
      deduction: NumberField.parse(_deduction),
      bonus: NumberField.parse(_bonus),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Pay salary')),
      bottomNavigationBar: SaveBar(
        label: _when == 'later' ? 'Save payroll' : 'Save & pay',
        busy: _busy,
        onPressed: _save,
        leading: net == null
            ? null
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Net salary', style: context.text.labelSmall),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      money(net),
                      style: context.text.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
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
                    title: 'Staff',
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _staffId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Staff member',
                        ),
                        items: [
                          for (final s in staff)
                            DropdownMenuItem(value: s.id, child: Text(s.name)),
                        ],
                        onChanged: (v) => setState(() => _staffId = v),
                      ),
                      SegmentedButton<bool>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(
                            value: false,
                            label: Text('For a period'),
                          ),
                          ButtonSegment(
                            value: true,
                            label: Text('Pay all dues'),
                          ),
                        ],
                        selected: {_allDues},
                        onSelectionChanged: (s) =>
                            setState(() => _allDues = s.first),
                      ),
                      if (!_allDues)
                        OutlinedButton.icon(
                          onPressed: () async {
                            final r = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(2015),
                              lastDate: DateTime.now(),
                              initialDateRange: _period,
                            );
                            if (r != null) setState(() => _period = r);
                          },
                          icon: const Icon(Icons.date_range_rounded),
                          label: Text(
                            '${dateText(_period.start)} – ${dateText(_period.end)}',
                          ),
                        )
                      else
                        Text(
                          balance == null
                              ? 'Settles everything owed: unpaid days, pending extras, minus advances and deductions.'
                              : 'Settles ${money(balance.balance)} owed: unpaid days, pending extras, minus advances and deductions.',
                          style: context.text.bodySmall,
                        ),
                    ],
                  ),
                  if (calc != null)
                    calc.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.only(bottom: Spacing.lg),
                        child: LinearProgressIndicator(),
                      ),
                      error: (e, _) => ErrorBanner(errorMessage(e)),
                      data: (c) => FormSection(
                        title: 'Calculation',
                        children: [
                          KeyValueRow(
                            'Present / working days',
                            '${qty(c.presentDays)} / ${qty(c.workingDays)}',
                          ),
                          if (c.halfDays > 0 ||
                              c.paidLeaveDays > 0 ||
                              c.weeklyOffDays > 0)
                            KeyValueRow(
                              'Half days · leave · week off',
                              '${qty(c.halfDays)} · ${qty(c.paidLeaveDays)} · ${qty(c.weeklyOffDays)}',
                            ),
                          KeyValueRow('Payable days', qty(c.payableDays)),
                          KeyValueRow(
                            'Salary for period',
                            money(c.calculatedSalary),
                          ),
                          if (c.extraAdd > 0)
                            KeyValueRow('Pending extras', money(c.extraAdd)),
                          if (c.periodDeductions > 0)
                            KeyValueRow(
                              'Deductions',
                              '− ${money(c.periodDeductions)}',
                            ),
                          if (c.advanceRecovery > 0)
                            KeyValueRow(
                              'Advance recovery',
                              '− ${money(c.advanceRecovery)}',
                            ),
                          if (c.extraDeduct > 0)
                            KeyValueRow(
                              'Extra payouts recovered',
                              '− ${money(c.extraDeduct)}',
                            ),
                          FieldRow(
                            children: [
                              NumberField(
                                controller: _deduction,
                                label: 'Other deduction',
                                onChanged: (_) => setState(() {}),
                                validator: (v) =>
                                    Validators.number(v, field: 'Deduction'),
                              ),
                              NumberField(
                                controller: _bonus,
                                label: 'Bonus',
                                onChanged: (_) => setState(() {}),
                                validator: (v) =>
                                    Validators.number(v, field: 'Bonus'),
                              ),
                            ],
                          ),
                          KeyValueRow(
                            'Net salary',
                            money(
                              c.netWith(
                                deduction: NumberField.parse(_deduction),
                                bonus: NumberField.parse(_bonus),
                              ),
                            ),
                            bold: true,
                          ),
                        ],
                      ),
                    ),
                  FormSection(
                    title: 'Payment',
                    children: [
                      SegmentedButton<String>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(value: 'full', label: Text('Pay full')),
                          ButtonSegment(value: 'part', label: Text('Pay part')),
                          ButtonSegment(
                            value: 'later',
                            label: Text('Pay later'),
                          ),
                        ],
                        selected: {_when},
                        onSelectionChanged: (s) =>
                            setState(() => _when = s.first),
                      ),
                      if (_when == 'part')
                        NumberField(
                          controller: _paid,
                          label: 'Amount paid now',
                          validator: (v) {
                            final e = Validators.number(
                              v,
                              required: true,
                              allowZero: false,
                              field: 'Amount',
                            );
                            if (e != null) return e;
                            return net != null &&
                                    (double.tryParse(v!) ?? 0) > net + 0.01
                                ? 'More than the net salary'
                                : null;
                          },
                        ),
                      DateField(
                        label: 'Payment date',
                        value: _payDate,
                        onChanged: (d) =>
                            setState(() => _payDate = d ?? _payDate),
                      ),
                      if (_when != 'later')
                        PayoutPicker(onChanged: (p) => _payout = p),
                    ],
                  ),
                  Text(
                    'The server works out the final amounts from attendance when you save.',
                    style: context.text.bodySmall,
                    textAlign: TextAlign.center,
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
