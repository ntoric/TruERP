import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/revision.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/models/inventory.dart';
import '../../../core/models/product.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/doc_widgets.dart';
import '../../../shared/widgets/form_widgets.dart';
import '../../../shared/widgets/paged_list.dart';
import '../../../shared/widgets/pickers.dart';
import '../data/inventory_repository.dart';

const inventoryAccent = Color(0xFF0891B2);

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _State();
}

class _State extends ConsumerState<InventoryScreen> with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(inventoryStatsProvider).asData?.value;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock'),
        actions: [
          IconButton(tooltip: 'Movements', icon: const Icon(Icons.swap_vert_rounded), onPressed: () => context.push('/stock/movements')),
          PopupMenuButton<String>(
            onSelected: (r) => context.push(r),
            itemBuilder: (_) => const [
              PopupMenuItem(value: '/stock/transfers', child: ListTile(leading: Icon(Icons.local_shipping_outlined), title: Text('Transfers'))),
              PopupMenuItem(value: '/warehouses', child: ListTile(leading: Icon(Icons.domain_rounded), title: Text('Warehouses'))),
              PopupMenuItem(value: '/categories', child: ListTile(leading: Icon(Icons.sell_outlined), title: Text('Categories'))),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(132),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, Spacing.sm),
              child: SummaryStrip(countCells: const {1}, cells: [
                ('Stock value', stats?.totalValue, null),
                ('Low stock items', stats?.lowStockCount.toDouble(), (stats?.lowStockCount ?? 0) > 0 ? StatusColors.warning : null),
              ]),
            ),
            TabBar(controller: _tabs, tabs: const [Tab(text: 'All stock'), Tab(text: 'Low stock'), Tab(text: 'Approvals')]),
          ]),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'adjust-stock',
        onPressed: () => showAdjustStockSheet(context),
        icon: const Icon(Icons.tune_rounded),
        label: const Text('Adjust stock'),
      ),
      body: TabBarView(controller: _tabs, children: const [_AllStock(), _LowStock(), _Approvals()]),
    );
  }
}

class _AllStock extends ConsumerStatefulWidget {
  const _AllStock();

  @override
  ConsumerState<_AllStock> createState() => _AllStockState();
}

class _AllStockState extends ConsumerState<_AllStock> {
  String _q = '';
  String? _outlet;
  bool _inStockOnly = false;

  @override
  Widget build(BuildContext context) {
    final rev = ref.watch(dataRevisionProvider);
    final store = ref.watch(activeStoreIdProvider);
    final warehouses = ref.watch(warehousesProvider).asData?.value ?? const <Warehouse>[];
    final repo = ref.read(inventoryRepositoryProvider);
    return ContentWidth(
      maxWidth: 900,
      child: PagedListView<StockRow>(
        resetKey: (_q, _outlet, _inStockOnly, rev, store),
        fetch: (page) => repo.stocks(page: page, search: _q, outletId: _outlet, availableOnly: _inStockOnly),
        header: ListFilters(
          searchHint: 'Search product, code or batch',
          onSearch: (v) => setState(() => _q = v),
          chips: [
            FilterChip(label: const Text('In stock only'), selected: _inStockOnly, onSelected: (v) => setState(() => _inStockOnly = v)),
            if (warehouses.length > 1) ...[
              ChoiceChip(label: const Text('All warehouses'), selected: _outlet == null, onSelected: (_) => setState(() => _outlet = null)),
              for (final w in warehouses)
                ChoiceChip(label: Text(w.name), selected: _outlet == w.id, onSelected: (_) => setState(() => _outlet = _outlet == w.id ? null : w.id)),
            ],
          ],
        ),
        empty: const EmptyState(icon: Icons.warehouse_rounded, title: 'No stock found', message: 'Stock appears here once you buy or add opening stock.'),
        itemBuilder: (ctx, s, _) => ListTile(
          onTap: () => showProductStockSheet(context, productId: s.productId, productName: s.productName),
          leading: const IconBadge(Icons.inventory_2_rounded, color: inventoryAccent),
          title: Text(s.productName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Text(
            [
              if (s.outletName.isNotEmpty) s.outletName,
              if (s.batchNo.isNotEmpty) 'Batch ${s.batchNo}',
              if (s.expDate != null) 'Exp ${dateShort(s.expDate)}',
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: s.isExpiringSoon ? StatusColors.warning : null),
          ),
          trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${qty(s.available)} ${s.unit}',
                style: ctx.text.labelLarge?.copyWith(color: s.available <= 0 ? StatusColors.danger : null)),
            Text(moneyShort(s.value), style: ctx.text.labelSmall),
          ]),
        ),
      ),
    );
  }
}

