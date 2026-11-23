import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/common.dart';
import '../data/accounting_repository.dart';
import 'accounting_screen.dart';

/// Shared frame: a date control on top, the report below.
class _ReportFrame extends StatelessWidget {
  const _ReportFrame({
    required this.title,
    required this.dateControl,
    required this.body,
  });
  final String title;
  final Widget dateControl;
  final Widget body;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: ListView(
      padding: const EdgeInsets.all(Spacing.lg),
      children: [
        ContentWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              dateControl,
              const SizedBox(height: Spacing.lg),
              body,
            ],
          ),
        ),
      ],
    ),
  );
}

class _DateButton extends StatelessWidget {
  const _DateButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap,
    icon: const Icon(Icons.event_rounded),
    label: Text(label),
  );
}

Future<DateTime?> _pickDate(BuildContext context, DateTime initial) =>
    showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2015),
      lastDate: DateTime(DateTime.now().year + 1),
    );

Widget _balanceBanner(
  BuildContext context,
  bool balanced,
  String okText,
  String badText,
) => Container(
  padding: const EdgeInsets.all(Spacing.md),
  decoration: BoxDecoration(
    color: (balanced ? StatusColors.success : StatusColors.warning).withValues(
      alpha: 0.1,
    ),
    borderRadius: BorderRadius.circular(Radii.control),
  ),
  child: Row(
    children: [
      Icon(
        balanced ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
        color: balanced ? StatusColors.success : StatusColors.warning,
      ),
      const SizedBox(width: Spacing.sm),
      Expanded(child: Text(balanced ? okText : badText)),
    ],
  ),
);

Widget _rows(
  BuildContext context,
  List<ReportRow> rows, {
  required double Function(ReportRow) value,
}) => Column(
  children: [
    for (final r in rows)
      ListTile(
        dense: true,
        onTap: r.accountId.isEmpty
            ? null
            : () => context.push('/accounting/ledger/${r.accountId}'),
        leading: Text(r.code, style: context.text.labelMedium),
        title: Text(r.name),
        trailing: Text(money(value(r)), style: context.text.labelLarge),
      ),
  ],
);

// ── Trial balance ───────────────────────────────────────────────────────

final _tbProvider = FutureProvider.autoDispose.family<TrialBalance, DateTime>(
  (ref, d) => ref.watch(accountingRepositoryProvider).trialBalance(d),
);

class TrialBalanceScreen extends ConsumerStatefulWidget {
  const TrialBalanceScreen({super.key});

  @override
  ConsumerState<TrialBalanceScreen> createState() => _TbState();
}

