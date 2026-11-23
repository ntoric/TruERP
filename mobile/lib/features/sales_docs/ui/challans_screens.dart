import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/revision.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/models/line_item.dart';
import '../../../core/models/party.dart';
import '../../../core/models/sales_docs.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/doc_widgets.dart';
import '../../../shared/widgets/form_widgets.dart';
import '../../../shared/widgets/line_items.dart';
import '../../../shared/widgets/paged_list.dart';
import '../../../shared/widgets/pickers.dart';
import '../../parties/data/parties_repository.dart';
import '../data/sales_docs_repository.dart';

const challansAccent = Color(0xFF0891B2);

// ── List ────────────────────────────────────────────────────────────────

class ChallansScreen extends ConsumerStatefulWidget {
  const ChallansScreen({super.key});

  @override
  ConsumerState<ChallansScreen> createState() => _ListState();
}

class _ListState extends ConsumerState<ChallansScreen> {
  String? _status;

  @override
  Widget build(BuildContext context) {
    final rev = ref.watch(dataRevisionProvider);
    final store = ref.watch(activeStoreIdProvider);
    final repo = ref.read(salesDocsRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Delivery challans')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new-challan',
        onPressed: () => context.push('/delivery-challans/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New challan'),
      ),
      body: ContentWidth(
        maxWidth: 900,
        child: PagedListView<DeliveryChallan>(
          resetKey: (_status, rev, store),
          fetch: (page) => repo.challans(page: page, status: _status),
          header: ChipsHeader(chips: [
            for (final (v, l) in const [(null, 'All'), ('draft', 'Pending'), ('delivered', 'Delivered'), ('cancelled', 'Cancelled')])
              ChoiceChip(label: Text(l), selected: _status == v, onSelected: (_) => setState(() => _status = v)),
          ]),
          empty: EmptyState(
            icon: Icons.local_shipping_rounded,
            title: 'No delivery challans',
            message: 'Send goods with a challan and bill them later.',
            action: FilledButton.icon(
              onPressed: () => context.push('/delivery-challans/new'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New challan'),
            ),
          ),
          itemBuilder: (ctx, c, _) => MoneyTile(
            icon: Icons.local_shipping_rounded,
            accent: challansAccent,
            title: c.party?.name ?? 'Customer',
            subtitle: '${c.number} · ${relativeDay(c.date)} · ${qty(c.totalQuantity)} items',
            amount: c.subTotal,
            status: c.status,
            statusLabel: c.isDraft ? 'Pending' : null,
            onTap: () => context.push('/delivery-challans/${c.id}'),
          ),
        ),
      ),
    );
  }
}

// ── Detail ──────────────────────────────────────────────────────────────

class ChallanDetailScreen extends ConsumerWidget {
  const ChallanDetailScreen({super.key, required this.challanId});
  final String challanId;

