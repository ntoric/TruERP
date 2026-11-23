import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/models/expense.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/common.dart';
import '../data/expenses_repository.dart';
import 'expenses_screen.dart';

class ExpenseCategoriesScreen extends ConsumerWidget {
  const ExpenseCategoriesScreen({super.key});

  Future<void> _edit(BuildContext context, WidgetRef ref, [ExpenseCategory? c]) async {
    final ctrl = TextEditingController(text: c?.name);
    var active = c?.isActive ?? true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(c == null ? 'New category' : 'Edit category'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            if (c != null)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                value: active,
                onChanged: (v) => setLocal(() => active = v),
              ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    final name = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true || name.isEmpty) return;
    try {
      final repo = ref.read(expensesRepositoryProvider);
      if (c == null) {
        await repo.createCategory(name);
      } else {
        await repo.updateCategory(c, name: name, isActive: active);
      }
      ref.invalidate(expenseCategoriesProvider);
    } catch (e) {
      if (context.mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, ExpenseCategory c) async {
    final ok = await confirmSheet(context,
        title: 'Delete "${c.name}"?',
        message: 'Existing expenses keep their category name.',
        confirmLabel: 'Delete',
        destructive: true);
    if (!ok) return;
    try {
      await ref.read(expensesRepositoryProvider).deleteCategory(c.id);
      ref.invalidate(expenseCategoriesProvider);
    } catch (e) {
      if (context.mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(expenseCategoriesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Expense categories')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new-expense-category',
        onPressed: () => _edit(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add category'),
      ),
      body: async.when(
        loading: () => const SkeletonList(),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(expenseCategoriesProvider)),
        data: (list) => list.isEmpty
            ? const EmptyState(icon: Icons.category_outlined, title: 'No categories yet', message: 'Add categories like Rent, Salary or Electricity.')
            : ContentWidth(
                child: ListView.separated(
                  padding: const EdgeInsets.only(top: Spacing.sm, bottom: 96),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(indent: 72),
                  itemBuilder: (ctx, i) {
                    final c = list[i];
                    return ListTile(
                      leading: IconBadge(Icons.label_rounded, color: c.isActive ? expensesAccent : StatusColors.neutral),
                      title: Text(c.name),
                      subtitle: c.isActive ? null : const Text('Inactive'),
                      onTap: () => _edit(context, ref, c),
                      trailing: IconButton(
                        tooltip: 'Delete',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _delete(context, ref, c),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}