class _TbState extends ConsumerState<TrialBalanceScreen> {
  DateTime _asOf = DateUtils.dateOnly(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_tbProvider(_asOf));
    return _ReportFrame(
      title: 'Trial balance',
      dateControl: _DateButton(
        label: 'As of ${dateText(_asOf)}',
        onTap: () async {
          final d = await _pickDate(context, _asOf);
          if (d != null) setState(() => _asOf = d);
        },
      ),
      body: async.when(
        loading: () =>
            const SizedBox(height: 300, child: SkeletonList(count: 5)),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(_tbProvider(_asOf)),
        ),
        data: (tb) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _balanceBanner(
              context,
              tb.isBalanced,
              'Debits equal credits.',
              'Out of balance by ${money((tb.totalDebit - tb.totalCredit).abs())}.',
            ),
            const SizedBox(height: Spacing.md),
            SectionCard(
              padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Account',
                            style: context.text.labelSmall,
                          ),
                        ),
                        SizedBox(
                          width: 96,
                          child: Text(
                            'Debit',
                            style: context.text.labelSmall,
                            textAlign: TextAlign.right,
                          ),
                        ),
                        SizedBox(
                          width: 96,
                          child: Text(
                            'Credit',
                            style: context.text.labelSmall,
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  for (final r in tb.rows)
                    InkWell(
                      onTap: r.accountId.isEmpty
                          ? null
                          : () => context.push(
                              '/accounting/ledger/${r.accountId}',
                            ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Spacing.lg,
                          vertical: 8,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: Text('${r.code} · ${r.name}')),
                            SizedBox(
                              width: 96,
                              child: Text(
                                r.debit == 0 ? '' : money(r.debit),
                                textAlign: TextAlign.right,
                              ),
                            ),
                            SizedBox(
                              width: 96,
                              child: Text(
                                r.credit == 0 ? '' : money(r.credit),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('Total', style: context.text.titleSmall),
                        ),
                        SizedBox(
                          width: 96,
                          child: Text(
                            money(tb.totalDebit),
                            style: context.text.titleSmall,
                            textAlign: TextAlign.right,
                          ),
                        ),
                        SizedBox(
                          width: 96,
                          child: Text(
                            money(tb.totalCredit),
                            style: context.text.titleSmall,
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
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

// ── Profit & loss ───────────────────────────────────────────────────────

final _plProvider = FutureProvider.autoDispose
    .family<ProfitLossStatement, DateTimeRange>(
      (ref, r) =>
          ref.watch(accountingRepositoryProvider).profitLoss(r.start, r.end),
    );

class ProfitLossScreen extends ConsumerStatefulWidget {
  const ProfitLossScreen({super.key});

  @override
  ConsumerState<ProfitLossScreen> createState() => _PlState();
}

class _PlState extends ConsumerState<ProfitLossScreen> {
  late DateTimeRange _range = DateTimeRange(
    start: fyStart(DateTime.now()),
    end: DateUtils.dateOnly(DateTime.now()),
  );

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_plProvider(_range));
    return _ReportFrame(
      title: 'Profit & loss',
      dateControl: _DateButton(
        label: '${dateText(_range.start)} – ${dateText(_range.end)}',
        onTap: () async {
          final r = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2015),
            lastDate: DateTime(DateTime.now().year + 1),
            initialDateRange: _range,
          );
          if (r != null) setState(() => _range = r);
        },
      ),
      body: async.when(
        loading: () =>
            const SizedBox(height: 300, child: SkeletonList(count: 5)),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(_plProvider(_range)),
        ),
        data: (pl) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(Spacing.lg),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        pl.netProfit >= 0 ? 'Net profit' : 'Net loss',
                        style: context.text.titleMedium,
                      ),
                    ),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          money(pl.netProfit.abs()),
                          style: context.text.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: pl.netProfit >= 0
                                ? StatusColors.success
                                : StatusColors.danger,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Spacing.lg),
            SectionCard(
              title: 'Income',
              trailing: Text(
                money(pl.totalIncome),
                style: context.text.labelLarge?.copyWith(
                  color: StatusColors.success,
                ),
              ),
              padding: const EdgeInsets.only(bottom: Spacing.xs),
              child: pl.income.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(Spacing.lg),
                      child: Text('No income in this period.'),
                    )
                  : _rows(context, pl.income, value: (r) => r.amount),
            ),
            const SizedBox(height: Spacing.md),
            SectionCard(
              title: 'Expenses',
              trailing: Text(
                money(pl.totalExpense),
                style: context.text.labelLarge?.copyWith(
                  color: StatusColors.danger,
                ),
              ),
              padding: const EdgeInsets.only(bottom: Spacing.xs),
              child: pl.expenses.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(Spacing.lg),
                      child: Text('No expenses in this period.'),
                    )
                  : _rows(context, pl.expenses, value: (r) => r.amount),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Balance sheet ───────────────────────────────────────────────────────

final _bsProvider = FutureProvider.autoDispose.family<BalanceSheet, DateTime>(
  (ref, d) => ref.watch(accountingRepositoryProvider).balanceSheet(d),
);

class BalanceSheetScreen extends ConsumerStatefulWidget {
  const BalanceSheetScreen({super.key});

  @override
  ConsumerState<BalanceSheetScreen> createState() => _BsState();
}

class _BsState extends ConsumerState<BalanceSheetScreen> {
  DateTime _asOf = DateUtils.dateOnly(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_bsProvider(_asOf));
    return _ReportFrame(
      title: 'Balance sheet',
      dateControl: _DateButton(
        label: 'As of ${dateText(_asOf)}',
        onTap: () async {
          final d = await _pickDate(context, _asOf);
          if (d != null) setState(() => _asOf = d);
        },
      ),
      body: async.when(
        loading: () =>
            const SizedBox(height: 300, child: SkeletonList(count: 5)),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(_bsProvider(_asOf)),
        ),
        data: (bs) {
          final rightSide = bs.totalLiabilities + bs.totalEquity;
          Widget section(String title, List<ReportRow> rows, double total) =>
              Padding(
                padding: const EdgeInsets.only(bottom: Spacing.md),
                child: SectionCard(
                  title: title,
                  trailing: Text(money(total), style: context.text.labelLarge),
                  padding: const EdgeInsets.only(bottom: Spacing.xs),
                  child: rows.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(Spacing.lg),
                          child: Text('Nothing here.'),
                        )
                      : _rows(context, rows, value: (r) => r.amount),
                ),
              );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _balanceBanner(
                context,
                bs.isBalanced,
                'Assets equal liabilities plus equity.',
                'Difference of ${money((bs.totalAssets - rightSide).abs())} between assets and liabilities + equity.',
              ),
              const SizedBox(height: Spacing.md),
              section('Assets', bs.assets, bs.totalAssets),
              section('Liabilities', bs.liabilities, bs.totalLiabilities),
              section('Equity', bs.equity, bs.totalEquity),
              KeyValueRow('Liabilities + equity', money(rightSide), bold: true),
            ],
          );
        },
      ),
    );
  }
}