  Future<void> _setStatus(BuildContext context, WidgetRef ref, DeliveryChallan c, String status) async {
    final (title, msg, label) = status == 'delivered'
        ? ('Mark ${c.number} as delivered?', 'Delivered challans can\'t be edited or deleted.', 'Mark delivered')
        : ('Cancel ${c.number}?', null, 'Cancel challan');
    final ok = await confirmSheet(context, title: title, message: msg, confirmLabel: label, destructive: status == 'cancelled');
    if (!ok) return;
    try {
      await ref.read(salesDocsRepositoryProvider).setChallanStatus(c, status);
      ref.read(dataRevisionProvider.notifier).bump();
      if (context.mounted) showSnack(context, status == 'delivered' ? 'Marked as delivered' : 'Challan cancelled');
    } catch (e) {
      if (context.mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, DeliveryChallan c) async {
    final ok = await confirmSheet(context, title: 'Delete ${c.number}?', confirmLabel: 'Delete', destructive: true);
    if (!ok) return;
    try {
      await ref.read(salesDocsRepositoryProvider).deleteChallan(c.id);
      ref.read(dataRevisionProvider.notifier).bump();
      if (context.mounted) context.pop();
    } catch (e) {
      if (context.mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(challanProvider(challanId));
    final c = async.asData?.value;
    return Scaffold(
      appBar: AppBar(
        title: Text(c?.number ?? 'Delivery challan'),
        actions: [
          if (c != null && c.status != 'delivered')
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'cancel') _setStatus(context, ref, c, 'cancelled');
                if (v == 'delete') _delete(context, ref, c);
              },
              itemBuilder: (_) => [
                if (c.status != 'cancelled')
                  const PopupMenuItem(value: 'cancel', child: ListTile(leading: Icon(Icons.block_rounded), title: Text('Cancel challan'))),
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(leading: Icon(Icons.delete_outline, color: StatusColors.danger), title: Text('Delete')),
                ),
              ],
            ),
        ],
      ),
      bottomNavigationBar: c == null || !c.isDraft
          ? null
          : SaveBar(label: 'Mark delivered', onPressed: () => _setStatus(context, ref, c, 'delivered')),
      body: async.when(
        loading: () => const SkeletonList(count: 5),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(challanProvider(challanId))),
        data: (c) => ListView(
          padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.sm, Spacing.lg, Spacing.xxl),
          children: [
            ContentWidth(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(Spacing.lg),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Row(children: [
                        Expanded(child: Text(c.party?.name ?? 'Customer', style: context.text.titleMedium)),
                        StatusChip(c.status, label: c.isDraft ? 'Pending' : null),
                      ]),
                      const SizedBox(height: Spacing.md),
                      KeyValueRow('Date', dateText(c.date)),
                      if (c.dueDate != null) KeyValueRow('Deliver by', dateText(c.dueDate)),
                      KeyValueRow('Total quantity', qty(c.totalQuantity)),
                      KeyValueRow('Value', money(c.subTotal)),
                      if (c.transportMode.isNotEmpty) KeyValueRow('Transport', titleCase(c.transportMode)),
                      if (c.vehicleNumber.isNotEmpty) KeyValueRow('Vehicle', c.vehicleNumber),
                      if (c.invoiceNumber != null) KeyValueRow('Invoice', c.invoiceNumber!),
                    ]),
                  ),
                ),
                const SizedBox(height: Spacing.lg),
                DocItemsCard(lines: c.items),
                if (c.notes.isNotEmpty) ...[const SizedBox(height: Spacing.lg), SectionCard(title: 'Notes', child: Text(c.notes))],
                if (c.invoiceId != null) ...[
                  const SizedBox(height: Spacing.lg),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/invoices/${c.invoiceId}'),
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('Open invoice'),
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

class ChallanFormScreen extends ConsumerStatefulWidget {
  const ChallanFormScreen({super.key, this.partyId});
  final String? partyId;

  @override
  ConsumerState<ChallanFormScreen> createState() => _FormState();
}

class _FormState extends ConsumerState<ChallanFormScreen> {
  final _form = GlobalKey<FormState>();
  final _number = TextEditingController();
  final _vehicle = TextEditingController();
  final _notes = TextEditingController();
  final _lines = <LineItem>[];
  Party? _party;
  DateTime _date = DateTime.now();
  DateTime? _due;
  String _transport = 'road';
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    ref.read(salesDocsRepositoryProvider).nextChallanNumber().then((n) {
      if (mounted && _number.text.isEmpty) _number.text = n;
    }).catchError((_) {});
    if (widget.partyId != null) {
      ref.read(partiesRepositoryProvider).get(widget.partyId!).then((p) {
        if (mounted) setState(() => _party = p);
      }).catchError((_) {});
    }
  }

  @override
  void dispose() {
    for (final c in [_number, _vehicle, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _addProduct() async {
    final p = await pickProduct(context);
    if (p == null || !mounted) return;
    setState(() {
      final existing = _lines.where((l) => l.productId == p.id).firstOrNull;
      if (existing != null) {
        existing.quantity += 1;
      } else {
        _lines.add(LineItem(productId: p.id, description: p.name, unitPrice: p.salePrice, unit: p.unit, stockQty: p.isService ? null : p.stockQty));
      }
    });
  }

  Future<void> _addCustom() async {
    final line = LineItem(description: '');
    if (await showLineEditor(context, line, isNew: true, showDiscount: false) == true) setState(() => _lines.add(line));
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_party == null || _lines.isEmpty) {
      setState(() => _error = _party == null ? 'Choose a customer.' : 'Add at least one item.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final c = await ref.read(salesDocsRepositoryProvider).createChallan(
            number: _number.text,
            partyId: _party!.id,
            date: _date,
            dueDate: _due,
            lines: _lines,
            vehicleNumber: _vehicle.text,
            transportMode: _transport,
            notes: _notes.text,
          );
      ref.read(dataRevisionProvider.notifier).bump();
      if (!mounted) return;
      showSnack(context, 'Challan ${c.number} saved');
      context.pushReplacement('/delivery-challans/${c.id}');
    } catch (e) {
      setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = _lines.fold<double>(0, (s, l) => s + l.gross);
    return Scaffold(
      appBar: AppBar(title: const Text('New delivery challan')),
      bottomNavigationBar: SaveBar(
        label: 'Save challan',
        busy: _busy,
        onPressed: _save,
        leading: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Value', style: context.text.labelSmall),
          FittedBox(fit: BoxFit.scaleDown, child: Text(money(value), style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w700))),
        ]),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(Spacing.lg),
          children: [
            ContentWidth(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (_error != null) ErrorBanner(_error!),
                FormSection(title: 'Deliver to', children: [
                  PickerField(
                    label: 'Customer',
                    icon: Icons.person_search_rounded,
                    value: _party?.name,
                    subtitle: _party?.fullAddress.isEmpty ?? true ? null : _party!.fullAddress,
                    onTap: () async {
                      final p = await pickParty(context, type: 'customer');
                      if (p != null) setState(() => _party = p);
                    },
                  ),
                  TextFormField(
                    controller: _number,
                    decoration: const InputDecoration(labelText: 'Challan number *'),
                    validator: (v) => (v ?? '').trim().isEmpty ? 'Challan number is required' : null,
                  ),
                  FieldRow(children: [
                    DateField(label: 'Date', value: _date, onChanged: (d) => setState(() => _date = d ?? _date)),
                    DateField(label: 'Deliver by', value: _due, clearable: true, firstDate: _date, onChanged: (d) => setState(() => _due = d)),
                  ]),
                ]),
                FormSection(title: 'Items', children: [
                  LineItemsEditor(
                    lines: _lines,
                    showDiscount: false,
                    onChanged: () => setState(() {}),
                    onAddProduct: _addProduct,
                    onAddCustom: _addCustom,
                  ),
                ]),
                FormSection(title: 'Transport', children: [
                  Wrap(spacing: Spacing.sm, children: [
                    for (final (v, l) in DeliveryChallan.transportModes)
                      ChoiceChip(label: Text(l), selected: _transport == v, onSelected: (_) => setState(() => _transport = v)),
                  ]),
                  TextFormField(
                    controller: _vehicle,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'Vehicle number', hintText: 'KA01AB1234'),
                  ),
                  TextFormField(
                    controller: _notes,
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Notes'),
                  ),
                ]),
                Text('Challans don\'t change stock or balances; bill the customer with an invoice.',
                    style: context.text.bodySmall, textAlign: TextAlign.center),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