class _LowStock extends ConsumerWidget {
  const _LowStock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rev = ref.watch(dataRevisionProvider);
    final store = ref.watch(activeStoreIdProvider);
    final repo = ref.read(inventoryRepositoryProvider);
    return ContentWidth(
      maxWidth: 900,
      child: PagedListView<LowStockRow>(
        resetKey: (rev, store),
        fetch: (page) => repo.lowStock(page: page),
        empty: const EmptyState(icon: Icons.check_circle_outline_rounded, title: 'Nothing is running low'),
        itemBuilder: (ctx, l, _) => ListTile(
          onTap: () => context.push('/products/${l.productId}'),
          leading: IconBadge(Icons.warning_amber_rounded, color: l.current <= 0 ? StatusColors.danger : StatusColors.warning),
          title: Text(l.productName, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(['Min ${qty(l.min)}', if (l.outletName.isNotEmpty) l.outletName].join(' · ')),
          trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(qty(l.current), style: ctx.text.labelLarge?.copyWith(color: l.current <= 0 ? StatusColors.danger : StatusColors.warning)),
            if (l.shortBy > 0) Text('short ${qty(l.shortBy)}', style: ctx.text.labelSmall),
          ]),
        ),
      ),
    );
  }
}

class _Approvals extends ConsumerStatefulWidget {
  const _Approvals();

  @override
  ConsumerState<_Approvals> createState() => _ApprovalsState();
}

class _ApprovalsState extends ConsumerState<_Approvals> {
  String _status = 'pending';

  Future<void> _act(Future<void> Function() action, String done) async {
    try {
      await action();
      ref.read(dataRevisionProvider.notifier).bump();
      if (mounted) showSnack(context, done);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rev = ref.watch(dataRevisionProvider);
    final store = ref.watch(activeStoreIdProvider);
    final repo = ref.read(inventoryRepositoryProvider);
    return ContentWidth(
      maxWidth: 900,
      child: PagedListView<StockEntry>(
        resetKey: (_status, rev, store),
        fetch: (page) => repo.entries(page: page, status: _status),
        header: Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.sm, Spacing.lg, Spacing.sm),
          child: Row(children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (final (v, l) in const [('pending', 'Pending'), ('approved', 'Approved'), ('rejected', 'Rejected')]) ...[
                    ChoiceChip(label: Text(l), selected: _status == v, onSelected: (_) => setState(() => _status = v)),
                    const SizedBox(width: Spacing.sm),
                  ],
                ]),
              ),
            ),
            if (_status == 'pending')
              IconButton(
                tooltip: 'Approve all',
                icon: const Icon(Icons.done_all_rounded, color: StatusColors.success),
                onPressed: () async {
                  final ok = await confirmSheet(context,
                      title: 'Approve all pending entries?', message: 'Stock is updated for every pending entry.', confirmLabel: 'Approve all');
                  if (ok) await _act(repo.approveAll, 'All pending entries approved');
                },
              ),
          ]),
        ),
        empty: EmptyState(
          icon: Icons.fact_check_outlined,
          title: _status == 'pending' ? 'Nothing waiting for approval' : 'No $_status entries',
        ),
        itemBuilder: (ctx, e, _) => ListTile(
          leading: IconBadge(e.quantity >= 0 ? Icons.south_west_rounded : Icons.north_east_rounded,
              color: e.quantity >= 0 ? StatusColors.success : StatusColors.danger),
          title: Text(e.itemName, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text([titleCase(e.entryType), if (e.outletName.isNotEmpty) e.outletName, relativeDay(e.date)].join(' · ')),
          trailing: e.status != 'pending'
              ? Text('${e.quantity >= 0 ? '+' : ''}${qty(e.quantity)}', style: ctx.text.labelLarge)
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('${e.quantity >= 0 ? '+' : ''}${qty(e.quantity)}', style: ctx.text.labelLarge),
                  IconButton(
                    tooltip: 'Reject',
                    icon: const Icon(Icons.close_rounded, color: StatusColors.danger),
                    onPressed: () async {
                      final reason = await askReason(context, title: 'Reject this entry?', confirmLabel: 'Reject');
                      if (reason != null) await _act(() => repo.reject(e.id, reason), 'Entry rejected');
                    },
                  ),
                  IconButton(
                    tooltip: 'Approve',
                    icon: const Icon(Icons.check_rounded, color: StatusColors.success),
                    onPressed: () => _act(() => repo.approve(e.id), 'Entry approved'),
                  ),
                ]),
        ),
      ),
    );
  }
}

