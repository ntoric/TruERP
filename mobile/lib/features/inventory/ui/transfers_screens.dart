import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/revision.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/models/inventory.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/doc_widgets.dart';
import '../../../shared/widgets/form_widgets.dart';
import '../../../shared/widgets/line_items.dart';
import '../../../shared/widgets/paged_list.dart';
import '../../../shared/widgets/pickers.dart';
import '../data/inventory_repository.dart';

/// The backend records transfers (draft → submitted → received) but does
/// not move stock between warehouses; every screen says so.
const transferStockNote =
    'Transfers record goods in transit between warehouses. They don\'t change stock levels — adjust stock in each warehouse if needed.';

String _whName(List<Warehouse> list, String id) => list.where((w) => w.id == id).firstOrNull?.name ?? 'Warehouse';

class TransfersScreen extends ConsumerStatefulWidget {
  const TransfersScreen({super.key});

  @override
  ConsumerState<TransfersScreen> createState() => _ListState();
}

class _ListState extends ConsumerState<TransfersScreen> {
  String? _status;

  @override
  Widget build(BuildContext context) {
    final rev = ref.watch(dataRevisionProvider);
    final store = ref.watch(activeStoreIdProvider);
    final warehouses = ref.watch(warehousesProvider).asData?.value ?? const <Warehouse>[];
    final repo = ref.read(inventoryRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Stock transfers')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new-transfer',
        onPressed: () => context.push('/stock/transfers/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New transfer'),
      ),
      body: ContentWidth(
        maxWidth: 900,
        child: PagedListView<StockTransfer>(
          resetKey: (_status, rev, store),
          fetch: (page) => repo.transfers(page: page, status: _status),
          header: ChipsHeader(note: transferStockNote, chips: [
            for (final (v, l) in const [(null, 'All'), ('draft', 'Draft'), ('submitted', 'In transit'), ('received', 'Received')])
              ChoiceChip(label: Text(l), selected: _status == v, onSelected: (_) => setState(() => _status = v)),
          ]),
          empty: const EmptyState(icon: Icons.local_shipping_outlined, title: 'No transfers yet'),
          itemBuilder: (ctx, t, _) => ListTile(
            onTap: () => context.push('/stock/transfers/${t.id}'),
            leading: const IconBadge(Icons.local_shipping_rounded, color: Color(0xFF64748B)),
            title: Text('${_whName(warehouses, t.fromId)} → ${_whName(warehouses, t.toId)}', maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text('${t.totalItems} items · ${qty(t.totalQuantity)} units · ${relativeDay(t.createdAt)}'),
            trailing: StatusChip(t.status, label: t.status == 'submitted' ? 'In transit' : null),
          ),
        ),
      ),
    );
  }
}

/// Transfer plus product names (the endpoint returns ids only).
final _transferProvider = FutureProvider.autoDispose.family<(StockTransfer, Map<String, String>), String>((ref, id) async {
  ref.watch(dataRevisionProvider);
  final repo = ref.watch(inventoryRepositoryProvider);
  final t = await repo.transfer(id);
  final stocks = await repo.stocksFor(t.items.map((i) => i.productId).toSet().toList());
  return (t, {for (final s in stocks) s.productId: s.productName});
});

class TransferDetailScreen extends ConsumerWidget {
  const TransferDetailScreen({super.key, required this.transferId});
  final String transferId;

