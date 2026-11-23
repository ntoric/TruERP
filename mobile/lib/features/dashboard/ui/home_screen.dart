import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/router/modules.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/common.dart';
import '../../invoices/ui/invoices_screen.dart';
import '../../more/more_screen.dart';
import '../../payments/ui/payments_in_screen.dart';
import '../../shell/account_sheet.dart';
import '../data/dashboard_repository.dart';

/// Home tab: KPIs for the chosen period, 30-day sales trend, quick actions,
/// recent activity and top customers.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(dashboardStatsProvider);
    ref.invalidate(dailySalesProvider);
    ref.invalidate(recentInvoicesProvider);
    ref.invalidate(recentPaymentsProvider);
    ref.invalidate(topPartiesProvider);
    await ref.read(dashboardStatsProvider.future).catchError((_) => const DashboardStats());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider).asData?.value;
    final user = session?.user;
    final store = session?.activeStore;
    final canSwitch = session?.canSwitchStores ?? false;
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.expanded;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: Spacing.lg,
        title: InkWell(
          borderRadius: BorderRadius.circular(Radii.control),
          onTap: canSwitch ? () => showAccountSheet(context) : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${_greeting()}, ${user?.name.split(' ').first ?? ''}', style: context.text.titleMedium),
              if (store != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.storefront_rounded, size: 14, color: context.colors.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Flexible(child: Text(store.name, style: context.text.bodySmall, overflow: TextOverflow.ellipsis)),
                    if (canSwitch) Icon(Icons.expand_more_rounded, size: 16, color: context.colors.onSurfaceVariant),
                  ],
                ),
            ],
          ),
        ),
        actions: const [AccountButton()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'home-new-invoice',
        onPressed: () => context.push('/invoices/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New invoice'),
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.sm, Spacing.lg, 96),
          children: [
            ContentWidth(
              maxWidth: 1200,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _PeriodBar(),
                  const SizedBox(height: Spacing.md),
                  const _Kpis(),
                  const SizedBox(height: Spacing.lg),
                  if (wide)
                    const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: _SalesChart()),
                        SizedBox(width: Spacing.lg),
                        Expanded(flex: 2, child: _QuickActions()),
                      ],
                    )
                  else ...[
                    const _QuickActions(),
                    const SizedBox(height: Spacing.lg),
                    const _SalesChart(),
                  ],
                  const SizedBox(height: Spacing.lg),
                  if (MediaQuery.sizeOf(context).width >= Breakpoints.compact)
                    const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _RecentInvoices()),
                        SizedBox(width: Spacing.lg),
                        Expanded(child: _RecentPayments()),
                      ],
                    )
                  else ...[
                    const _RecentInvoices(),
                    const SizedBox(height: Spacing.lg),
                    const _RecentPayments(),
                  ],
                  const SizedBox(height: Spacing.lg),
                  const _TopCustomers(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodBar extends ConsumerWidget {
  const _PeriodBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(dashPeriodProvider);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final p in DashPeriod.values) ...[
            ChoiceChip(
              label: Text(p.label),
              selected: p == period,
              onSelected: (_) => ref.read(dashPeriodProvider.notifier).set(p),
            ),
            const SizedBox(width: Spacing.sm),
          ],
        ],
      ),
    );
  }
}