// ── Product stock breakdown ─────────────────────────────────────────────

Future<void> showProductStockSheet(BuildContext context, {required String productId, required String productName}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ProductStockSheet(productId: productId, productName: productName),
    );

final _productStockProvider = FutureProvider.autoDispose.family<List<StockRow>, String>((ref, id) async {
  ref.watch(dataRevisionProvider);
  return (await ref.watch(inventoryRepositoryProvider).stocks(productId: id, page: 1)).items;
});

class _ProductStockSheet extends ConsumerWidget {
  const _ProductStockSheet({required this.productId, required this.productName});
  final String productId;
  final String productName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_productStockProvider(productId));
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.xl, 0, Spacing.xl, Spacing.lg),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(productName, style: context.text.titleMedium),
            const SizedBox(height: Spacing.md),
            Flexible(
              child: async.when(
                loading: () => const Padding(padding: EdgeInsets.all(Spacing.lg), child: LinearProgressIndicator()),
                error: (e, _) => Text(errorMessage(e)),
                data: (rows) {
                  final total = rows.fold<double>(0, (s, r) => s + r.available);
                  return ListView(shrinkWrap: true, children: [
                    KeyValueRow('Total available', '${qty(total)} ${rows.isEmpty ? '' : rows.first.unit}', bold: true),
                    const Divider(),
                    for (final r in rows)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(r.outletName.isEmpty ? 'Warehouse' : r.outletName),
                        subtitle: Text([
                          if (r.batchNo.isNotEmpty) 'Batch ${r.batchNo}',
                          if (r.reserved > 0) '${qty(r.reserved)} reserved',
                          'Avg cost ${money(r.averageCost)}',
                        ].join(' · ')),
                        trailing: Text(qty(r.available), style: context.text.labelLarge),
                      ),
                  ]);
                },
              ),
            ),
            const SizedBox(height: Spacing.md),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/products/$productId');
                  },
                  child: const Text('Open product'),
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    showAdjustStockSheet(context, productId: productId, productName: productName);
                  },
                  child: const Text('Adjust'),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ── Adjust stock ────────────────────────────────────────────────────────

const adjustReasons = ['Damaged', 'Expired', 'Lost / theft', 'Found in count', 'Stock count correction', 'Free sample', 'Other'];

/// Add or remove stock for one product in one warehouse.
Future<void> showAdjustStockSheet(BuildContext context, {String? productId, String? productName}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AdjustSheet(productId: productId, productName: productName),
    );

class _AdjustSheet extends ConsumerStatefulWidget {
  const _AdjustSheet({this.productId, this.productName});
  final String? productId;
  final String? productName;

  @override
  ConsumerState<_AdjustSheet> createState() => _AdjustState();
}