  Future<void> _advance(BuildContext context, WidgetRef ref, StockTransfer t) async {
    final submit = t.status == 'draft';
    final ok = await confirmSheet(context,
        title: submit ? 'Mark as sent?' : 'Mark as received?', message: transferStockNote, confirmLabel: submit ? 'Mark sent' : 'Mark received');
    if (!ok) return;
    try {
      final repo = ref.read(inventoryRepositoryProvider);
      await (submit ? repo.submitTransfer(t.id) : repo.receiveTransfer(t.id));
      ref.read(dataRevisionProvider.notifier).bump();
      if (context.mounted) showSnack(context, submit ? 'Transfer sent' : 'Transfer received');
    } catch (e) {
      if (context.mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_transferProvider(transferId));
    final warehouses = ref.watch(warehousesProvider).asData?.value ?? const <Warehouse>[];
    final t = async.asData?.value.$1;
    return Scaffold(
      appBar: AppBar(title: const Text('Transfer')),
      bottomNavigationBar: t == null || (t.status != 'draft' && t.status != 'submitted')
          ? null
          : SaveBar(label: t.status == 'draft' ? 'Mark sent' : 'Mark received', onPressed: () => _advance(context, ref, t)),
      body: async.when(
        loading: () => const SkeletonList(count: 4),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(_transferProvider(transferId))),
        data: (d) {
          final (t, names) = d;
          return ListView(
            padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.sm, Spacing.lg, Spacing.xxl),
            children: [
              ContentWidth(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(Spacing.lg),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Row(children: [
                          Expanded(
                            child: Text('${_whName(warehouses, t.fromId)} → ${_whName(warehouses, t.toId)}', style: context.text.titleMedium),
                          ),
                          StatusChip(t.status, label: t.status == 'submitted' ? 'In transit' : null),
                        ]),
                        const SizedBox(height: Spacing.md),
                        KeyValueRow('Created', dateText(t.createdAt)),
                        if (t.sentDate != null) KeyValueRow('Sent', dateText(t.sentDate)),
                        if (t.receivedDate != null) KeyValueRow('Received', dateText(t.receivedDate)),
                        if (t.notes.isNotEmpty) KeyValueRow('Notes', t.notes),
                      ]),
                    ),
                  ),
                  const SizedBox(height: Spacing.lg),
                  SectionCard(
                    title: 'Items (${t.items.length})',
                    padding: const EdgeInsets.only(bottom: Spacing.xs),
                    child: Column(children: [
                      for (final it in t.items)
                        ListTile(
                          dense: true,
                          title: Text(names[it.productId] ?? 'Product', maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: t.status == 'draft' ? null : Text('Sent ${qty(it.sent)} · received ${qty(it.received)}'),
                          trailing: Text(qty(it.quantity), style: context.text.labelLarge),
                        ),
                    ]),
                  ),
                  const SizedBox(height: Spacing.md),
                  Text(transferStockNote, style: context.text.bodySmall, textAlign: TextAlign.center),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }
}

class TransferFormScreen extends ConsumerStatefulWidget {
  const TransferFormScreen({super.key});

  @override
  ConsumerState<TransferFormScreen> createState() => _FormState();
}

class _FormState extends ConsumerState<TransferFormScreen> {
  final _notes = TextEditingController();
  final _qty = <String, double>{};
  final _names = <String, String>{};
  String? _from;
  String? _to;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final p = await pickProduct(context);
    if (p == null) return;
    setState(() {
      _names[p.id] = p.name;
      _qty[p.id] = (_qty[p.id] ?? 0) + 1;
    });
  }

  Future<void> _save() async {
    if (_from == null || _to == null || _from == _to) {
      setState(() => _error = 'Choose two different warehouses.');
      return;
    }
    if (_qty.values.every((q) => q <= 0)) {
      setState(() => _error = 'Add at least one item.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final t = await ref.read(inventoryRepositoryProvider).createTransfer(fromId: _from!, toId: _to!, qtyByProduct: _qty, notes: _notes.text);
      ref.read(dataRevisionProvider.notifier).bump();
      if (!mounted) return;
      showSnack(context, 'Transfer saved as draft');
      context.pushReplacement('/stock/transfers/${t.id}');
    } catch (e) {
      setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final warehouses = ref.watch(warehousesProvider).asData?.value.where((w) => w.isActive).toList() ?? const <Warehouse>[];
    return Scaffold(
      appBar: AppBar(title: const Text('New transfer')),
      bottomNavigationBar: SaveBar(label: 'Save transfer', busy: _busy, onPressed: _save),
      body: ListView(
        padding: const EdgeInsets.all(Spacing.lg),
        children: [
          ContentWidth(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (_error != null) ErrorBanner(_error!),
              if (warehouses.length < 2)
                const ErrorBanner('You need at least two active warehouses to transfer stock.'),
              FormSection(title: 'Route', children: [
                DropdownButtonFormField<String>(
                  initialValue: _from,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'From', prefixIcon: Icon(Icons.north_east_rounded)),
                  items: [for (final w in warehouses) DropdownMenuItem(value: w.id, child: Text(w.name))],
                  onChanged: (v) => setState(() => _from = v),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _to,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'To', prefixIcon: Icon(Icons.south_west_rounded)),
                  items: [for (final w in warehouses.where((w) => w.id != _from)) DropdownMenuItem(value: w.id, child: Text(w.name))],
                  onChanged: (v) => setState(() => _to = v),
                ),
              ]),
              FormSection(title: 'Items', children: [
                for (final id in _qty.keys.toList())
                  Row(children: [
                    Expanded(child: Text(_names[id] ?? 'Product', maxLines: 2, overflow: TextOverflow.ellipsis)),
                    QtyStepper(
                      value: _qty[id]!,
                      min: 0,
                      onChanged: (v) => setState(() => v <= 0 ? _qty.remove(id) : _qty[id] = v),
                    ),
                  ]),
                FilledButton.tonalIcon(onPressed: _add, icon: const Icon(Icons.add_rounded), label: const Text('Add item')),
              ]),
              FormSection(title: 'Notes', children: [
                TextFormField(controller: _notes, maxLines: 2, textCapitalization: TextCapitalization.sentences),
              ]),
              Text(transferStockNote, style: context.text.bodySmall, textAlign: TextAlign.center),
            ]),
          ),
        ],
      ),
    );
  }
}
