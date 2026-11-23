import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/revision.dart';
import '../../../core/models/product.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/common.dart';
import '../../inventory/ui/inventory_screen.dart';
import '../data/products_repository.dart';
import 'products_screen.dart';

class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({super.key, required this.productId, this.embedded = false, this.onDeleted});
  final String productId;
  final bool embedded;
  final VoidCallback? onDeleted;

  Future<void> _delete(BuildContext context, WidgetRef ref, Product p) async {
    final ok = await confirmSheet(context,
        title: 'Delete ${p.name}?',
        message: 'Past invoices keep their line items. This can\'t be undone.',
        confirmLabel: 'Delete',
        destructive: true);
    if (!ok) return;
    try {
      await ref.read(productsRepositoryProvider).delete(p.id);
      ref.read(dataRevisionProvider.notifier).bump();
      if (!context.mounted) return;
      showSnack(context, '${p.name} deleted');
      embedded ? onDeleted?.call() : context.pop();
    } catch (e) {
      if (context.mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(dataRevisionProvider);
    final async = ref.watch(productDetailProvider(productId));
    final product = async.asData?.value;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !embedded,
        title: Text(product?.name ?? 'Product'),
        actions: [
          if (product != null) ...[
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push('/products/${product.id}/edit'),
            ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(context, ref, product),
            ),
          ],
        ],
      ),
      body: async.when(
        loading: () => const SkeletonList(count: 6),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(productDetailProvider(productId))),
        data: (p) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(productDetailProvider(productId)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.sm, Spacing.lg, Spacing.xxl),
            children: [ContentWidth(child: _Body(product: p))],
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final p = product;
    final stockColor = p.isOutOfStock ? StatusColors.danger : p.isLowStock ? StatusColors.warning : StatusColors.success;
    final margin = p.salePrice - p.purchasePrice;
    final cols = Breakpoints.columns(context, compactCols: 2, mediumCols: 4, expandedCols: 4);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Spacing.lg),
            child: Row(
              children: [
                IconBadge(p.isService ? Icons.handyman_rounded : Icons.inventory_2_rounded, color: productsAccent, size: 56),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name, style: context.text.titleMedium),
                      const SizedBox(height: 4),
                      Wrap(spacing: 6, runSpacing: 4, children: [
                        if (p.category.isNotEmpty) StatusChip('draft', label: p.category),
                        if (p.isService) const StatusChip('draft', label: 'Service'),
                        if (!p.isActive) const StatusChip('inactive', label: 'Inactive'),
                        if (!p.isService && p.isOutOfStock)
                          const StatusChip('overdue', label: 'Out of stock')
                        else if (p.isLowStock)
                          const StatusChip('pending', label: 'Low stock'),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Spacing.md),
        ResponsiveGrid(
          columns: cols,
          children: [
            StatTile(label: 'Sale price', value: money(p.salePrice), icon: Icons.sell_rounded, accent: const Color(0xFF2563EB)),
            StatTile(
                label: 'Purchase price', value: money(p.purchasePrice), icon: Icons.shopping_bag_rounded, accent: const Color(0xFFEA580C)),
            if (!p.isService)
              StatTile(
                label: 'In stock',
                value: '${qty(p.stockQty)} ${p.unit}',
                icon: Icons.warehouse_rounded,
                accent: stockColor,
                caption: p.minStock > 0 ? 'Min ${qty(p.minStock)}' : null,
              ),
            StatTile(
              label: 'Margin',
              value: money(margin),
              icon: Icons.trending_up_rounded,
              accent: margin >= 0 ? StatusColors.success : StatusColors.danger,
              caption: p.salePrice > 0 ? '${(margin / p.salePrice * 100).toStringAsFixed(1)}%' : null,
            ),
          ],
        ),
        if (!p.isService) ...[
          const SizedBox(height: Spacing.md),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => showProductStockSheet(context, productId: p.id, productName: p.name),
                icon: const Icon(Icons.domain_rounded),
                label: const Text('By warehouse'),
              ),
            ),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () => showAdjustStockSheet(context, productId: p.id, productName: p.name),
                icon: const Icon(Icons.tune_rounded),
                label: const Text('Adjust stock'),
              ),
            ),
          ]),
        ],
        const SizedBox(height: Spacing.lg),
        SectionCard(
          title: 'Details',
          child: Column(children: [
            for (final r in <(String, String)>[
              ('Item code', p.itemCode),
              ('SKU', p.sku),
              ('Unit', p.unit),
              ('MRP', p.mrp > 0 ? money(p.mrp) : ''),
              ('GST rate', p.taxRate > 0 ? '${qty(p.taxRate)}%' : ''),
              ('HSN / SAC', p.hsnCode),
              ('Description', p.description),
            ].where((r) => r.$2.isNotEmpty))
              KeyValueRow(r.$1, r.$2),
          ]),
        ),
      ],
    );
  }
}