class _Kpis extends ConsumerWidget {
  const _Kpis();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dashboardStatsProvider);
    final cols = Breakpoints.columns(context, compactCols: 2, mediumCols: 4, expandedCols: 4);
    return async.when(
      loading: () => _grid(context, cols, List.generate(4, (_) => const _TilePlaceholder())),
      error: (e, _) => Card(child: ErrorView(error: e, onRetry: () => ref.invalidate(dashboardStatsProvider))),
      data: (s) {
        final pendingCaption = s.overdueInvoices > 0 ? '${s.overdueInvoices} overdue' : null;
        return _grid(context, cols, [
          StatTile(
            label: 'Sales',
            value: moneyShort(s.totalSales),
            icon: Icons.trending_up_rounded,
            accent: salesAccent,
            caption: '${number(s.totalInvoices)} invoices',
            onTap: () => context.push('/invoices'),
          ),
          StatTile(
            label: 'Received',
            value: moneyShort(s.totalSalesPaid),
            icon: Icons.call_received_rounded,
            accent: StatusColors.success,
            onTap: () => context.push('/payments-in'),
          ),
          StatTile(
            label: 'To collect',
            value: moneyShort(s.pendingAmount),
            icon: Icons.hourglass_bottom_rounded,
            accent: StatusColors.danger,
            caption: pendingCaption,
            onTap: () => context.push('/parties?balance=to_collect'),
          ),
          StatTile(
            label: 'Today',
            value: moneyShort(s.todaySales),
            icon: Icons.today_rounded,
            accent: paymentsAccent,
            caption: '${number(s.todayInvoices)} invoices',
          ),
          StatTile(
            label: 'Customers',
            value: number(s.totalCustomers),
            icon: Icons.groups_rounded,
            accent: const Color(0xFF7C3AED),
            onTap: () => context.push('/parties?type=customer'),
          ),
          StatTile(
            label: 'Low stock items',
            value: number(s.lowStockProducts),
            icon: Icons.warning_amber_rounded,
            accent: s.lowStockProducts > 0 ? StatusColors.warning : StatusColors.neutral,
            caption: '${number(s.totalProducts)} products',
            onTap: () => context.push('/products'),
          ),
        ]);
      },
    );
  }

  Widget _grid(BuildContext context, int cols, List<Widget> children) =>
      ResponsiveGrid(columns: cols, children: children);
}

class _TilePlaceholder extends StatelessWidget {
  const _TilePlaceholder();

  @override
  Widget build(BuildContext context) => Card(
        child: SizedBox(
          height: 110,
          child: Center(
            child: SizedBox.square(
            dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.outline),
            ),
          ),
        ),
      );
}

class _SalesChart extends ConsumerWidget {
  const _SalesChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dailySalesProvider);
    return SectionCard(
      title: 'Paid sales · last 30 days',
      child: SizedBox(
        height: 200,
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          error: (e, _) => Center(child: Text(errorMessage(e), style: context.text.bodySmall)),
          data: (points) {
            final total = points.fold<double>(0, (s, p) => s + p.sales);
            if (total == 0) {
              return Center(child: Text('No paid sales in the last 30 days.', style: context.text.bodySmall));
            }
            final maxY = points.map((p) => p.sales).reduce((a, b) => a > b ? a : b) * 1.15;
            final color = context.colors.primary;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(money(total), style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: Spacing.sm),
                Expanded(
                  child: BarChart(
                    BarChartData(
                      maxY: maxY,
                      alignment: BarChartAlignment.spaceBetween,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: maxY / 3,
                        getDrawingHorizontalLine: (_) =>
                            FlLine(color: context.colors.outlineVariant, strokeWidth: 1, dashArray: [4, 4]),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(),
                        rightTitles: const AxisTitles(),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 44,
                            interval: maxY / 3,
                            getTitlesWidget: (v, _) => Text(moneyCompact(v), style: context.text.labelSmall),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 22,
                            getTitlesWidget: (v, _) {
                              final i = v.toInt();
                              if (i % 7 != 0 && i != points.length - 1) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(dateShort(points[i].date), style: context.text.labelSmall),
                              );
                            },
                          ),
                        ),
                      ),
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => context.colors.inverseSurface,
                          getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                            '${dateShort(points[group.x].date)}\n${money(rod.toY)}',
                            TextStyle(color: context.colors.onInverseSurface, fontSize: 12),
                          ),
                        ),
                      ),
                      barGroups: [
                        for (final (i, p) in points.indexed)
                          BarChartGroupData(x: i, barRods: [
                            BarChartRodData(
                              toY: p.sales,
                              width: 6,
                              color: i == points.length - 1 ? color : color.withValues(alpha: 0.55),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                            ),
                          ]),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final actions = <(String, IconData, Color, String)>[
      ('New invoice', Icons.receipt_long_rounded, salesAccent, '/invoices/new'),
      ('Receive', Icons.call_received_rounded, paymentsAccent, '/payments-in/new'),
      ('Add party', Icons.person_add_alt_rounded, const Color(0xFF7C3AED), '/parties/new'),
      ('Add product', Icons.add_box_rounded, const Color(0xFF0891B2), '/products/new'),
    ];
    final modules = ['purchase-bills', 'expenses', 'pos', 'reports']
        .map(moduleById)
        .whereType<AppModule>()
        .toList();

    Widget tile(String label, IconData icon, Color color, VoidCallback onTap) => InkWell(
          borderRadius: BorderRadius.circular(Radii.control),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconBadge(icon, color: color, size: 46),
                const SizedBox(height: 6),
                Text(label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelSmall?.copyWith(color: context.colors.onSurface)),
              ],
            ),
          ),
        );

    return SectionCard(
      title: 'Quick actions',
      child: ResponsiveGrid(
        columns: 4,
        spacing: Spacing.xs,
        children: [
          for (final (label, icon, color, route) in actions) tile(label, icon, color, () => context.push(route)),
          for (final m in modules) tile(m.name, m.icon, groupOf(m.id)!.accent, () => openModule(context, m)),
        ],
      ),
    );
  }
}

