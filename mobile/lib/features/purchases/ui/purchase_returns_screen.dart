import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/revision.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/models/purchase.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/doc_widgets.dart';
import '../../../shared/widgets/form_widgets.dart';
import '../../../shared/widgets/line_items.dart';
import '../../../shared/widgets/paged_list.dart';
import '../data/purchases_repository.dart';
import 'purchase_bills_screen.dart';

// ── List ────────────────────────────────────────────────────────────────

class PurchaseReturnsScreen extends ConsumerStatefulWidget {
  const PurchaseReturnsScreen({super.key});

  @override
  ConsumerState<PurchaseReturnsScreen> createState() => _ListState();
}

class _ListState extends ConsumerState<PurchaseReturnsScreen> {
  String? _status;

  @override
  Widget build(BuildContext context) {
    final rev = ref.watch(dataRevisionProvider);
    final store = ref.watch(activeStoreIdProvider);
    final repo = ref.read(purchasesRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Purchase returns')),
      body: ContentWidth(
        maxWidth: 900,
        child: PagedListView<PurchaseReturn>(
          resetKey: (_status, rev, store),
          fetch: (page) => repo.returns(page: page, status: _status),
          header: Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.lg,
              Spacing.sm,
              Spacing.lg,
              Spacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'To return items, open a purchase bill and choose "Return items".',
                  style: context.text.bodySmall,
                ),
                const SizedBox(height: Spacing.sm),
                Wrap(
                  spacing: Spacing.sm,
                  children: [
                    for (final (v, l) in const [
                      (null, 'All'),
                      ('draft', 'Draft'),
                      ('processed', 'Processed'),
                    ])
                      ChoiceChip(
                        label: Text(l),
                        selected: _status == v,
                        onSelected: (_) => setState(() => _status = v),
                      ),
                  ],
                ),
              ],
            ),
          ),
          empty: const EmptyState(
            icon: Icons.undo_rounded,
            title: 'No purchase returns',
            message: 'Goods sent back to vendors show up here.',
          ),
          itemBuilder: (ctx, r, _) => MoneyTile(
            icon: Icons.undo_rounded,
            accent: purchasesAccent,
            title: r.party?.name ?? 'Vendor',
            subtitle: [
              r.number,
              relativeDay(r.date),
              if (r.purchaseBillNumber != null) 'Bill ${r.purchaseBillNumber}',
            ].join(' · '),
            amount: r.amount,
            status: r.status,
            onTap: () => context.push('/purchase-returns/${r.id}'),
          ),
        ),
      ),
    );
  }
}

// ── Detail ──────────────────────────────────────────────────────────────

class PurchaseReturnDetailScreen extends ConsumerWidget {
  const PurchaseReturnDetailScreen({super.key, required this.returnId});
  final String returnId;

