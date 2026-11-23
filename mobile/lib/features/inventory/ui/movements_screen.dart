import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/revision.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/models/inventory.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/doc_widgets.dart';
import '../../../shared/widgets/paged_list.dart';
import '../data/inventory_repository.dart';

typedef _Key = (DateTimeRange, String?, String);

final _summaryProvider = FutureProvider.autoDispose.family<MovementSummary, _Key>((ref, k) {
  ref.watch(activeStoreIdProvider);
  ref.watch(dataRevisionProvider);
  return ref.watch(inventoryRepositoryProvider).movementSummary(from: k.$1.start, to: k.$1.end, type: k.$2, search: k.$3);
});

/// Stock in/out ledger; defaults to the current month like the web page.
class MovementsScreen extends ConsumerStatefulWidget {
  const MovementsScreen({super.key});

  @override
  ConsumerState<MovementsScreen> createState() => _State();
}

class _State extends ConsumerState<MovementsScreen> {
  late DateTimeRange _range = () {
    final n = DateTime.now();
    return DateTimeRange(start: DateTime(n.year, n.month, 1), end: DateTime(n.year, n.month, n.day));
  }();
  String? _type;
  String _q = '';

  /// Screen for a movement's source document, when mobile has one.
  String? _route(Movement m) {
    if (m.referenceId.isEmpty) return null;
    return switch (m.referenceType) {
      'invoice' => '/invoices/${m.referenceId}',
      'purchase_bill' => '/purchases/${m.referenceId}',
      'sales_return' => '/sales-returns/${m.referenceId}',
      'purchase_return' => '/purchase-returns/${m.referenceId}',
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final rev = ref.watch(dataRevisionProvider);
    final store = ref.watch(activeStoreIdProvider);
    final summary = ref.watch(_summaryProvider((_range, _type, _q))).asData?.value;
    final repo = ref.read(inventoryRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Stock movements')),
      body: ContentWidth(
        maxWidth: 900,
        child: PagedListView<Movement>(
          resetKey: (_range, _type, _q, rev, store),
          fetch: (page) => repo.movements(from: _range.start, to: _range.end, page: page, type: _type, search: _q),
          header: ListFilters(
            summary: Column(children: [
              SummaryStrip(countCells: const {0, 1, 2}, cells: [
                ('Opening', summary?.openingQty, null),
                ('In', summary?.inQty, StatusColors.success),
                ('Out', summary?.outQty, StatusColors.danger),
              ]),
              const SizedBox(height: Spacing.sm),
              SummaryStrip(countCells: const {0}, cells: [
                ('Closing qty', summary?.closingQty, null),
                ('Closing value', summary?.closingValue, null),
              ]),
            ]),
            searchHint: 'Search product, code or document',
            onSearch: (v) => setState(() => _q = v),
            range: _range,
            onRange: (r) {
              if (r != null) setState(() => _range = r);
            },
            chips: [
              ChoiceChip(label: const Text('All'), selected: _type == null, onSelected: (_) => setState(() => _type = null)),
              for (final (v, l) in Movement.types)
                ChoiceChip(label: Text(l), selected: _type == v, onSelected: (_) => setState(() => _type = _type == v ? null : v)),
            ],
          ),
          empty: const EmptyState(icon: Icons.swap_vert_rounded, title: 'No stock movements in this period'),
          itemBuilder: (ctx, m, _) {
            final route = _route(m);
            return ListTile(
              onTap: route == null ? null : () => context.push(route),
              leading: IconBadge(m.isIn ? Icons.south_west_rounded : Icons.north_east_rounded,
                  color: m.isIn ? StatusColors.success : StatusColors.danger),
              title: Text(m.productName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
              subtitle: Text(
                [m.typeLabel, if (m.documentNo.isNotEmpty) m.documentNo, dateShort(m.date), if (m.outletName.isNotEmpty) m.outletName].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(m.isIn ? '+${qty(m.qtyIn)}' : '−${qty(m.qtyOut)}',
                    style: ctx.text.labelLarge?.copyWith(color: m.isIn ? StatusColors.success : StatusColors.danger)),
                Text('Bal ${qty(m.stockAfter)} ${m.unit}', style: ctx.text.labelSmall),
              ]),
            );
          },
        ),
      ),
    );
  }
}