// ── General ledger ──────────────────────────────────────────────────────

typedef _LedgerKey = (String, DateTimeRange?);

final _glProvider = FutureProvider.autoDispose
    .family<GeneralLedger, _LedgerKey>(
      (ref, k) => ref
          .watch(accountingRepositoryProvider)
          .ledger(k.$1, from: k.$2?.start, to: k.$2?.end),
    );

class GeneralLedgerScreen extends ConsumerStatefulWidget {
  const GeneralLedgerScreen({super.key, required this.accountId});
  final String accountId;

  @override
  ConsumerState<GeneralLedgerScreen> createState() => _GlState();
}

class _GlState extends ConsumerState<GeneralLedgerScreen> {
  DateTimeRange? _range;

  @override
  Widget build(BuildContext context) {
    final key = (widget.accountId, _range);
    final async = ref.watch(_glProvider(key));
    final account = async.asData?.value.account;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          account == null ? 'Ledger' : '${account.code} · ${account.name}',
        ),
      ),
      body: async.when(
        loading: () => const SkeletonList(),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(_glProvider(key)),
        ),
        data: (gl) => ListView(
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
                  Row(
                    children: [
                      Expanded(
                        child: _DateButton(
                          label: _range == null
                              ? 'All dates'
                              : '${dateShort(_range!.start)} – ${dateShort(_range!.end)}',
                          onTap: () async {
                            final r = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(2015),
                              lastDate: DateTime(DateTime.now().year + 1),
                              initialDateRange: _range,
                            );
                            if (r != null) setState(() => _range = r);
                          },
                        ),
                      ),
                      if (_range != null)
                        IconButton(
                          tooltip: 'Clear dates',
                          onPressed: () => setState(() => _range = null),
                          icon: const Icon(Icons.close_rounded),
                        ),
                    ],
                  ),
                  const SizedBox(height: Spacing.md),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(Spacing.lg),
                      child: Column(
                        children: [
                          KeyValueRow('Opening balance', money(gl.opening)),
                          KeyValueRow(
                            'Closing balance',
                            money(gl.closing),
                            bold: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Spacing.md),
                  if (gl.lines.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: Spacing.xl),
                      child: EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'No entries in this period',
                      ),
                    )
                  else
                    SectionCard(
                      title: 'Entries (${gl.lines.length})',
                      padding: const EdgeInsets.only(bottom: Spacing.xs),
                      child: Column(
                        children: [
                          for (final l in gl.lines.reversed)
                            ListTile(
                              dense: true,
                              title: Text(
                                l.description.isNotEmpty
                                    ? l.description
                                    : titleCase(l.type),
                                maxLines: 2,
                              ),
                              subtitle: Text(
                                [
                                  dateText(l.date),
                                  if (l.reference.isNotEmpty) l.reference,
                                ].join(' · '),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    l.debit > 0
                                        ? 'Dr ${money(l.debit)}'
                                        : 'Cr ${money(l.credit)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: l.debit > 0
                                          ? StatusColors.success
                                          : StatusColors.danger,
                                    ),
                                  ),
                                  Text(
                                    'Bal ${money(l.balance)}',
                                    style: context.text.labelSmall,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
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