class _RecentInvoices extends ConsumerWidget {
  const _RecentInvoices();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(recentInvoicesProvider);
    return SectionCard(
      title: 'Recent invoices',
      trailing: TextButton(onPressed: () => context.push('/invoices'), child: const Text('See all')),
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: async.when(
        loading: () => const Padding(padding: EdgeInsets.all(Spacing.lg), child: LinearProgressIndicator()),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(recentInvoicesProvider)),
        data: (list) => list.isEmpty
            ? const Padding(padding: EdgeInsets.all(Spacing.lg), child: Text('No invoices yet.'))
            : Column(children: [
                for (final inv in list) InvoiceTile(invoice: inv, onTap: () => context.push('/invoices/${inv.id}')),
              ]),
      ),
    );
  }
}

class _RecentPayments extends ConsumerWidget {
  const _RecentPayments();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(recentPaymentsProvider);
    return SectionCard(
      title: 'Recent payments',
      trailing: TextButton(onPressed: () => context.push('/payments-in'), child: const Text('See all')),
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: async.when(
        loading: () => const Padding(padding: EdgeInsets.all(Spacing.lg), child: LinearProgressIndicator()),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(recentPaymentsProvider)),
        data: (list) => list.isEmpty
            ? const Padding(padding: EdgeInsets.all(Spacing.lg), child: Text('No payments yet.'))
            : Column(children: [
                for (final p in list) PaymentInTile(payment: p, onTap: () => showPaymentInSheet(context, p)),
              ]),
      ),
    );
  }
}

class _TopCustomers extends ConsumerWidget {
  const _TopCustomers();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(topPartiesProvider);
    return async.maybeWhen(
      data: (list) => list.isEmpty
          ? const SizedBox.shrink()
          : SectionCard(
              title: 'Top customers',
              padding: const EdgeInsets.only(bottom: Spacing.sm),
              child: Column(children: [
                for (final (i, t) in list.take(5).indexed)
                  ListTile(
                    onTap: t.id.isEmpty ? null : () => context.push('/parties/${t.id}'),
                    leading: InitialsAvatar(t.name),
                    title: Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${t.invoiceCount} invoices'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(money(t.totalSales), style: context.text.labelLarge),
                        if (i == 0) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.emoji_events_rounded, color: Color(0xFFCA8A04), size: 18),
                        ],
                      ],
                    ),
                  ),
              ]),
            ),
      orElse: () => const SizedBox.shrink(),
    );
  }
}
