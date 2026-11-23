import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/revision.dart';
import '../../../core/models/inventory.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/common.dart';
import '../../products/data/products_repository.dart';
import '../data/inventory_repository.dart';
import 'inventory_screen.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  Future<void> _edit(BuildContext context, WidgetRef ref, [ProductCategory? c]) async {
    final name = TextEditingController(text: c?.name);
    final desc = TextEditingController(text: c?.description);
    var active = c?.isActive ?? true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(c == null ? 'New category' : 'Edit category'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: Spacing.md),
            TextField(controller: desc, decoration: const InputDecoration(labelText: 'Description')),
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
    final n = name.text.trim();
    final d = desc.text.trim();
    name.dispose();
    desc.dispose();
    if (ok != true || n.isEmpty) return;
    try {
      final repo = ref.read(inventoryRepositoryProvider);
      c == null ? await repo.createCategory(n, description: d) : await repo.updateCategory(c, name: n, description: d, isActive: active);
      ref.read(dataRevisionProvider.notifier).bump();
      ref.invalidate(productCategoriesProvider);
    } catch (e) {
      if (context.mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, ProductCategory c) async {
    final ok = await confirmSheet(context,
        title: 'Delete "${c.name}"?', message: 'Products keep this category name until you change them.', confirmLabel: 'Delete', destructive: true);
    if (!ok) return;
    try {
      await ref.read(inventoryRepositoryProvider).deleteCategory(c.id);
      ref.read(dataRevisionProvider.notifier).bump();
      ref.invalidate(productCategoriesProvider);
    } catch (e) {
      if (context.mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(productCategoryListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Product categories')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new-category',
        onPressed: () => _edit(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add category'),
      ),
      body: async.when(
        loading: () => const SkeletonList(),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(productCategoryListProvider)),
        data: (list) => list.isEmpty
            ? const EmptyState(icon: Icons.sell_outlined, title: 'No categories yet', message: 'Group products like Grocery, Beverages or Spares.')
            : ContentWidth(
                child: ListView.separated(
                  padding: const EdgeInsets.only(top: Spacing.sm, bottom: 96),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(indent: 72),
                  itemBuilder: (ctx, i) {
                    final c = list[i];
                    return ListTile(
                      onTap: () => _edit(context, ref, c),
                      leading: IconBadge(Icons.sell_rounded, color: c.isActive ? inventoryAccent : StatusColors.neutral),
                      title: Text(c.name),
                      subtitle: Text([if (!c.isActive) 'Inactive', if (c.description.isNotEmpty) c.description].join(' · ')),
                      trailing: IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline), onPressed: () => _delete(context, ref, c)),
                    );
                  },
                ),
              ),
      ),
    );
  }
}
