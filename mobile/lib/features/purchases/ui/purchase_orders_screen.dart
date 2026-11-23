import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/revision.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/models/line_item.dart';
import '../../../core/models/party.dart';
import '../../../core/models/purchase.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/doc_widgets.dart';
import '../../../shared/widgets/form_widgets.dart';
import '../../../shared/widgets/line_items.dart';
import '../../../shared/widgets/paged_list.dart';
import '../../../shared/widgets/pickers.dart';
import '../data/purchases_repository.dart';
import 'purchase_bills_screen.dart';

// ── List ────────────────────────────────────────────────────────────────

class PurchaseOrdersScreen extends ConsumerStatefulWidget {
  const PurchaseOrdersScreen({super.key});

  @override
  ConsumerState<PurchaseOrdersScreen> createState() => _ListState();
}

class _ListState extends ConsumerState<PurchaseOrdersScreen> {
  String? _status;

  @override
  Widget build(BuildContext context) {
    final rev = ref.watch(dataRevisionProvider);
    final store = ref.watch(activeStoreIdProvider);
    final repo = ref.read(purchasesRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Purchase orders')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new-po',
        onPressed: () => context.push('/purchase-orders/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New order'),
      ),
      body: ContentWidth(
        maxWidth: 900,
        child: PagedListView<PurchaseOrder>(
          resetKey: (_status, rev, store),
          fetch: (page) => repo.orders(page: page, status: _status),
          header: Padding(
            padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.sm, Spacing.lg, Spacing.sm),
            child: Wrap(spacing: Spacing.sm, children: [
              for (final (v, l) in const [(null, 'All'), ('draft', 'Draft'), ('submitted', 'Submitted')])
                ChoiceChip(label: Text(l), selected: _status == v, onSelected: (_) => setState(() => _status = v)),
            ]),
          ),
          empty: const EmptyState(
            icon: Icons.shopping_cart_checkout_rounded,
            title: 'No purchase orders',
            message: 'Send orders to vendors before the goods arrive.',
          ),
          itemBuilder: (ctx, o, _) => MoneyTile(
            icon: Icons.shopping_cart_checkout_rounded,
            accent: purchasesAccent,
            title: o.party?.name ?? 'Vendor',
            subtitle: '${o.number} · ${relativeDay(o.date)}',
            amount: o.totalAmount,
            status: o.status,
            onTap: () => context.push('/purchase-orders/${o.id}'),
          ),
        ),
      ),
    );
  }
}

// ── Detail ──────────────────────────────────────────────────────────────

class PurchaseOrderDetailScreen extends ConsumerWidget {
  const PurchaseOrderDetailScreen({super.key, required this.orderId});
  final String orderId;

  Future<void> _submit(BuildContext context, WidgetRef ref, PurchaseOrder o) async {
    final ok = await confirmSheet(context,
        title: 'Submit ${o.number}?', message: 'Submitted orders can no longer be deleted.', confirmLabel: 'Submit order');
    if (!ok) return;
    try {
      await ref.read(purchasesRepositoryProvider).submitOrder(o.id);
      ref.read(dataRevisionProvider.notifier).bump();
      if (context.mounted) showSnack(context, '${o.number} submitted');
    } catch (e) {
      if (context.mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, PurchaseOrder o) async {
    final ok = await confirmSheet(context, title: 'Delete ${o.number}?', confirmLabel: 'Delete', destructive: true);
    if (!ok) return;
    try {
      await ref.read(purchasesRepositoryProvider).deleteOrder(o.id);
      ref.read(dataRevisionProvider.notifier).bump();
      if (context.mounted) context.pop();
    } catch (e) {
      if (context.mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(purchaseOrderProvider(orderId));
    final o = async.asData?.value;
    return Scaffold(
      appBar: AppBar(
        title: Text(o?.number ?? 'Purchase order'),
        actions: [
          if (o != null && o.isDraft)
            IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline), onPressed: () => _delete(context, ref, o)),
        ],
      ),
      bottomNavigationBar: o == null || !o.isDraft ? null : SaveBar(label: 'Submit order', onPressed: () => _submit(context, ref, o)),
      body: async.when(
        loading: () => const SkeletonList(count: 5),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(purchaseOrderProvider(orderId))),
        data: (o) => ListView(
          padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.sm, Spacing.lg, Spacing.xxl),
          children: [
            ContentWidth(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(Spacing.lg),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Row(children: [
                        Expanded(child: Text(o.party?.name ?? 'Vendor', style: context.text.titleMedium)),
                        StatusChip(o.status),
                      ]),
                      const SizedBox(height: Spacing.sm),
                      Text(money(o.totalAmount), style: context.text.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: Spacing.md),
                      KeyValueRow('Order date', dateText(o.date)),
                      if (o.expectedDate != null) KeyValueRow('Expected', dateText(o.expectedDate)),
                    ]),
                  ),
                ),
                const SizedBox(height: Spacing.lg),
                DocItemsCard(lines: o.items, showTax: true, showReceived: !o.isDraft),
                const SizedBox(height: Spacing.lg),
                SectionCard(
                  title: 'Summary',
                  child: Column(children: [
                    KeyValueRow('Subtotal', money(o.subTotal)),
                    KeyValueRow('GST', money(o.taxTotal)),
                    KeyValueRow('Total', money(o.totalAmount), bold: true),
                  ]),
                ),
                if (o.notes.isNotEmpty || o.terms.isNotEmpty) ...[
                  const SizedBox(height: Spacing.lg),
                  SectionCard(
                    title: 'Notes & terms',
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (o.notes.isNotEmpty) Text(o.notes),
                      if (o.terms.isNotEmpty) Text(o.terms, style: context.text.bodySmall),
                    ]),
                  ),
                ],
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Create ──────────────────────────────────────────────────────────────

class PurchaseOrderFormScreen extends ConsumerStatefulWidget {
  const PurchaseOrderFormScreen({super.key});

