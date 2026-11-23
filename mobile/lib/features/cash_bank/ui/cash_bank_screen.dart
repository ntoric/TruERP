import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/revision.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/models/money.dart';
import '../../../core/models/payment.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/doc_widgets.dart';
import '../../../shared/widgets/paged_list.dart';
import '../data/cash_bank_repository.dart';
import 'money_move_sheet.dart';

const cashBankAccent = Color(0xFF16A34A);

final _recentProvider = FutureProvider.autoDispose<List<CashTransaction>>((
  ref,
) async {
  ref.watch(activeStoreIdProvider);
  ref.watch(dataRevisionProvider);
  return (await ref.watch(cashBankRepositoryProvider).transactions(page: 1))
      .items
      .take(8)
      .toList();
});

String txnSubtitle(CashTransaction t, {bool showWhere = true}) => [
  relativeDay(t.date),
  if (showWhere) t.where,
  if (t.reference.isNotEmpty) t.reference,
].join(' · ');

String txnTitle(CashTransaction t) =>
    t.description.isNotEmpty ? t.description : t.typeLabel;

/// Overview: total, cash in hand, bank accounts, quick actions, recent activity.
class CashBankScreen extends ConsumerWidget {
  const CashBankScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(cashBankSummaryProvider);
    final s = async.asData?.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cash & Bank'),
        actions: [
          IconButton(
            tooltip: 'All transactions',
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => context.push('/cash-bank/transactions'),
          ),
          IconButton(
            tooltip: 'Payment routing',
            icon: const Icon(Icons.alt_route_rounded),
            onPressed: () => context.push('/cash-bank/routing'),
          ),
        ],
      ),
      floatingActionButton: s == null
          ? null
          : FloatingActionButton.extended(
              heroTag: 'money-move',
              onPressed: () => showMoneyMoveSheet(
                context,
                kind: MoneyMove.add,
                accounts: s.accounts,
              ),
              icon: const Icon(Icons.swap_vert_rounded),
              label: const Text('Add / reduce'),
            ),
      body: async.when(
        loading: () => const SkeletonList(count: 6),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(cashBankSummaryProvider),
        ),
        data: (s) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(cashBankSummaryProvider);
            ref.invalidate(_recentProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              Spacing.lg,
              Spacing.sm,
              Spacing.lg,
              96,
            ),
            children: [ContentWidth(maxWidth: 900, child: _Body(summary: s))],
          ),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.summary});
  final CashBankSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = summary;
    final recent = ref.watch(_recentProvider);
    final active = s.accounts.where((a) => a.isActive).toList();
    final inactive = s.accounts.where((a) => !a.isActive).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: context.colors.primaryContainer.withValues(alpha: 0.35),
          child: Padding(
            padding: const EdgeInsets.all(Spacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Total balance', style: context.text.bodyMedium),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    money(s.totalBalance),
                    style: context.text.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.md),
                ResponsiveGrid(
                  columns: 2,
                  children: [
                    _Mini('Cash in hand', s.cashInHand, Icons.payments_rounded),
                    _Mini(
                      'In banks',
                      s.bankTotal,
                      Icons.account_balance_rounded,
                    ),
                  ],
                ),
                if (s.initialInvestment != 0) ...[
                  const SizedBox(height: Spacing.sm),
                  Text(
                    'Initial investment (owner\'s equity): ${money(s.initialInvestment)}',
                    style: context.text.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: Spacing.md),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () => showMoneyMoveSheet(
                  context,
                  kind: MoneyMove.add,
                  accounts: s.accounts,
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add'),
              ),
            ),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () => showMoneyMoveSheet(
                  context,
                  kind: MoneyMove.reduce,
                  accounts: s.accounts,
                ),
                icon: const Icon(Icons.remove_rounded),
                label: const Text('Reduce'),
              ),
            ),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: active.length < 2
                    ? null
                    : () => showMoneyMoveSheet(
                        context,
                        kind: MoneyMove.transfer,
                        accounts: s.accounts,
                      ),
                icon: const Icon(Icons.swap_horiz_rounded),
                label: const Text('Transfer'),
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.lg),
        SectionCard(
          title: 'Accounts',
          trailing: TextButton.icon(
            onPressed: () => context.push('/cash-bank/accounts/new'),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Bank account'),
          ),
          padding: const EdgeInsets.only(bottom: Spacing.sm),
          child: Column(
            children: [
              ListTile(
                onTap: () => context.push('/cash-bank/account/cash'),
                leading: const IconBadge(
                  Icons.payments_rounded,
                  color: cashBankAccent,
                ),
                title: const Text(
                  'Cash in hand',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                trailing: _Amount(s.cashInHand),
              ),
              for (final a in active) _AccountTile(account: a),
              if (active.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(Spacing.lg),
                  child: Text(
                    'Add your bank accounts to track UPI, card and bank payments separately.',
                    style: context.text.bodySmall,
                  ),
                ),
              if (inactive.isNotEmpty)
                ExpansionTile(
                  title: Text(
                    'Inactive (${inactive.length})',
                    style: context.text.bodyMedium,
                  ),
                  children: [
                    for (final a in inactive) _AccountTile(account: a),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.lg),
        SectionCard(
          title: 'Recent transactions',
          trailing: TextButton(
            onPressed: () => context.push('/cash-bank/transactions'),
            child: const Text('See all'),
          ),
          padding: const EdgeInsets.only(bottom: Spacing.sm),
          child: recent.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(Spacing.lg),
              child: LinearProgressIndicator(),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(Spacing.lg),
              child: Text(errorMessage(e)),
            ),
            data: (list) => list.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(Spacing.lg),
                    child: Text('No transactions yet.'),
                  )
                : Column(
                    children: [
                      for (final t in list)
                        CashTxnTile(
                          inflow: t.isInflow,
                          amount: t.amount,
                          title: txnTitle(t),
                          subtitle: txnSubtitle(t),
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini(this.label, this.amount, this.icon);
  final String label;
  final double amount;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconBadge(icon, color: cashBankAccent, size: 32),
      const SizedBox(width: Spacing.sm),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: context.text.labelSmall),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                moneyShort(amount),
                style: context.text.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _Amount extends StatelessWidget {
  const _Amount(this.amount);
  final double amount;

  @override
  Widget build(BuildContext context) => Text(
    money(amount),
    style: context.text.labelLarge?.copyWith(
      color: amount < 0 ? StatusColors.danger : null,
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
  );
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({required this.account});
  final BankAccount account;

  @override
  Widget build(BuildContext context) {
    final a = account;
    return ListTile(
      onTap: () => context.push('/cash-bank/account/${a.id}'),
      leading: IconBadge(
        Icons.account_balance_rounded,
        color: a.isActive ? const Color(0xFF2563EB) : StatusColors.neutral,
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              a.accountName.isEmpty ? a.bankName : a.accountName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          if (a.isPrimary) ...[
            const SizedBox(width: 6),
            const Icon(Icons.star_rounded, size: 16, color: Color(0xFFCA8A04)),
          ],
        ],
      ),
      subtitle: Text(
        [a.bankName, a.maskedNumber].where((e) => e.isNotEmpty).join(' · '),
        maxLines: 1,
      ),
      trailing: _Amount(a.balance),
    );
  }
}

/// Transactions, optionally for one account (`cash` or a bank id).
class CashTransactionsScreen extends ConsumerStatefulWidget {
  const CashTransactionsScreen({super.key, this.accountId});
  final String? accountId;

  @override
  ConsumerState<CashTransactionsScreen> createState() => _TxnState();
}

class _TxnState extends ConsumerState<CashTransactionsScreen> {
  String _q = '';
  String? _type;
  DateTimeRange? _range;

  @override
  Widget build(BuildContext context) {
    final rev = ref.watch(dataRevisionProvider);
    final store = ref.watch(activeStoreIdProvider);
    final repo = ref.read(cashBankRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      body: ContentWidth(
        maxWidth: 900,
        child: _TxnList(
          accountId: widget.accountId,
          resetKey: (_q, _type, _range, rev, store),
          fetch: (page) => repo.transactions(
            page: page,
            accountId: widget.accountId,
            type: _type,
            search: _q,
            from: _range?.start,
            to: _range?.end,
          ),
          header: ListFilters(
            searchHint: 'Search description or reference',
            onSearch: (v) => setState(() => _q = v),
            range: _range,
            onRange: (r) => setState(() => _range = r),
            chips: [
              ChoiceChip(
                label: const Text('All'),
                selected: _type == null,
                onSelected: (_) => setState(() => _type = null),
              ),
              for (final e in CashTransaction.typeLabels.entries.take(7))
                ChoiceChip(
                  label: Text(e.value),
                  selected: _type == e.key,
                  onSelected: (_) =>
                      setState(() => _type = _type == e.key ? null : e.key),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Paged transaction list; super admins can long-press manual entries to delete.
class _TxnList extends ConsumerWidget {
  const _TxnList({
    required this.fetch,
    required this.resetKey,
    required this.header,
    this.accountId,
  });
  final PageFetcher<CashTransaction> fetch;
  final Object resetKey;
  final Widget header;
  final String? accountId;

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    CashTransaction t,
  ) async {
    final ok = await confirmSheet(
      context,
      title: 'Delete this ${t.typeLabel.toLowerCase()}?',
      message:
          '${money(t.amount)} · ${dateText(t.date)}. The account balance will be reversed.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(cashBankRepositoryProvider).deleteTransaction(t.id);
      ref.read(dataRevisionProvider.notifier).bump();
    } catch (e) {
      if (context.mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final superAdmin = ref.watch(currentUserProvider)?.isSuperAdmin ?? false;
    return PagedListView<CashTransaction>(
      resetKey: resetKey,
      fetch: fetch,
      header: header,
      empty: const EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No transactions',
      ),
      itemBuilder: (ctx, t, _) => CashTxnTile(
        inflow: t.isInflow,
        amount: t.amount,
        title: txnTitle(t),
        subtitle: txnSubtitle(t, showWhere: accountId == null),
        // Only hand-entered movements; linked ones belong to their document.
        onLongPress:
            superAdmin &&
                !t.isLinked &&
                const {'add', 'reduce'}.contains(t.type)
            ? () => _delete(context, ref, t)
            : null,
      ),
    );
  }
}

/// One account: balance, actions and its transactions.
class CashAccountScreen extends ConsumerWidget {
  const CashAccountScreen({super.key, required this.accountId});

  /// `cash` or a bank account id.
  final String accountId;

  Future<void> _setPrimary(
    BuildContext context,
    WidgetRef ref,
    BankAccount a,
  ) async {
    try {
      await ref.read(cashBankRepositoryProvider).setPrimary(a.id);
      ref.read(dataRevisionProvider.notifier).bump();
      if (context.mounted) {
        showSnack(context, '${a.accountName} is now the primary account');
      }
    } catch (e) {
      if (context.mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    BankAccount a,
  ) async {
    final ok = await confirmSheet(
      context,
      title: 'Delete ${a.accountName}?',
      message:
          'Past transactions stay in your records. Consider marking it inactive instead.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(cashBankRepositoryProvider).deleteAccount(a.id);
      ref.read(dataRevisionProvider.notifier).bump();
      if (context.mounted) context.pop();
    } catch (e) {
      if (context.mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rev = ref.watch(dataRevisionProvider);
    final store = ref.watch(activeStoreIdProvider);
    final summary = ref.watch(cashBankSummaryProvider).asData?.value;
    final isCash = accountId == 'cash';
    final account = isCash
        ? null
        : summary?.accounts.where((a) => a.id == accountId).firstOrNull;
    final balance = isCash ? summary?.cashInHand : account?.balance;
    final repo = ref.read(cashBankRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isCash ? 'Cash in hand' : (account?.accountName ?? 'Bank account'),
        ),
        actions: [
          if (account != null)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') {
                  context.push('/cash-bank/accounts/${account.id}/edit');
                }
                if (v == 'primary') _setPrimary(context, ref, account);
                if (v == 'delete') _delete(context, ref, account);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Edit'),
                  ),
                ),
                if (!account.isPrimary && account.isActive)
                  const PopupMenuItem(
                    value: 'primary',
                    child: ListTile(
                      leading: Icon(Icons.star_outline_rounded),
                      title: Text('Make primary'),
                    ),
                  ),
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(
                      Icons.delete_outline,
                      color: StatusColors.danger,
                    ),
                    title: Text('Delete'),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: ContentWidth(
        maxWidth: 900,
        child: _TxnList(
          accountId: accountId,
          resetKey: (rev, store),
          fetch: (page) => repo.transactions(page: page, accountId: accountId),
          header: Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.lg,
              Spacing.sm,
              Spacing.lg,
              Spacing.sm,
            ),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(Spacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (account != null) ...[
                      Text(
                        [
                          account.bankName,
                          account.maskedNumber,
                          if (account.ifscCode.isNotEmpty) account.ifscCode,
                        ].where((e) => e.isNotEmpty).join(' · '),
                        style: context.text.bodySmall,
                      ),
                      const SizedBox(height: Spacing.xs),
                    ],
                    Text('Balance', style: context.text.bodyMedium),
                    Text(
                      balance == null ? '—' : money(balance),
                      style: context.text.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: Spacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: summary == null
                                ? null
                                : () => showMoneyMoveSheet(
                                    context,
                                    kind: MoneyMove.add,
                                    accounts: summary.accounts,
                                    accountId: accountId,
                                  ),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Add'),
                          ),
                        ),
                        const SizedBox(width: Spacing.sm),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: summary == null
                                ? null
                                : () => showMoneyMoveSheet(
                                    context,
                                    kind: MoneyMove.reduce,
                                    accounts: summary.accounts,
                                    accountId: accountId,
                                  ),
                            icon: const Icon(Icons.remove_rounded),
                            label: const Text('Reduce'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
