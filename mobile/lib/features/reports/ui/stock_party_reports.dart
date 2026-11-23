import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/json.dart';
import '../../../core/api/revision.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/models/reports.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/doc_widgets.dart';
import '../../../shared/widgets/form_widgets.dart';
import '../../../shared/widgets/paged_list.dart';
import '../data/report_period.dart';
import '../data/reports_repository.dart';
import 'report_widgets.dart';

// ── Stock report ────────────────────────────────────────────────────────

final _stockProvider = FutureProvider.autoDispose
    .family<StockReport, ReportPeriod>((ref, p) {
      ref.watch(activeStoreIdProvider);
      ref.watch(dataRevisionProvider);
      return ref.watch(reportsRepositoryProvider).stock(p);
    });

class StockReportScreen extends ConsumerStatefulWidget {
  const StockReportScreen({super.key});

  @override
  ConsumerState<StockReportScreen> createState() => _StockState();
}

class _StockState extends ConsumerState<StockReportScreen> {
  ReportPeriod _p = ReportPeriod.thisMonth();
  String _q = '';
  bool _movedOnly = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_stockProvider(_p));
    final r = async.asData?.value;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock report'),
        actions: [
          ExportMenu(
            exports: ReportExports.stock,
            query: _p.toQuery(),
            baseName: 'Stock_Report',
          ),
        ],
      ),
      body: ReportBody(
        onRefresh: () async => ref.invalidate(_stockProvider(_p)),
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
              onRetry: () => ref.invalidate(_stockProvider(_p)),
            ),
            data: (r) {
              final q = _q.toLowerCase();
              final lines = r.lines
                  .where(
                    (l) =>
                        q.isEmpty ||
                        l.name.toLowerCase().contains(q) ||
                        l.category.toLowerCase().contains(q),
                  )
                  .where((l) => !_movedOnly || l.inQty != 0 || l.outQty != 0)
                  .toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SummaryStrip(
                    cells: [
                      ('Opening value', r.openingValue, null),
                      ('Closing value', r.closingValue, null),
                      (
                        'Change',
                        r.change,
                        r.change >= 0
                            ? StatusColors.success
                            : StatusColors.danger,
                      ),
                    ],
                  ),
                  const SizedBox(height: Spacing.md),
                  SearchField(
                    hint: 'Search product or category',
                    onChanged: (v) => setState(() => _q = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Only items that moved'),
                    value: _movedOnly,
                    onChanged: (v) => setState(() => _movedOnly = v),
                  ),
                  SectionCard(
                    title: 'Products (${lines.length})',
                    padding: const EdgeInsets.only(bottom: Spacing.xs),
                    child: lines.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(Spacing.lg),
                            child: Text('No matching products.'),
                          )
                        : Column(
                            children: [
                              for (final l in lines.take(200))
                                ListTile(
                                  dense: true,
                                  onTap: l.productId.isEmpty
                                      ? null
                                      : () => context.push(
                                          '/products/${l.productId}',
                                        ),
                                  title: Text(
                                    l.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    'Open ${qty(l.openingQty)} · +${qty(l.inQty)} · −${qty(l.outQty)}${l.category.isEmpty ? '' : ' · ${l.category}'}',
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${qty(l.closingQty)} ${l.unit}',
                                        style: context.text.labelLarge,
                                      ),
                                      Text(
                                        moneyShort(l.closingValue),
                                        style: context.text.labelSmall,
                                      ),
                                    ],
                                  ),
                                ),
                              if (lines.length > 200)
                                Padding(
                                  padding: const EdgeInsets.all(Spacing.md),
                                  child: Text(
                                    'Showing 200 of ${lines.length}. Search to narrow, or share the Excel file.',
                                    style: context.text.bodySmall,
                                  ),
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

// ── Party balances ──────────────────────────────────────────────────────

typedef _PbKey = (DateTime, String?);

final _pbProvider = FutureProvider.autoDispose
    .family<PartyBalanceReport, _PbKey>((ref, k) {
      ref.watch(activeStoreIdProvider);
      ref.watch(dataRevisionProvider);
      return ref
          .watch(reportsRepositoryProvider)
          .partyBalances(k.$1, type: k.$2);
    });

class PartyBalanceReportScreen extends ConsumerStatefulWidget {
  const PartyBalanceReportScreen({super.key});

  @override
  ConsumerState<PartyBalanceReportScreen> createState() => _PbState();
}

class _PbState extends ConsumerState<PartyBalanceReportScreen> {
  DateTime _asOf = DateUtils.dateOnly(DateTime.now());
  String? _type;
  String _q = '';
  bool _hideSettled = true;

  @override
  Widget build(BuildContext context) {
    final key = (_asOf, _type);
    final async = ref.watch(_pbProvider(key));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Party balances'),
        actions: [
          ExportMenu(
            exports: ReportExports.partyBalance,
            query: {'date': ymd(_asOf), 'party_type': _type},
            baseName: 'Party_Balances',
          ),
        ],
      ),
      body: ReportBody(
        onRefresh: () async => ref.invalidate(_pbProvider(key)),
        children: [
          DateField(
            label: 'As of',
            value: _asOf,
            onChanged: (d) => setState(() => _asOf = d ?? _asOf),
          ),
          const SizedBox(height: Spacing.md),
          SegmentedButton<String?>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: null, label: Text('All')),
              ButtonSegment(value: 'customer', label: Text('Customers')),
              ButtonSegment(value: 'vendor', label: Text('Vendors')),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: Spacing.lg),
          async.when(
            loading: reportLoading,
            error: (e, _) => ErrorView(
              error: e,
              onRetry: () => ref.invalidate(_pbProvider(key)),
            ),
            data: (r) {
              final q = _q.toLowerCase();
              final lines = r.lines
                  .where(
                    (l) =>
                        q.isEmpty ||
                        l.name.toLowerCase().contains(q) ||
                        l.phone.contains(q),
                  )
                  .where((l) => !_hideSettled || l.closing.abs() >= 0.005)
                  .toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SummaryStrip(
                    cells: [
                      ('To collect', r.receivable, StatusColors.success),
                      ('To pay', r.payable, StatusColors.danger),
                      ('Net', r.net, null),
                    ],
                  ),
                  const SizedBox(height: Spacing.md),
                  SearchField(
                    hint: 'Search name or phone',
                    onChanged: (v) => setState(() => _q = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Hide settled parties'),
                    value: _hideSettled,
                    onChanged: (v) => setState(() => _hideSettled = v),
                  ),
                  SectionCard(
                    title: 'Parties (${lines.length})',
                    padding: const EdgeInsets.only(bottom: Spacing.xs),
                    child: lines.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(Spacing.lg),
                            child: Text('No matching parties.'),
                          )
                        : Column(
                            children: [
                              for (final l in lines.take(300))
                                ListTile(
                                  dense: true,
                                  onTap: l.partyId.isEmpty
                                      ? null
                                      : () => context.push(
                                          '/parties/${l.partyId}',
                                        ),
                                  leading: InitialsAvatar(l.name, size: 34),
                                  title: Text(
                                    l.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    'Dr ${moneyShort(l.debit)} · Cr ${moneyShort(l.credit)}',
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        money(l.closing.abs()),
                                        style: context.text.labelLarge
                                            ?.copyWith(
                                              color: l.closing > 0
                                                  ? StatusColors.success
                                                  : l.closing < 0
                                                  ? StatusColors.danger
                                                  : null,
                                            ),
                                      ),
                                      Text(
                                        l.closing > 0
                                            ? 'to collect'
                                            : l.closing < 0
                                            ? 'to pay'
                                            : 'settled',
                                        style: context.text.labelSmall,
                                      ),
                                    ],
                                  ),
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

// ── Outstanding & aging ─────────────────────────────────────────────────

final _outstandingProvider = FutureProvider.autoDispose<OutstandingReport>((
  ref,
) {
  ref.watch(activeStoreIdProvider);
  ref.watch(dataRevisionProvider);
  return ref.watch(reportsRepositoryProvider).outstanding();
});

class OutstandingScreen extends ConsumerWidget {
  const OutstandingScreen({super.key});

  static const _agingColors = [
    StatusColors.success,
    Color(0xFFCA8A04),
    StatusColors.warning,
    Color(0xFFEA580C),
    StatusColors.danger,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_outstandingProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Outstanding & aging')),
      body: async.when(
        loading: () => const SkeletonList(),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(_outstandingProvider),
        ),
        data: (r) => ReportBody(
          onRefresh: () async => ref.invalidate(_outstandingProvider),
          children: [
            HeadlineCard(
              label: 'Outstanding',
              amount: r.total,
              signed: false,
              caption:
                  '${r.invoices.length} invoices · ${r.overdueCount} overdue',
            ),
            const SizedBox(height: Spacing.lg),
            SectionCard(
              title: 'Aging',
              child: Column(
                children: [
                  for (final (i, (label, amount)) in r.aging.buckets.indexed)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(label)),
                              Text(
                                money(amount),
                                style: context.text.labelLarge,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ShareBar(
                            fraction: r.aging.total == 0
                                ? 0
                                : amount / r.aging.total,
                            color: _agingColors[i],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.lg),
            if (r.byParty.isNotEmpty)
              SectionCard(
                title: 'By customer',
                padding: const EdgeInsets.only(bottom: Spacing.xs),
                child: Column(
                  children: [
                    for (final p in r.byParty.take(20))
                      ListTile(
                        dense: true,
                        onTap: p.id.isEmpty
                            ? null
                            : () => context.push('/parties/${p.id}'),
                        leading: InitialsAvatar(p.name, size: 34),
                        title: Text(
                          p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(p.subtitle),
                        trailing: Text(
                          money(p.value),
                          style: context.text.labelLarge?.copyWith(
                            color: StatusColors.danger,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: Spacing.lg),
            if (r.invoices.isNotEmpty)
              SectionCard(
                title: 'Invoices',
                padding: const EdgeInsets.only(bottom: Spacing.xs),
                child: Column(
                  children: [
                    for (final i in r.invoices.take(50))
                      ListTile(
                        dense: true,
                        onTap: () => context.push('/invoices/${i.id}'),
                        title: Text(
                          i.partyName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text('${i.number} · ${dateShort(i.date)}'),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              money(i.outstanding),
                              style: context.text.labelLarge,
                            ),
                            if (i.daysOverdue > 0)
                              Text(
                                '${i.daysOverdue} days overdue',
                                style: context.text.labelSmall?.copyWith(
                                  color: StatusColors.danger,
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

// ── Ranked analytics (customers / products / categories) ────────────────

enum RankKind { customers, products, categories }

typedef _RankKey = (RankKind, AnalyticsPeriod);

final _rankProvider = FutureProvider.autoDispose.family<RankReport, _RankKey>((
  ref,
  k,
) {
  ref.watch(activeStoreIdProvider);
  ref.watch(dataRevisionProvider);
  final repo = ref.watch(reportsRepositoryProvider);
  return switch (k.$1) {
    RankKind.customers => repo.customers(k.$2),
    RankKind.products => repo.products(k.$2),
    RankKind.categories => repo.categories(k.$2),
  };
});

class RankReportScreen extends ConsumerStatefulWidget {
  const RankReportScreen({super.key, required this.kind});
  final RankKind kind;

  @override
  ConsumerState<RankReportScreen> createState() => _RankState();
}

class _RankState extends ConsumerState<RankReportScreen> {
  AnalyticsPeriod _period = AnalyticsPeriod.monthly;

  @override
  Widget build(BuildContext context) {
    final key = (widget.kind, _period);
    final async = ref.watch(_rankProvider(key));
    final (title, totalLabel, icon) = switch (widget.kind) {
      RankKind.customers => (
        'Top customers',
        'Paid sales',
        Icons.person_rounded,
      ),
      RankKind.products => (
        'Top products',
        'Revenue',
        Icons.inventory_2_rounded,
      ),
      RankKind.categories => ('Categories', 'Revenue', Icons.sell_rounded),
    };
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ReportBody(
        onRefresh: () async => ref.invalidate(_rankProvider(key)),
        children: [
          AnalyticsPeriodChips(
            value: _period,
            onChanged: (p) => setState(() => _period = p),
          ),
          const SizedBox(height: Spacing.lg),
          async.when(
            loading: reportLoading,
            error: (e, _) => ErrorView(
              error: e,
              onRetry: () => ref.invalidate(_rankProvider(key)),
            ),
            data: (r) {
              final top = r.rows.isEmpty
                  ? 0.0
                  : r.rows.map((x) => x.value).reduce((a, b) => a > b ? a : b);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  HeadlineCard(
                    label: totalLabel,
                    amount: r.total,
                    signed: false,
                    caption: '${r.count} ${widget.kind.name}',
                  ),
                  const SizedBox(height: Spacing.lg),
                  SectionCard(
                    padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
                    child: r.rows.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(Spacing.lg),
                            child: Text('No sales in this period.'),
                          )
                        : Column(
                            children: [
                              for (final (i, row) in r.rows.take(100).indexed)
                                InkWell(
                                  onTap:
                                      row.id.isEmpty ||
                                          widget.kind == RankKind.categories
                                      ? null
                                      : () => context.push(
                                          widget.kind == RankKind.customers
                                              ? '/parties/${row.id}'
                                              : '/products/${row.id}',
                                        ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: Spacing.lg,
                                      vertical: Spacing.sm,
                                    ),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 28,
                                          child: Text(
                                            '${i + 1}',
                                            style: context.text.labelLarge,
                                          ),
                                        ),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      row.name,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                                  Text(
                                                    money(row.value),
                                                    style:
                                                        context.text.labelLarge,
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      row.subtitle,
                                                      style: context
                                                          .text
                                                          .bodySmall,
                                                    ),
                                                  ),
                                                  if (row.share > 0)
                                                    Text(
                                                      '${row.share.toStringAsFixed(1)}%',
                                                      style: context
                                                          .text
                                                          .labelSmall,
                                                    ),
                                                  if (row.secondary > 0)
                                                    Text(
                                                      'Due ${moneyShort(row.secondary)}',
                                                      style: context
                                                          .text
                                                          .labelSmall
                                                          ?.copyWith(
                                                            color: StatusColors
                                                                .danger,
                                                          ),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              ShareBar(
                                                fraction: top == 0
                                                    ? 0
                                                    : row.value / top,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: Spacing.md),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          icon,
                          size: 14,
                          color: context.colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(_period.label, style: context.text.labelSmall),
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

class AnalyticsPeriodChips extends StatelessWidget {
  const AnalyticsPeriodChips({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final AnalyticsPeriod value;
  final ValueChanged<AnalyticsPeriod> onChanged;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final p in AnalyticsPeriod.values) ...[
          ChoiceChip(
            label: Text(p.label),
            selected: value == p,
            onSelected: (_) => onChanged(p),
          ),
          const SizedBox(width: Spacing.sm),
        ],
      ],
    ),
  );
}

// ── Payments analytics ──────────────────────────────────────────────────

final _paymentsProvider = FutureProvider.autoDispose
    .family<PaymentsAnalytics, AnalyticsPeriod>((ref, p) {
      ref.watch(activeStoreIdProvider);
      ref.watch(dataRevisionProvider);
      return ref.watch(reportsRepositoryProvider).payments(p);
    });

class PaymentsAnalyticsScreen extends ConsumerStatefulWidget {
  const PaymentsAnalyticsScreen({super.key});

  @override
  ConsumerState<PaymentsAnalyticsScreen> createState() => _PayState();
}

class _PayState extends ConsumerState<PaymentsAnalyticsScreen> {
  AnalyticsPeriod _period = AnalyticsPeriod.monthly;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_paymentsProvider(_period));
    return Scaffold(
      appBar: AppBar(title: const Text('Payments')),
      body: ReportBody(
        onRefresh: () async => ref.invalidate(_paymentsProvider(_period)),
        children: [
          AnalyticsPeriodChips(
            value: _period,
            onChanged: (p) => setState(() => _period = p),
          ),
          const SizedBox(height: Spacing.lg),
          async.when(
            loading: reportLoading,
            error: (e, _) => ErrorView(
              error: e,
              onRetry: () => ref.invalidate(_paymentsProvider(_period)),
            ),
            data: (r) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SummaryStrip(
                  cells: [
                    ('Received', r.totalIn, StatusColors.success),
                    ('Paid', r.totalOut, StatusColors.danger),
                    (
                      'Net',
                      r.net,
                      r.net >= 0 ? StatusColors.success : StatusColors.danger,
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.lg),
                SectionCard(
                  title: 'By payment mode',
                  child: r.byMode.isEmpty
                      ? const Text('No payments in this period.')
                      : Column(
                          children: [
                            for (final m in r.byMode) ...[
                              Padding(
                                padding: const EdgeInsets.only(top: Spacing.sm),
                                child: Text(
                                  modeName(m.label),
                                  style: context.text.titleSmall,
                                ),
                              ),
                              AmountLine(
                                'In',
                                m.inAmount,
                                color: StatusColors.success,
                                indent: true,
                              ),
                              AmountLine(
                                'Out',
                                m.outAmount,
                                color: StatusColors.danger,
                                indent: true,
                              ),
                            ],
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

String modeName(String code) => code.isEmpty ? 'Unspecified' : titleCase(code);
