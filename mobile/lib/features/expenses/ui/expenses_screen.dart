import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/revision.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/models/expense.dart';
import '../../../core/models/payment.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/doc_widgets.dart';
import '../../../shared/widgets/master_detail.dart';
import '../../../shared/widgets/paged_list.dart';
import '../data/expenses_repository.dart';
import 'expense_detail_screen.dart';

const expensesAccent = Color(0xFFE11D48);

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  String _q = '';
  String? _category;
  DateTimeRange? _range;
  String? _selected;

  void _open(Expense e) {
    if (MasterDetail.isSplit(context)) {
      setState(() => _selected = e.id);
    } else {
      context.push('/expenses/${e.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final rev = ref.watch(dataRevisionProvider);
    final store = ref.watch(activeStoreIdProvider);
    final categories =
        ref.watch(expenseCategoriesProvider).asData?.value ??
        const <ExpenseCategory>[];
    final repo = ref.read(expensesRepositoryProvider);
    final filtered = _q.isNotEmpty || _category != null || _range != null;

    final list = PagedListView<Expense>(
      resetKey: (_q, _category, _range, rev, store),
      fetch: (page) => repo.list(
        page: page,
        search: _q,
        category: _category,
        from: _range?.start,
        to: _range?.end,
      ),
      header: ListFilters(
        searchHint: 'Search expenses',
        onSearch: (v) => setState(() => _q = v),
        range: _range,
        onRange: (r) => setState(() => _range = r),
        chips: [
          ChoiceChip(
            label: const Text('All'),
            selected: _category == null,
            onSelected: (_) => setState(() => _category = null),
          ),
          for (final c in categories.where((c) => c.isActive))
            ChoiceChip(
              label: Text(c.name),
              selected: _category == c.name,
              onSelected: (_) => setState(
                () => _category = _category == c.name ? null : c.name,
              ),
            ),
        ],
      ),
      empty: EmptyState(
        icon: Icons.receipt_rounded,
        title: filtered ? 'No matching expenses' : 'No expenses yet',
        message: filtered
            ? null
            : 'Track rent, salaries, utilities and other business spending.',
        action: filtered
            ? null
            : FilledButton.icon(
                onPressed: () => context.push('/expenses/new'),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add expense'),
              ),
      ),
      itemBuilder: (ctx, e, _) => MoneyTile(
        icon: Icons.receipt_rounded,
        accent: expensesAccent,
        title: e.title,
        subtitle: [
          if (e.category.isNotEmpty) e.category,
          relativeDay(e.date),
          if (e.paymentMode.isNotEmpty) PaymentMode.labelOf(e.paymentMode),
        ].join(' · '),
        amount: e.amount,
        struck: e.isCancelled,
        status: e.isCancelled ? 'cancelled' : null,
        selected: e.id == _selected,
        onTap: () => _open(e),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          IconButton(
            tooltip: 'Categories',
            icon: const Icon(Icons.category_outlined),
            onPressed: () => context.push('/expenses/categories'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new-expense',
        onPressed: () => context.push('/expenses/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add expense'),
      ),
      body: MasterDetail(
        list: list,
        detail: _selected == null
            ? null
            : ExpenseDetailScreen(
                key: ValueKey(_selected),
                expenseId: _selected!,
                embedded: true,
              ),
      ),
    );
  }
}