  Future<void> _process(
    BuildContext context,
    WidgetRef ref,
    PurchaseReturn r,
  ) async {
    final settle = r.refundMode == 'credit_note'
        ? 'A debit note of ${money(r.amount)} will reduce what you owe ${r.party?.name ?? 'the vendor'}.'
        : '${money(r.amount)} will be recorded as received by ${PurchaseReturn.refundLabel(r.refundMode)}.';
    final ok = await confirmSheet(
      context,
      title: 'Process return ${r.number}?',
      message:
          '$settle Stock for the returned items goes down. This can\'t be undone.',
      confirmLabel: 'Process return',
    );
    if (!ok) return;
    try {
      await ref.read(purchasesRepositoryProvider).processReturn(r.id);
      ref.read(dataRevisionProvider.notifier).bump();
      if (context.mounted) showSnack(context, 'Return ${r.number} processed');
    } catch (e) {
      if (context.mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    PurchaseReturn r,
  ) async {
    final ok = await confirmSheet(
      context,
      title: 'Delete draft ${r.number}?',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(purchasesRepositoryProvider).deleteReturn(r.id);
      ref.read(dataRevisionProvider.notifier).bump();
      if (context.mounted) context.pop();
    } catch (e) {
      if (context.mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(purchaseReturnProvider(returnId));
    final r = async.asData?.value;
    return Scaffold(
      appBar: AppBar(
        title: Text(r?.number ?? 'Purchase return'),
        actions: [
          if (r != null && r.isDraft)
            IconButton(
              tooltip: 'Delete draft',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(context, ref, r),
            ),
        ],
      ),
      bottomNavigationBar: r == null || !r.isDraft
          ? null
          : SaveBar(
              label: 'Process return',
              onPressed: () => _process(context, ref, r),
            ),
      body: async.when(
        loading: () => const SkeletonList(count: 5),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(purchaseReturnProvider(returnId)),
        ),
        data: (r) => ListView(
          padding: const EdgeInsets.fromLTRB(
            Spacing.lg,
            Spacing.sm,
            Spacing.lg,
            Spacing.xxl,
          ),
          children: [
            ContentWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(Spacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  r.party?.name ?? 'Vendor',
                                  style: context.text.titleMedium,
                                ),
                              ),
                              StatusChip(r.status),
                            ],
                          ),
                          const SizedBox(height: Spacing.sm),
                          Text(
                            money(r.amount),
                            style: context.text.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: Spacing.md),
                          KeyValueRow('Date', dateText(r.date)),
                          KeyValueRow(
                            'Refund as',
                            PurchaseReturn.refundLabel(r.refundMode),
                          ),
                          if (r.purchaseBillNumber != null)
                            KeyValueRow('Against bill', r.purchaseBillNumber!),
                          if (r.reason.isNotEmpty)
                            KeyValueRow('Reason', r.reason),
                          if (r.notes.isNotEmpty) KeyValueRow('Notes', r.notes),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Spacing.lg),
                  DocItemsCard(lines: r.items, showTax: true),
                  if (r.isDraft) ...[
                    const SizedBox(height: Spacing.md),
                    Text(
                      'Drafts don\'t affect stock or balances until processed.',
                      style: context.text.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Create from a bill ──────────────────────────────────────────────────

class PurchaseReturnFormScreen extends ConsumerStatefulWidget {
  const PurchaseReturnFormScreen({super.key, required this.billId});
  final String billId;

  @override
  ConsumerState<PurchaseReturnFormScreen> createState() => _FormState();
}

class _FormState extends ConsumerState<PurchaseReturnFormScreen> {
  final _reason = TextEditingController();
  final _notes = TextEditingController();
  final _qty = <String, double>{};
  DateTime _date = DateTime.now();
  String _refund = 'credit_note';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    _notes.dispose();
    super.dispose();
  }

  double _amount(PurchaseBill b) {
    var total = 0.0;
    for (final l in b.items) {
      final q = _qty[l.id] ?? 0;
      final price = l.unitPrice * (1 - l.discount / 100);
      final tax = b.taxExempt ? 0 : l.taxRate;
      total += q * price * (1 + tax / 100);
    }
    return total;
  }

  Future<void> _save(PurchaseBill b) async {
    if (_qty.values.every((q) => q <= 0)) {
      setState(() => _error = 'Choose at least one item to return.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await ref
          .read(purchasesRepositoryProvider)
          .createReturn(
            bill: b,
            qtyByLineId: _qty,
            date: _date,
            refundMode: _refund,
            reason: _reason.text,
            notes: _notes.text,
          );
      ref.read(dataRevisionProvider.notifier).bump();
      if (!mounted) return;
      showSnack(context, 'Return ${r.number} saved as draft');
      context.pushReplacement('/purchase-returns/${r.id}');
    } catch (e) {
      setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(purchaseBillProvider(widget.billId));
    return async.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Return items')),
        body: const SkeletonList(count: 5),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Return items')),
        body: ErrorView(
          error: e,
          onRetry: () => ref.invalidate(purchaseBillProvider(widget.billId)),
        ),
      ),
      data: (b) => Scaffold(
        appBar: AppBar(title: Text('Return from ${b.number}')),
        bottomNavigationBar: SaveBar(
          label: 'Save return',
          busy: _busy,
          onPressed: () => _save(b),
          leading: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Return value', style: context.text.labelSmall),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  money(_amount(b)),
                  style: context.text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(Spacing.lg),
          children: [
            ContentWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null) ErrorBanner(_error!),
                  FormSection(
                    title: 'Items to return',
                    children: [
                      for (final l in b.items)
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l.description,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    'Bought ${qty(l.quantity)} × ${money(l.unitPrice * (1 - l.discount / 100))}',
                                    style: context.text.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            QtyStepper(
                              value: _qty[l.id] ?? 0,
                              min: 0,
                              max: l.quantity,
                              onChanged: (v) => setState(() => _qty[l.id] = v),
                            ),
                          ],
                        ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => setState(() {
                            for (final l in b.items) {
                              _qty[l.id] = l.quantity;
                            }
                          }),
                          child: const Text('Return everything'),
                        ),
                      ),
                    ],
                  ),
                  FormSection(
                    title: 'Settlement',
                    children: [
                      Wrap(
                        spacing: Spacing.sm,
                        runSpacing: Spacing.sm,
                        children: [
                          for (final (v, l) in PurchaseReturn.refundModes)
                            ChoiceChip(
                              label: Text(l),
                              selected: _refund == v,
                              onSelected: (_) => setState(() => _refund = v),
                            ),
                        ],
                      ),
                      Text(
                        _refund == 'credit_note'
                            ? 'A debit note reduces what you owe this vendor.'
                            : 'Records money received back from the vendor.',
                        style: context.text.bodySmall,
                      ),
                      DateField(
                        label: 'Return date',
                        value: _date,
                        onChanged: (d) => setState(() => _date = d ?? _date),
                      ),
                      TextFormField(
                        controller: _reason,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Reason',
                          hintText: 'Damaged, wrong item…',
                        ),
                      ),
                      TextFormField(
                        controller: _notes,
                        maxLines: 2,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(labelText: 'Notes'),
                      ),
                    ],
                  ),
                  Text(
                    'Saved as a draft. Process it to update stock and the vendor balance.',
                    style: context.text.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