class _AdjustState extends ConsumerState<_AdjustSheet> {
  final _form = GlobalKey<FormState>();
  final _qty = TextEditingController();
  final _note = TextEditingController();
  late String? _productId = widget.productId;
  late String? _productName = widget.productName;
  String? _outletId;
  bool _add = true;
  String _reason = adjustReasons.last;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _qty.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final Product? p = await pickProduct(context);
    if (p != null) {
      setState(() {
        _productId = p.id;
        _productName = p.name;
      });
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_productId == null || _outletId == null) {
      setState(() => _error = _productId == null ? 'Choose a product.' : 'Choose a warehouse.');
      return;
    }
    final amount = NumberField.parse(_qty);
    final reason = [_reason, if (_note.text.trim().isNotEmpty) _note.text.trim()].join(' — ');
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(inventoryRepositoryProvider).adjust(
            productId: _productId!,
            productName: _productName ?? '',
            outletId: _outletId!,
            quantity: _add ? amount : -amount,
            reason: reason,
          );
      ref.read(dataRevisionProvider.notifier).bump();
      if (!mounted) return;
      Navigator.pop(context);
      showSnack(context, '${_add ? 'Added' : 'Removed'} ${qty(amount)} · $_productName');
    } catch (e) {
      setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final warehouses = ref.watch(warehousesProvider);
    final active = warehouses.asData?.value.where((w) => w.isActive).toList() ?? const <Warehouse>[];
    _outletId ??= (active.where((w) => w.isDefault).firstOrNull ?? active.firstOrNull)?.id;

    return Padding(
      padding: EdgeInsets.fromLTRB(Spacing.xl, 0, Spacing.xl, MediaQuery.viewInsetsOf(context).bottom + Spacing.xl),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Adjust stock', style: context.text.titleMedium),
            const SizedBox(height: Spacing.md),
            if (_error != null) ErrorBanner(_error!),
            PickerField(label: 'Product', icon: Icons.inventory_2_outlined, value: _productName, onTap: _pick),
            const SizedBox(height: Spacing.md),
            if (warehouses.isLoading)
              const LinearProgressIndicator()
            else if (active.isEmpty)
              const ErrorBanner('Add a warehouse first (Stock → ⋯ → Warehouses).')
            else
              DropdownButtonFormField<String>(
                initialValue: _outletId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Warehouse', prefixIcon: Icon(Icons.domain_rounded)),
                items: [for (final w in active) DropdownMenuItem(value: w.id, child: Text(w.isDefault ? '${w.name} (default)' : w.name))],
                onChanged: (v) => setState(() => _outletId = v),
              ),
            const SizedBox(height: Spacing.md),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: true, icon: Icon(Icons.add_rounded), label: Text('Add stock')),
                ButtonSegment(value: false, icon: Icon(Icons.remove_rounded), label: Text('Remove stock')),
              ],
              selected: {_add},
              onSelectionChanged: (s) => setState(() => _add = s.first),
            ),
            const SizedBox(height: Spacing.md),
            NumberField(
              controller: _qty,
              label: 'Quantity',
              money: false,
              validator: (v) => Validators.number(v, required: true, allowZero: false, field: 'Quantity'),
            ),
            const SizedBox(height: Spacing.md),
            Wrap(spacing: Spacing.sm, runSpacing: Spacing.sm, children: [
              for (final r in adjustReasons) ChoiceChip(label: Text(r), selected: _reason == r, onSelected: (_) => setState(() => _reason = r)),
            ]),
            const SizedBox(height: Spacing.md),
            TextFormField(
              controller: _note,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Note'),
              validator: (v) => _reason == 'Other' && (v ?? '').trim().isEmpty ? 'Describe the reason' : null,
            ),
            const SizedBox(height: Spacing.lg),
            FilledButton(
              onPressed: _busy || active.isEmpty ? null : _save,
              child: _busy
                  ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : Text(_add ? 'Add stock' : 'Remove stock'),
            ),
          ]),
        ),
      ),
    );
  }
}
