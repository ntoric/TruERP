import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/revision.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/models/sales_docs.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/doc_widgets.dart';
import '../../../shared/widgets/paged_list.dart';
import '../data/sales_docs_repository.dart';

final _totalProvider = FutureProvider.autoDispose
    .family<double, (String?, String)>((ref, k) {
      ref.watch(activeStoreIdProvider);
      ref.watch(dataRevisionProvider);
      return ref
          .watch(salesDocsRepositoryProvider)
          .discountTotal(type: k.$1, search: k.$2);
    });

/// Every discount given or received, across documents.
class DiscountsScreen extends ConsumerStatefulWidget {
  const DiscountsScreen({super.key});

  @override
  ConsumerState<DiscountsScreen> createState() => _State();
}

class _State extends ConsumerState<DiscountsScreen> {
  String? _type;
  String _q = '';

  String? _route(DiscountTxn t) => switch (t.type) {
    'sale_invoice' => '/invoices/${t.id}',
    'estimate' => '/estimates/${t.id}',
    'purchase_bill' => '/purchases/${t.id}',
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final rev = ref.watch(dataRevisionProvider);
    final store = ref.watch(activeStoreIdProvider);
    final total = ref.watch(_totalProvider((_type, _q))).asData?.value;
    final repo = ref.read(salesDocsRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Discounts')),
      body: ContentWidth(
        maxWidth: 900,
        child: PagedListView<DiscountTxn>(
          resetKey: (_type, _q, rev, store),
          fetch: (page) => repo.discounts(page: page, type: _type, search: _q),
          header: ListFilters(
            summary: SummaryStrip(
              cells: [('Total discount', total, const Color(0xFFCA8A04))],
            ),
            searchHint: 'Search number or party',
            onSearch: (v) => setState(() => _q = v),
            chips: [
              ChoiceChip(
                label: const Text('All'),
                selected: _type == null,
                onSelected: (_) => setState(() => _type = null),
              ),
              for (final (v, l) in DiscountTxn.types)
                ChoiceChip(
                  label: Text(l),
                  selected: _type == v,
                  onSelected: (_) =>
                      setState(() => _type = _type == v ? null : v),
                ),
            ],
          ),
          empty: const EmptyState(
            icon: Icons.percent_rounded,
            title: 'No discounts found',
          ),
          itemBuilder: (ctx, t, _) {
            final route = _route(t);
            return ListTile(
              onTap: route == null ? null : () => context.push(route),
              leading: const IconBadge(
                Icons.percent_rounded,
                color: Color(0xFFCA8A04),
              ),
              title: Text(
                t.partyName.isEmpty ? t.reference : t.partyName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                [
                  t.typeLabel,
                  t.reference,
                  relativeDay(t.date),
                ].where((s) => s.isNotEmpty).join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    money(t.totalDiscount),
                    style: ctx.text.labelLarge?.copyWith(
                      color: const Color(0xFFCA8A04),
                    ),
                  ),
                  if (t.documentTotal > 0)
                    Text(
                      'on ${moneyShort(t.documentTotal)}',
                      style: ctx.text.labelSmall,
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
