import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/revision.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/models/product.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/master_detail.dart';
import '../../../shared/widgets/paged_list.dart';
import '../data/products_repository.dart';
import 'product_detail_screen.dart';

const productsAccent = Color(0xFF0891B2);

enum _Sort { name, lowStock, price }

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  String _q = '';
  String? _category;
  _Sort _sort = _Sort.name;
  String? _selected;

  void _open(Product p) {
    if (MasterDetail.isSplit(context)) {
      setState(() => _selected = p.id);
    } else {
      context.push('/products/${p.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final rev = ref.watch(dataRevisionProvider);
    final store = ref.watch(activeStoreIdProvider);
    final categories = ref.watch(productCategoriesProvider).asData?.value ?? const <String>[];
    final repo = ref.read(productsRepositoryProvider);

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.sm, Spacing.lg, Spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SearchField(hint: 'Search name, item code, SKU', onChanged: (v) => setState(() => _q = v)),
          const SizedBox(height: Spacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                PopupMenuButton<_Sort>(
                  initialValue: _sort,
                  onSelected: (s) => setState(() => _sort = s),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: _Sort.name, child: Text('Name (A–Z)')),
                    PopupMenuItem(value: _Sort.lowStock, child: Text('Lowest stock first')),
                    PopupMenuItem(value: _Sort.price, child: Text('Highest price first')),
                  ],
                  child: Chip(
                    avatar: const Icon(Icons.sort_rounded, size: 18),
                    label: Text(switch (_sort) {
                      _Sort.name => 'Name',
                      _Sort.lowStock => 'Low stock',
                      _Sort.price => 'Price',
                    }),
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                ChoiceChip(
                  label: const Text('All'),
                  selected: _category == null,
                  onSelected: (_) => setState(() => _category = null),
                ),
                for (final c in categories) ...[
                  const SizedBox(width: Spacing.sm),
                  ChoiceChip(
                    label: Text(c),
                    selected: _category == c,
                    onSelected: (_) => setState(() => _category = _category == c ? null : c),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    final list = PagedListView<Product>(
      resetKey: (_q, _category, _sort, rev, store),
      fetch: (page) => repo.list(
        page: page,
        search: _q,
        category: _category,
        sort: switch (_sort) { _Sort.name => 'name', _Sort.lowStock => 'stock', _Sort.price => 'sale_price' },
        ascending: _sort != _Sort.price,
      ),
      header: header,
      empty: EmptyState(
        icon: Icons.inventory_2_rounded,
        title: _q.isEmpty && _category == null ? 'No products yet' : 'No matching products',
        message: _q.isEmpty && _category == null ? 'Add the items and services you sell.' : null,
        action: _q.isEmpty && _category == null
            ? FilledButton.icon(
                onPressed: () => context.push('/products/new'),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add product'),
              )
            : null,
      ),
      itemBuilder: (ctx, p, _) => ProductTile(product: p, selected: p.id == _selected, onTap: () => _open(p)),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Products')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-product',
        onPressed: () => context.push('/products/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add product'),
      ),
      body: MasterDetail(
        list: list,
        detail: _selected == null
            ? null
            : ProductDetailScreen(
                key: ValueKey(_selected),
                productId: _selected!,
                embedded: true,
                onDeleted: () => setState(() => _selected = null),
              ),
      ),
    );
  }
}

class ProductTile extends StatelessWidget {
  const ProductTile({super.key, required this.product, required this.onTap, this.selected = false});
  final Product product;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final p = product;
    final stockColor = p.isService
        ? context.colors.onSurfaceVariant
        : p.isOutOfStock
            ? StatusColors.danger
            : p.isLowStock
                ? StatusColors.warning
                : StatusColors.success;
    return ListTile(
      selected: selected,
      selectedTileColor: context.colors.primaryContainer.withValues(alpha: 0.5),
      onTap: onTap,
      leading: IconBadge(p.isService ? Icons.handyman_rounded : Icons.inventory_2_rounded, color: productsAccent),
      title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(
        [if (p.itemCode.isNotEmpty) p.itemCode, if (p.category.isNotEmpty) p.category].join(' · ').ifEmpty(p.unit),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(money(p.salePrice), style: context.text.labelLarge),
          Text(
            p.isService ? 'Service' : '${qty(p.stockQty)} ${p.unit}',
            style: context.text.labelSmall?.copyWith(color: stockColor, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}
