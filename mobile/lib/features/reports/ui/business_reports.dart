import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/revision.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/models/reports.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/paged_list.dart';
import '../data/report_period.dart';
import '../data/reports_repository.dart';
import 'report_widgets.dart';

// ── Day & period summary ────────────────────────────────────────────────

final _periodProvider = FutureProvider.autoDispose
    .family<PeriodReport, ReportPeriod>((ref, p) {
      ref.watch(activeStoreIdProvider);
      ref.watch(dataRevisionProvider);
      return ref.watch(reportsRepositoryProvider).period(p);
    });

class PeriodReportScreen extends ConsumerStatefulWidget {
  const PeriodReportScreen({super.key});

  @override
  ConsumerState<PeriodReportScreen> createState() => _PeriodState();
}

class _PeriodState extends ConsumerState<PeriodReportScreen> {
  ReportPeriod _p = ReportPeriod.today();

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_periodProvider(_p));
    final r = async.asData?.value;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Day & period summary'),
        actions: [
          ExportMenu(
            exports: ReportExports.period,
            query: _p.toQuery(),
            baseName: 'Summary',
          ),
        ],
      ),
      body: ReportBody(
        onRefresh: () async => ref.invalidate(_periodProvider(_p)),
        children: [
          PeriodBar(
            period: _p,
            serverLabel: r?.header.label,
            onChanged: (p) => setState(() => _p = p),
          ),
          const SizedBox(height: Spacing.lg),
          async.when(
            loading: reportLoading,
            error: (e, _) => ErrorView(
              error: e,
              onRetry: () => ref.invalidate(_periodProvider(_p)),
            ),
            data: (r) => _PeriodBody(r: r),
          ),
        ],
      ),
    );
  }
}

class _PeriodBody extends StatelessWidget {
  const _PeriodBody({required this.r});
  final PeriodReport r;

