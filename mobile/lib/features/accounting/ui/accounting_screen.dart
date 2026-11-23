import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/revision.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/models/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/paged_list.dart';
import '../data/accounting_repository.dart';

const accountingAccent = Color(0xFF0D9488);

/// Start of the Indian financial year (1 April) containing [d].
DateTime fyStart(DateTime d) => DateTime(d.month >= 4 ? d.year : d.year - 1, 4, 1);

class AccountingScreen extends ConsumerStatefulWidget {
  const AccountingScreen({super.key});

  @override
  ConsumerState<AccountingScreen> createState() => _State();
}

class _State extends ConsumerState<AccountingScreen> with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounting'),
        bottom: TabBar(controller: _tabs, tabs: const [Tab(text: 'Overview'), Tab(text: 'Accounts'), Tab(text: 'Journal')]),
      ),
      body: TabBarView(controller: _tabs, children: const [_Overview(), _Accounts(), _Journal()]),
    );
  }
}

class _Overview extends ConsumerWidget {
  const _Overview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(accountingStatsProvider);
    final cols = Breakpoints.columns(context, compactCols: 2, mediumCols: 3, expandedCols: 3);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(accountingStatsProvider),
      child: ListView(
        padding: const EdgeInsets.all(Spacing.lg),
        children: [
          ContentWidth(
            maxWidth: 1000,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              stats.when(
                loading: () => const SizedBox(height: 220, child: SkeletonList(count: 3)),
                error: (e, _) => Card(child: ErrorView(error: e, onRetry: () => ref.invalidate(accountingStatsProvider))),
                data: (s) => ResponsiveGrid(columns: cols, children: [
                  StatTile(label: 'Assets', value: moneyShort(s.assets), icon: Icons.account_balance_rounded, accent: const Color(0xFF2563EB)),
                  StatTile(label: 'Liabilities', value: moneyShort(s.liabilities), icon: Icons.request_page_rounded, accent: StatusColors.danger),
                  StatTile(label: 'Equity', value: moneyShort(s.equity), icon: Icons.pie_chart_rounded, accent: const Color(0xFF7C3AED)),
                  StatTile(label: 'Income', value: moneyShort(s.income), icon: Icons.trending_up_rounded, accent: StatusColors.success),
                  StatTile(label: 'Expenses', value: moneyShort(s.expense), icon: Icons.trending_down_rounded, accent: StatusColors.warning),
                  StatTile(
                    label: 'Net profit',
                    value: moneyShort(s.netProfit),
                    icon: Icons.savings_rounded,
                    accent: s.netProfit >= 0 ? StatusColors.success : StatusColors.danger,
                  ),
                ]),
              ),
              const SizedBox(height: Spacing.lg),
              SectionCard(
                title: 'Reports',
                padding: const EdgeInsets.only(bottom: Spacing.sm),
                child: Column(children: [
                  for (final (title, sub, icon, route) in const [
                    ('Trial balance', 'Debits and credits for every account', Icons.balance_rounded, '/accounting/trial-balance'),
                    ('Profit & loss', 'Income against expenses for a period', Icons.trending_up_rounded, '/accounting/profit-loss'),
                    ('Balance sheet', 'Assets, liabilities and equity on a date', Icons.account_balance_rounded, '/accounting/balance-sheet'),
                  ])
                    ListTile(
                      onTap: () => context.push(route),
                      leading: IconBadge(icon, color: accountingAccent),
                      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: Text(sub),
                      trailing: const Icon(Icons.chevron_right_rounded),
                    ),
                ]),
              ),
              const SizedBox(height: Spacing.md),
              Text('Journal entries are created and posted from the TruERP web app.',
                  style: context.text.bodySmall, textAlign: TextAlign.center),
            ]),
          ),
        ],
      ),
    );
  }
}