  @override
  ConsumerState<PurchaseOrderFormScreen> createState() => _FormState();
}

class _FormState extends ConsumerState<PurchaseOrderFormScreen> {
  final _notes = TextEditingController();
  final _terms = TextEditingController();
  final _lines = <LineItem>[];
  Party? _vendor;
  DateTime _date = DateTime.now();
  DateTime? _expected;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _notes.dispose();
    _terms.dispose();
    super.dispose();
  }

  // Orders have no discounts; total = qty × price + GST (server formula).
  double get _sub => _lines.fold(0, (s, l) => s + l.gross);
  double get _tax => _lines.fold(0, (s, l) => s + l.gross * l.taxRate / 100);

  Future<void> _addProduct() async {
    final p = await pickProduct(context);
    if (p == null || !mounted) return;
    setState(() {
      final existing = _lines.where((l) => l.productId == p.id).firstOrNull;
      if (existing != null) {
        existing.quantity += 1;
      } else {
        _lines.add(LineItem(productId: p.id, description: p.name, unitPrice: p.purchasePrice, unit: p.unit, taxRate: p.taxRate));
      }
    });
  }

  Future<void> _addCustom() async {
    final line = LineItem(description: '');
    final ok = await showLineEditor(context, line, isNew: true, showTax: true, showDiscount: false, priceLabel: 'Rate');
    if (ok == true) setState(() => _lines.add(line));
  }

  Future<void> _save() async {
    if (_vendor == null || _lines.isEmpty) {
      setState(() => _error = _vendor == null ? 'Choose a vendor.' : 'Add at least one item.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final o = await ref.read(purchasesRepositoryProvider).createOrder(
            partyId: _vendor!.id,
            date: _date,
            expected: _expected,
            lines: _lines,
            notes: _notes.text,
            terms: _terms.text,
          );
      ref.read(dataRevisionProvider.notifier).bump();
      if (!mounted) return;
      showSnack(context, 'Order ${o.number} saved as draft');
      context.pushReplacement('/purchase-orders/${o.id}');
    } catch (e) {
      setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New purchase order')),
      bottomNavigationBar: SaveBar(
        label: 'Save order',
        busy: _busy,
        onPressed: _save,
        leading: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Total', style: context.text.labelSmall),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(money(_sub + _tax), style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
      body: ListView(
        padding: const EdgeInsets.all(Spacing.lg),
        children: [
          ContentWidth(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (_error != null) ErrorBanner(_error!),
              FormSection(title: 'Vendor', children: [
                PickerField(
                  label: 'Order from',
                  icon: Icons.storefront_rounded,
                  value: _vendor?.name,
                  onTap: () async {
                    final p = await pickParty(context, type: 'vendor');
                    if (p != null) setState(() => _vendor = p);
                  },
                ),
                FieldRow(children: [
                  DateField(label: 'Order date', value: _date, onChanged: (d) => setState(() => _date = d ?? _date)),
                  DateField(
                    label: 'Expected by',
                    value: _expected,
                    clearable: true,
                    firstDate: _date,
                    onChanged: (d) => setState(() => _expected = d),
                  ),
                ]),
              ]),
              FormSection(title: 'Items', children: [
                LineItemsEditor(
                  lines: _lines,
                  showTax: true,
                  showDiscount: false,
                  priceLabel: 'Rate',
                  onChanged: () => setState(() {}),
                  onAddProduct: _addProduct,
                  onAddCustom: _addCustom,
                ),
                KeyValueRow('Subtotal', money(_sub)),
                KeyValueRow('GST', money(_tax)),
                KeyValueRow('Total', money(_sub + _tax), bold: true),
              ]),
              FormSection(title: 'Notes & terms', children: [
                TextFormField(
                  controller: _notes,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
                TextFormField(
                  controller: _terms,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Terms'),
                ),
              ]),
            ]),
          ),
        ],
      ),
    );
  }
}