  @override
  Widget build(BuildContext context) {
    final cols = Breakpoints.columns(
      context,
      compactCols: 2,
      mediumCols: 4,
      expandedCols: 4,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ResponsiveGrid(
          columns: cols,
          children: [
            StatTile(
              label: 'Sales',
              value: moneyShort(r.sales.amount),
              icon: Icons.trending_up_rounded,
              accent: const Color(0xFF2563EB),
              caption: '${r.sales.count} invoices',
            ),
            StatTile(
              label: 'Profit',
              value: moneyShort(r.dailyProfit),
              icon: Icons.savings_rounded,
              accent: r.dailyProfit >= 0
                  ? StatusColors.success
                  : StatusColors.danger,
              caption: 'Product margin ${moneyShort(r.productProfit)}',
            ),
            StatTile(
              label: 'Money in',
              value: moneyShort(r.paymentsIn.amount),
              icon: Icons.call_received_rounded,
              accent: StatusColors.success,
              caption: '${r.paymentsIn.count} payments',
            ),
            StatTile(
              label: 'Money out',
              value: moneyShort(r.paymentsOut.amount + r.expenses.amount),
              icon: Icons.call_made_rounded,
              accent: StatusColors.danger,
              caption: 'Net flow ${moneyShort(r.netCashFlow)}',
            ),
          ],
        ),
        const SizedBox(height: Spacing.lg),
        SectionCard(
          title: 'Activity',
          child: Column(
            children: [
              AmountLine('Sales', r.sales.amount, count: r.sales.count),
              AmountLine(
                'Sales returns',
                r.salesReturns.amount,
                count: r.salesReturns.count,
                negative: true,
              ),
              AmountLine(
                'Credit notes',
                r.creditNotes.amount,
                count: r.creditNotes.count,
                negative: true,
              ),
              AmountLine(
                'Purchases',
                r.purchases.amount,
                count: r.purchases.count,
              ),
              AmountLine(
                'Purchase returns',
                r.purchaseReturns.amount,
                count: r.purchaseReturns.count,
                negative: true,
              ),
              AmountLine(
                'Debit notes',
                r.debitNotes.amount,
                count: r.debitNotes.count,
                negative: true,
              ),
              AmountLine(
                'Expenses',
                r.expenses.amount,
                count: r.expenses.count,
              ),
              if (r.profitDistributions.count > 0)
                AmountLine(
                  'Profit distributed',
                  r.profitDistributions.amount,
                  count: r.profitDistributions.count,
                ),
              if (r.gstCollected > 0)
                AmountLine('GST collected', r.gstCollected),
              const Divider(height: Spacing.lg),
              AmountLine(
                'Payments received',
                r.paymentsIn.amount,
                count: r.paymentsIn.count,
                color: StatusColors.success,
              ),
              AmountLine(
                'Payments made',
                r.paymentsOut.amount,
                count: r.paymentsOut.count,
                color: StatusColors.danger,
              ),
              AmountLine(
                'Net cash flow',
                r.netCashFlow,
                bold: true,
                color: r.netCashFlow >= 0
                    ? StatusColors.success
                    : StatusColors.danger,
              ),
              const Divider(height: Spacing.lg),
              AmountLine(
                'Unpaid purchase bills (this period)',
                r.accountsPayable.amount,
                count: r.accountsPayable.count,
              ),
              AmountLine(
                'Total payable (all open bills)',
                r.accountsPayableTotal,
                bold: true,
              ),
            ],
          ),
        ),
        if (r.byMode.any((m) => m.inAmount != 0 || m.outAmount != 0)) ...[
          const SizedBox(height: Spacing.lg),
          SectionCard(
            title: 'By payment mode',
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(child: SizedBox()),
                    SizedBox(
                      width: 100,
                      child: Text(
                        'In',
                        textAlign: TextAlign.right,
                        style: context.text.labelSmall,
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: Text(
                        'Out',
                        textAlign: TextAlign.right,
                        style: context.text.labelSmall,
                      ),
                    ),
                  ],
                ),
                for (final m in r.byMode.where(
                  (m) => m.inAmount != 0 || m.outAmount != 0,
                ))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Expanded(child: Text(m.label.isEmpty ? '—' : m.label)),
                        SizedBox(
                          width: 100,
                          child: Text(
                            money(m.inAmount),
                            textAlign: TextAlign.right,
                            style: const TextStyle(color: StatusColors.success),
                          ),
                        ),
                        SizedBox(
                          width: 100,
                          child: Text(
                            money(m.outAmount),
                            textAlign: TextAlign.right,
                            style: const TextStyle(color: StatusColors.danger),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (r.expenseLines.isNotEmpty) ...[
          const SizedBox(height: Spacing.lg),
          SectionCard(
            title: 'Expenses',
            padding: const EdgeInsets.only(bottom: Spacing.xs),
            child: Column(
              children: [
                for (final e in r.expenseLines.take(30))
                  ListTile(
                    dense: true,
                    title: Text(
                      e.description.isEmpty ? e.category : e.description,
                    ),
                    subtitle: Text(
                      [
                        e.category,
                        e.date,
                      ].where((s) => s.isNotEmpty).join(' · '),
                    ),
                    trailing: Text(
                      money(e.amount),
                      style: context.text.labelLarge,
                    ),
                  ),
                if (r.expenseLines.length > 30)
                  Padding(
                    padding: const EdgeInsets.all(Spacing.md),
                    child: Text(
                      '${r.expenseLines.length - 30} more — share the PDF for the full list.',
                      style: context.text.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ── Profit & loss (trading account) ─────────────────────────────────────

final _plProvider = FutureProvider.autoDispose
    .family<TradingProfitLoss, ReportPeriod>((ref, p) {
      ref.watch(activeStoreIdProvider);
      ref.watch(dataRevisionProvider);
      return ref.watch(reportsRepositoryProvider).profitLoss(p);
    });

class ProfitLossReportScreen extends ConsumerStatefulWidget {
  const ProfitLossReportScreen({super.key});

  @override
  ConsumerState<ProfitLossReportScreen> createState() => _PlState();
}

class _PlState extends ConsumerState<ProfitLossReportScreen> {
  ReportPeriod _p = ReportPeriod.thisMonth();

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_plProvider(_p));
    final r = async.asData?.value;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profit & loss'),
        actions: [
          ExportMenu(
            exports: ReportExports.profitLoss,
            query: _p.toQuery(),
            baseName: 'Profit_Loss',
          ),
        ],
      ),
      body: ReportBody(
        onRefresh: () async => ref.invalidate(_plProvider(_p)),
        children: [
          PeriodBar(
            period: _p,
            serverLabel: r?.header.label,
            onChanged: (p) => setState(() => _p = p),
          ),
          const SizedBox(height: Spacing.lg),
          async.when(
            loading: reportLoading,
            error: (e, _) => ErrorView(
              error: e,
              onRetry: () => ref.invalidate(_plProvider(_p)),
            ),
            data: (r) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HeadlineCard(
                  label: r.netProfit >= 0 ? 'Net profit' : 'Net loss',
                  amount: r.netProfit,
                ),
                const SizedBox(height: Spacing.lg),
                SectionCard(
                  title: 'Trading account',
                  child: Column(
                    children: [
                      AmountLine('Opening stock', r.openingStock),
                      AmountLine(
                        'Purchases',
                        r.purchases.amount,
                        count: r.purchases.count,
                      ),
                      AmountLine(
                        'Purchase returns & debit notes',
                        r.purchaseReturns.amount,
                        negative: true,
                      ),
                      AmountLine('Sales', r.sales.amount, count: r.sales.count),
                      AmountLine(
                        'Sales returns & credit notes',
                        r.salesReturns.amount,
                        negative: true,
                      ),
                      AmountLine('Closing stock', r.closingStock),
                      const Divider(height: Spacing.lg),
                      AmountLine(
                        'Gross profit',
                        r.grossProfit,
                        bold: true,
                        color: r.grossProfit >= 0
                            ? StatusColors.success
                            : StatusColors.danger,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Spacing.lg),
                SectionCard(
                  title: 'Profit & loss account',
                  child: Column(
                    children: [
                      AmountLine('Gross profit', r.grossProfit),
                      AmountLine('Other income', r.otherIncome.amount),
                      for (final l in r.otherIncomeLines)
                        AmountLine(l.name, l.amount, indent: true),
                      AmountLine(
                        'Indirect expenses',
                        r.indirectExpenses.amount,
                        negative: true,
                      ),
                      for (final l in r.indirectExpenseLines)
                        AmountLine(l.name, l.amount, indent: true),
                      AmountLine(
                        'Expenses',
                        r.expenses.amount,
                        count: r.expenses.count,
                        negative: true,
                      ),
                      const Divider(height: Spacing.lg),
                      AmountLine(
                        r.netProfit >= 0 ? 'Net profit' : 'Net loss',
                        r.netProfit.abs(),
                        bold: true,
                        color: r.netProfit >= 0
                            ? StatusColors.success
                            : StatusColors.danger,
                      ),
                    ],
                  ),
                ),
                if (r.expenseLines.isNotEmpty) ...[
                  const SizedBox(height: Spacing.lg),
                  ExpansionTile(
                    title: Text(
                      'Expense details (${r.expenseLines.length})',
                      style: context.text.titleSmall,
                    ),
                    children: [
                      for (final e in r.expenseLines.take(50))
                        ListTile(
                          dense: true,
                          title: Text(
                            e.description.isEmpty ? e.category : e.description,
                          ),
                          subtitle: Text(e.category),
                          trailing: Text(money(e.amount)),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Daily profit ────────────────────────────────────────────────────────

final _dailyProfitProvider = FutureProvider.autoDispose
    .family<DailyProfitReport, ReportPeriod>((ref, p) {
      ref.watch(activeStoreIdProvider);
      ref.watch(dataRevisionProvider);
      return ref.watch(reportsRepositoryProvider).dailyProfit(p);
    });

class DailyProfitScreen extends ConsumerStatefulWidget {
  const DailyProfitScreen({super.key});

  @override
  ConsumerState<DailyProfitScreen> createState() => _DpState();
}

class _DpState extends ConsumerState<DailyProfitScreen> {
  ReportPeriod _p = ReportPeriod.thisMonth();

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_dailyProfitProvider(_p));
    final r = async.asData?.value;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily profit'),
        actions: [
          ExportMenu(
            exports: ReportExports.dailyProfit,
            query: _p.toQuery(),
            baseName: 'Daily_Profit',
          ),
        ],
      ),
      body: ReportBody(
        onRefresh: () async => ref.invalidate(_dailyProfitProvider(_p)),
        children: [
          PeriodBar(
            period: _p,
            serverLabel: r?.header.label,
            // A single day has nothing to break down.
            kinds: const [
              PeriodKind.weekly,
              PeriodKind.monthly,
              PeriodKind.yearly,
              PeriodKind.custom,
            ],
            onChanged: (p) => setState(() => _p = p),
          ),
          const SizedBox(height: Spacing.lg),
          async.when(
            loading: reportLoading,
            error: (e, _) => ErrorView(
              error: e,
              onRetry: () => ref.invalidate(_dailyProfitProvider(_p)),
            ),
            data: (r) {
              final t = r.totals;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  HeadlineCard(
                    label: 'Net profit',
                    amount: t.netProfit,
                    caption: '${r.totalDays} days',
                  ),
                  const SizedBox(height: Spacing.md),
                  SectionCard(
                    title: 'Totals',
                    child: Column(
                      children: [
                        AmountLine('Sales', t.sales),
                        AmountLine(
                          'Cost of goods sold',
                          t.cogs,
                          negative: true,
                        ),
                        AmountLine(
                          'Sales returns',
                          t.salesReturn,
                          negative: true,
                        ),
                        AmountLine('Gross profit', t.grossProfit, bold: true),
                        AmountLine('Expenses', t.expenses, negative: true),
                        AmountLine(
                          'Net profit',
                          t.netProfit,
                          bold: true,
                          color: t.netProfit >= 0
                              ? StatusColors.success
                              : StatusColors.danger,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Spacing.lg),
                  SectionCard(
                    title: 'By day',
                    padding: const EdgeInsets.only(bottom: Spacing.xs),
                    child: r.rows.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(Spacing.lg),
                            child: Text('No activity in this period.'),
                          )
                        : Column(
                            children: [
                              for (final d in r.rows)
                                ExpansionTile(
                                  dense: true,
                                  title: Text(dateText(d.date)),
                                  subtitle: Text(
                                    'Sales ${moneyShort(d.sales)}',
                                  ),
                                  trailing: Text(
                                    money(d.netProfit),
                                    style: context.text.labelLarge?.copyWith(
                                      color: d.netProfit >= 0
                                          ? StatusColors.success
                                          : StatusColors.danger,
                                    ),
                                  ),
                                  childrenPadding: const EdgeInsets.symmetric(
                                    horizontal: Spacing.lg,
                                  ),
                                  children: [
                                    AmountLine('Sales', d.sales),
                                    AmountLine(
                                      'Cost of goods sold',
                                      d.cogs,
                                      negative: true,
                                    ),
                                    AmountLine(
                                      'Sales returns',
                                      d.salesReturn,
                                      negative: true,
                                    ),
                                    AmountLine('Gross profit', d.grossProfit),
                                    AmountLine(
                                      'Expenses',
                                      d.expenses,
                                      negative: true,
                                    ),
                                    AmountLine(
                                      'Purchases (not in profit)',
                                      d.purchase,
                                    ),
                                    const SizedBox(height: Spacing.sm),
                                  ],
                                ),
                            ],
                          ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Bill-wise profit ────────────────────────────────────────────────────

typedef _BillwiseKey = (ReportPeriod, String, String);

final _billwiseProvider = FutureProvider.autoDispose
    .family<BillwiseProfitReport, _BillwiseKey>((ref, k) {
      ref.watch(activeStoreIdProvider);
      ref.watch(dataRevisionProvider);
      return ref
          .watch(reportsRepositoryProvider)
          .billwise(k.$1, sort: k.$2, search: k.$3);
    });

class BillwiseProfitScreen extends ConsumerStatefulWidget {
  const BillwiseProfitScreen({super.key});

  @override
  ConsumerState<BillwiseProfitScreen> createState() => _BwState();
}

class _BwState extends ConsumerState<BillwiseProfitScreen> {
  ReportPeriod _p = ReportPeriod.thisMonth();
  String _sort = 'newest';
  String _q = '';

  static const _sorts = [
    ('newest', 'Newest'),
    ('profit_desc', 'Most profit'),
    ('profit_asc', 'Least profit'),
    ('sale_desc', 'Biggest sale'),
  ];

  void _showBill(BillProfit b) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.8,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(
            Spacing.xl,
            0,
            Spacing.xl,
            Spacing.lg,
          ),
          children: [
            Text(
              '${b.invoiceNumber} · ${b.partyName}',
              style: ctx.text.titleMedium,
            ),
            Text(dateText(b.date), style: ctx.text.bodySmall),
            const SizedBox(height: Spacing.md),
            AmountLine('Sale value', b.saleAmount),
            AmountLine('Discounts', b.discount, negative: true),
            AmountLine('Returns', b.returnsAmount, negative: true),
            AmountLine('Cost', b.costAmount, negative: true),
            AmountLine(
              'Profit (${b.marginPct.toStringAsFixed(1)}%)',
              b.profit,
              bold: true,
              color: b.profit >= 0 ? StatusColors.success : StatusColors.danger,
            ),
            if (b.items.isNotEmpty) ...[
              const Divider(height: Spacing.xl),
              for (final i in b.items)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(i.description),
                  subtitle: Text(
                    '${qty(i.quantity)} × · sale ${money(i.saleAmount)} · cost ${money(i.costAmount)}',
                  ),
                  trailing: Text(
                    money(i.profit),
                    style: TextStyle(
                      color: i.profit >= 0
                          ? StatusColors.success
                          : StatusColors.danger,
                    ),
                  ),
                ),
            ],
            const SizedBox(height: Spacing.md),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                context.push('/invoices/${b.invoiceId}');
              },
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Open invoice'),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final key = (_p, _sort, _q);
    final async = ref.watch(_billwiseProvider(key));
    final r = async.asData?.value;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bill-wise profit'),
        actions: [
          ExportMenu(
            exports: ReportExports.billwise,
            query: {..._p.toQuery(), 'sort': _sort},
            baseName: 'Billwise_Profit',
          ),
        ],
      ),
      body: ReportBody(
        onRefresh: () async => ref.invalidate(_billwiseProvider(key)),
        children: [
          PeriodBar(
            period: _p,
            serverLabel: r?.header.label,
            onChanged: (p) => setState(() => _p = p),
          ),
          const SizedBox(height: Spacing.md),
          SearchField(
            hint: 'Search invoice or customer',
            onChanged: (v) => setState(() => _q = v),
          ),
          const SizedBox(height: Spacing.sm),
          Wrap(
            spacing: Spacing.sm,
            children: [
              for (final (v, l) in _sorts)
                ChoiceChip(
                  label: Text(l),
                  selected: _sort == v,
                  onSelected: (_) => setState(() => _sort = v),
                ),
            ],
          ),
          const SizedBox(height: Spacing.lg),
          async.when(
            loading: reportLoading,
            error: (e, _) => ErrorView(
              error: e,
              onRetry: () => ref.invalidate(_billwiseProvider(key)),
            ),
            data: (r) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HeadlineCard(
                  label: 'Profit',
                  amount: r.profit,
                  caption:
                      '${r.billCount} bills · ${r.marginPct.toStringAsFixed(1)}% margin',
                ),
                const SizedBox(height: Spacing.md),
                SectionCard(
                  title: 'Bills',
                  padding: const EdgeInsets.only(bottom: Spacing.xs),
                  child: r.bills.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(Spacing.lg),
                          child: Text('No bills in this period.'),
                        )
                      : Column(
                          children: [
                            for (final b in r.bills)
                              ListTile(
                                onTap: () => _showBill(b),
                                title: Text(
                                  b.partyName.isEmpty
                                      ? b.invoiceNumber
                                      : b.partyName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  '${b.invoiceNumber} · ${dateShort(b.date)} · sale ${moneyShort(b.saleAmount)}',
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      money(b.profit),
                                      style: context.text.labelLarge?.copyWith(
                                        color: b.profit >= 0
                                            ? StatusColors.success
                                            : StatusColors.danger,
                                      ),
                                    ),
                                    Text(
                                      '${b.marginPct.toStringAsFixed(1)}%',
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
    );
  }
}