class _Accounts extends ConsumerWidget {
  const _Accounts();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(chartOfAccountsProvider);
    return async.when(
      loading: () => const SkeletonList(),
      error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(chartOfAccountsProvider)),
      data: (all) {
        if (all.isEmpty) return const EmptyState(icon: Icons.menu_book_outlined, title: 'No accounts yet');
        final byType = <String, List<LedgerAccount>>{};
        for (final a in all) {
          byType.putIfAbsent(a.type, () => []).add(a);
        }
        final types = [
          ...LedgerAccount.typeOrder.where(byType.containsKey),
          ...byType.keys.where((t) => !LedgerAccount.typeOrder.contains(t)),
        ];
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(chartOfAccountsProvider),
          child: ContentWidth(
            maxWidth: 900,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.md, Spacing.lg, Spacing.xxl),
              children: [
                for (final t in types) ...[
                  SectionCard(
                    title: LedgerAccount.typeLabels[t] ?? titleCase(t),
                    trailing: Text(money(byType[t]!.fold<double>(0, (s, a) => s + a.balance)), style: context.text.labelLarge),
                    padding: const EdgeInsets.only(bottom: Spacing.xs),
                    child: Column(children: [
                      for (final a in (byType[t]!..sort((x, y) => x.code.compareTo(y.code))))
                        ListTile(
                          dense: true,
                          onTap: () => context.push('/accounting/ledger/${a.id}'),
                          leading: Text(a.code, style: context.text.labelMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                          title: Text(a.name, style: TextStyle(color: a.isActive ? null : context.colors.onSurfaceVariant)),
                          subtitle: a.subType.isEmpty ? null : Text(titleCase(a.subType)),
                          trailing: Text(money(a.balance), style: context.text.labelLarge),
                        ),
                    ]),
                  ),
                  const SizedBox(height: Spacing.md),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Journal extends ConsumerWidget {
  const _Journal();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rev = ref.watch(dataRevisionProvider);
    final store = ref.watch(activeStoreIdProvider);
    final repo = ref.read(accountingRepositoryProvider);
    return ContentWidth(
      maxWidth: 900,
      child: PagedListView<JournalEntry>(
        resetKey: (rev, store),
        fetch: (page) => repo.journal(page: page),
        empty: const EmptyState(icon: Icons.menu_book_outlined, title: 'No journal entries'),
        itemBuilder: (ctx, e, _) => ListTile(
          onTap: () => _showEntry(context, e),
          leading: const IconBadge(Icons.menu_book_rounded, color: accountingAccent),
          title: Text(e.description.isEmpty ? e.number : e.description, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${e.number} · ${relativeDay(e.date)}'),
          trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(money(e.totalDebit), style: ctx.text.labelLarge),
            StatusChip(e.status == 'posted' ? 'active' : 'draft', label: titleCase(e.status)),
          ]),
        ),
      ),
    );
  }

  void _showEntry(BuildContext context, JournalEntry e) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.8),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(Spacing.xl, 0, Spacing.xl, Spacing.lg),
              children: [
                Text(e.number, style: ctx.text.titleMedium),
                Text('${dateText(e.date)} · ${titleCase(e.status)}', style: ctx.text.bodySmall),
                if (e.description.isNotEmpty) ...[const SizedBox(height: Spacing.sm), Text(e.description)],
                const SizedBox(height: Spacing.lg),
                Row(children: [
                  Expanded(child: Text('Account', style: ctx.text.labelSmall)),
                  SizedBox(width: 90, child: Text('Debit', style: ctx.text.labelSmall, textAlign: TextAlign.right)),
                  SizedBox(width: 90, child: Text('Credit', style: ctx.text.labelSmall, textAlign: TextAlign.right)),
                ]),
                const Divider(),
                for (final l in e.lines)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: Text(l.accountName)),
                      SizedBox(width: 90, child: Text(l.debit == 0 ? '' : money(l.debit), textAlign: TextAlign.right)),
                      SizedBox(width: 90, child: Text(l.credit == 0 ? '' : money(l.credit), textAlign: TextAlign.right)),
                    ]),
                  ),
                const Divider(),
                Row(children: [
                  Expanded(child: Text('Total', style: ctx.text.titleSmall)),
                  SizedBox(width: 90, child: Text(money(e.totalDebit), style: ctx.text.titleSmall, textAlign: TextAlign.right)),
                  SizedBox(width: 90, child: Text(money(e.totalCredit), style: ctx.text.titleSmall, textAlign: TextAlign.right)),
                ]),
              ],
            ),
          ),
        ),
      );
}
