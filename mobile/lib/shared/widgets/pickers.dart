import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/paged.dart';
import '../../core/models/party.dart';
import '../../core/models/product.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/formatters.dart';
import '../../features/parties/data/parties_repository.dart';
import '../../features/products/data/products_repository.dart';
import 'common.dart';
import 'paged_list.dart';

/// Searchable party sheet. [type] limits to customer/vendor. Offers
/// "Add new" which opens the party form and returns the created party.
Future<Party?> pickParty(BuildContext context, {String? type}) =>
    showModalBottomSheet<Party>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _PickerSheet<Party>(
        title: type == 'vendor'
            ? 'Select vendor'
            : type == 'customer'
            ? 'Select customer'
            : 'Select party',
        hint: 'Search name, phone or GSTIN',
        addLabel: type == 'vendor' ? 'New vendor' : 'New customer',
        onAdd: (ctx) =>
            ctx.push<Party>('/parties/new${type == null ? '' : '?type=$type'}'),
        fetch: (ref, page, q) => ref
            .read(partiesRepositoryProvider)
            .list(page: page, search: q, type: type),
        itemBuilder: (ctx, p) => ListTile(
          leading: InitialsAvatar(p.name),
          title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            [p.phone, p.city].where((e) => e.isNotEmpty).join(' · '),
            maxLines: 1,
          ),
          trailing: p.balance.abs() > 0.005 ? _balance(ctx, p) : null,
        ),
      ),
    );

Widget _balance(BuildContext context, Party p) => Column(
  mainAxisAlignment: MainAxisAlignment.center,
  crossAxisAlignment: CrossAxisAlignment.end,
  children: [
    Text(
      moneyShort(p.balance.abs()),
      style: context.text.labelLarge?.copyWith(
        color: p.toCollect ? StatusColors.success : StatusColors.danger,
      ),
    ),
    Text(p.toCollect ? 'to collect' : 'to pay', style: context.text.labelSmall),
  ],
);

/// Searchable product sheet showing price and stock.
Future<Product?> pickProduct(BuildContext context) =>
    showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _PickerSheet<Product>(
        title: 'Add item',
        hint: 'Search name, code or SKU',
        addLabel: 'New product',
        onAdd: (ctx) => ctx.push<Product>('/products/new'),
        fetch: (ref, page, q) => ref
            .read(productsRepositoryProvider)
            .list(page: page, search: q, sort: 'name'),
        itemBuilder: (ctx, p) => ListTile(
          leading: const IconBadge(
            Icons.inventory_2_rounded,
            color: Color(0xFF0891B2),
          ),
          title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            p.isService ? 'Service' : 'Stock: ${qty(p.stockQty)} ${p.unit}',
            style: TextStyle(
              color: !p.isService && p.stockQty <= 0
                  ? StatusColors.danger
                  : null,
            ),
          ),
          trailing: Text(money(p.salePrice), style: ctx.text.labelLarge),
        ),
      ),
    );

class _PickerSheet<T> extends ConsumerStatefulWidget {
  const _PickerSheet({
    required this.title,
    required this.hint,
    required this.fetch,
    required this.itemBuilder,
    required this.addLabel,
    required this.onAdd,
  });

  final String title;
  final String hint;
  final String addLabel;
  final Future<T?> Function(BuildContext) onAdd;
  final Future<Paged<T>> Function(WidgetRef ref, int page, String q) fetch;
  final Widget Function(BuildContext, T) itemBuilder;

  @override
  ConsumerState<_PickerSheet<T>> createState() => _PickerSheetState<T>();
}

class _PickerSheetState<T> extends ConsumerState<_PickerSheet<T>> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.88,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.lg,
              0,
              Spacing.sm,
              Spacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(widget.title, style: context.text.titleMedium),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add_rounded),
                  label: Text(widget.addLabel),
                  onPressed: () async {
                    final created = await widget.onAdd(context);
                    if (created != null && context.mounted) {
                      Navigator.pop(context, created);
                    }
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
            child: SearchField(
              hint: widget.hint,
              autofocus: true,
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Expanded(
            child: PagedListView<T>(
              resetKey: _q,
              fetch: (page) => widget.fetch(ref, page, _q),
              empty: EmptyState(
                icon: Icons.search_off_rounded,
                title: _q.isEmpty ? 'Nothing here yet' : 'No matches for "$_q"',
                action: FilledButton.tonalIcon(
                  icon: const Icon(Icons.add_rounded),
                  label: Text(widget.addLabel),
                  onPressed: () async {
                    final created = await widget.onAdd(context);
                    if (created != null && context.mounted) {
                      Navigator.pop(context, created);
                    }
                  },
                ),
              ),
              itemBuilder: (ctx, item, _) => InkWell(
                onTap: () => Navigator.pop(context, item),
                child: widget.itemBuilder(ctx, item),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
