import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/revision.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/models/purchase.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/doc_widgets.dart';
import '../../../shared/widgets/master_detail.dart';
import '../../../shared/widgets/paged_list.dart';
import '../../shell/account_sheet.dart';
import '../data/purchases_repository.dart';
import 'purchase_bill_detail_screen.dart';

const purchasesAccent = Color(0xFFEA580C);

const _statuses = <(String?, String)>[
  (null, 'All'),
  ('unpaid', 'Unpaid'),
  ('partial', 'Partial'),
  ('paid', 'Paid'),
  ('draft', 'Draft'),
];

class PurchaseBillsScreen extends ConsumerStatefulWidget {
  const PurchaseBillsScreen({super.key, this.isTab = false});
  final bool isTab;

  @override
  ConsumerState<PurchaseBillsScreen> createState() =>
      _PurchaseBillsScreenState();
}

class _PurchaseBillsScreenState extends ConsumerState<PurchaseBillsScreen> {
  String? _status;
  String _q = '';
  DateTimeRange? _range;
  String? _selected;

  void _open(PurchaseBill b) {
    if (MasterDetail.isSplit(context)) {
      setState(() => _selected = b.id);
    } else {
      context.push('/purchases/${b.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final rev = ref.watch(dataRevisionProvider);
    final store = ref.watch(activeStoreIdProvider);
    final stats = ref.watch(purchaseStatsProvider).asData?.value;
    final repo = ref.read(purchasesRepositoryProvider);
    final filtered = _status != null || _q.isNotEmpty || _range != null;

    final list = PagedListView<PurchaseBill>(
      resetKey: (_status, _q, _range, rev, store),
      fetch: (page) => repo.bills(
        page: page,
        search: _q,
        status: _status,
        from: _range?.start,
        to: _range?.end,
      ),
      header: ListFilters(
        summary: SummaryStrip(
          cells: [
            ('Total purchases', stats?.total, null),
            ('Paid', stats?.paid, StatusColors.success),
            ('To pay', stats?.unpaid, StatusColors.danger),
          ],
        ),
        searchHint: 'Search bill number or vendor',
        onSearch: (v) => setState(() => _q = v),
        range: _range,
        onRange: (r) => setState(() => _range = r),
        chips: [
          for (final (value, label) in _statuses)
            ChoiceChip(
              label: Text(label),
              selected: _status == value,
              onSelected: (_) => setState(() => _status = value),
            ),
        ],
      ),
      empty: EmptyState(
        icon: Icons.shopping_bag_rounded,
        title: filtered ? 'No matching purchases' : 'No purchases yet',
        message: filtered
            ? null
            : 'Record bills from your vendors to track what you owe and update stock.',
        action: filtered
            ? null
            : FilledButton.icon(
                onPressed: () => context.push('/purchases/new'),
                icon: const Icon(Icons.add_rounded),
                label: const Text('New purchase'),
              ),
      ),
      itemBuilder: (ctx, b, _) => MoneyTile(
        icon: Icons.description_rounded,
        accent: purchasesAccent,
        title: b.vendorName,
        subtitle: '${b.number} · ${relativeDay(b.date)}',
        amount: b.totalAmount,
        status: b.status,
        selected: b.id == _selected,
        onTap: () => _open(b),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isTab ? 'Purchases' : 'Purchase bills'),
        automaticallyImplyLeading: !widget.isTab,
        actions: [
          IconButton(
            tooltip: 'Payments made',
            icon: const Icon(Icons.call_made_rounded),
            onPressed: () => context.push('/payments-out'),
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (r) => context.push(r),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: '/purchase-returns',
                child: ListTile(
                  leading: Icon(Icons.undo_rounded),
                  title: Text('Purchase returns'),
                ),
              ),
              PopupMenuItem(
                value: '/purchase-orders',
                child: ListTile(
                  leading: Icon(Icons.shopping_cart_checkout_rounded),
                  title: Text('Purchase orders'),
                ),
              ),
              PopupMenuItem(
                value: '/expenses',
                child: ListTile(
                  leading: Icon(Icons.receipt_rounded),
                  title: Text('Expenses'),
                ),
              ),
            ],
          ),
          if (widget.isTab) const AccountButton(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new-purchase',
        onPressed: () => context.push('/purchases/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New purchase'),
      ),
      body: MasterDetail(
        list: list,
        detail: _selected == null
            ? null
            : PurchaseBillDetailScreen(
                key: ValueKey(_selected),
                billId: _selected!,
                embedded: true,
                onDeleted: () => setState(() => _selected = null),
              ),
      ),
    );
  }
}
