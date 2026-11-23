import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/paged.dart';
import '../../../core/api/revision.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/models/invoice.dart';
import '../../../core/models/purchase.dart';
import '../../../core/models/sales_docs.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/doc_widgets.dart';
import '../../../shared/widgets/form_widgets.dart';
import '../../../shared/widgets/line_items.dart';
import '../../../shared/widgets/paged_list.dart';
import '../../invoices/data/invoices_repository.dart';
import '../../purchases/data/purchases_repository.dart';
import '../data/sales_docs_repository.dart';

/// Sales returns, credit notes and debit notes share list, detail and
/// create screens; this describes what differs.
enum ReturnKind {
  salesReturn(
    'sales-return',
    'sales-returns',
    'Sales returns',
    'Sales return',
    Icons.assignment_return_rounded,
    Color(0xFF2563EB),
  ),
  creditNote(
    'credit-note',
    'credit-notes',
    'Credit notes',
    'Credit note',
    Icons.note_add_rounded,
    Color(0xFF0F766E),
  ),
  debitNote(
    'debit-note',
    'debit-notes',
    'Debit notes',
    'Debit note',
    Icons.note_alt_rounded,
    Color(0xFFEA580C),
  );

  const ReturnKind(
    this.key,
    this.route,
    this.plural,
    this.singular,
    this.icon,
    this.accent,
  );
  final String key;
  final String route;
  final String plural;
  final String singular;
  final IconData icon;
  final Color accent;

  bool get fromBill => this == ReturnKind.debitNote;

  /// Status that finalises a draft: processed (returns) or issued (notes).
  String get finalStatus =>
      this == ReturnKind.salesReturn ? 'processed' : 'issued';
  String get finaliseLabel => this == ReturnKind.salesReturn
      ? 'Process return'
      : 'Issue ${singular.toLowerCase()}';

  List<(String, String)> get refundModes => switch (this) {
    ReturnKind.salesReturn => RefundModes.salesReturn,
    ReturnKind.creditNote => RefundModes.creditNote,
    ReturnKind.debitNote => RefundModes.debitNote,
  };

  List<(String?, String)> get statusFilters => this == ReturnKind.salesReturn
      ? const [(null, 'All'), ('draft', 'Draft'), ('processed', 'Processed')]
      : const [
          (null, 'All'),
          ('draft', 'Draft'),
          ('issued', 'Issued'),
          ('cancelled', 'Cancelled'),
        ];

  String get startHint => fromBill
      ? 'To raise one, open a purchase bill and choose "Debit note".'
      : 'To create one, open an invoice and choose "${this == ReturnKind.salesReturn ? 'Return items' : 'Credit note'}".';

  Future<Paged<ReturnDoc>> list(
    SalesDocsRepository repo,
    int page,
    String? status,
  ) => switch (this) {
    ReturnKind.salesReturn => repo.salesReturns(page: page, status: status),
    ReturnKind.creditNote => repo.creditNotes(page: page, status: status),
    ReturnKind.debitNote => repo.debitNotes(page: page, status: status),
  };

  static ReturnKind fromKey(String key) =>
      values.firstWhere((k) => k.key == key);
}

// ── List ────────────────────────────────────────────────────────────────

class ReturnDocsScreen extends ConsumerStatefulWidget {
  const ReturnDocsScreen({super.key, required this.kind});
  final ReturnKind kind;

  @override
  ConsumerState<ReturnDocsScreen> createState() => _ListState();
}

class _ListState extends ConsumerState<ReturnDocsScreen> {
  String? _status;

  @override
  Widget build(BuildContext context) {
    final k = widget.kind;
    final rev = ref.watch(dataRevisionProvider);
    final store = ref.watch(activeStoreIdProvider);
    final repo = ref.read(salesDocsRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: Text(k.plural)),
      body: ContentWidth(
        maxWidth: 900,
        child: PagedListView<ReturnDoc>(
          resetKey: (_status, rev, store),
          fetch: (page) => k.list(repo, page, _status),
          header: ChipsHeader(
            note: k.startHint,
            chips: [
              for (final (v, l) in k.statusFilters)
                ChoiceChip(
                  label: Text(l),
                  selected: _status == v,
                  onSelected: (_) => setState(() => _status = v),
                ),
            ],
          ),
          empty: EmptyState(
            icon: k.icon,
            title: 'No ${k.plural.toLowerCase()}',
            message: k.startHint,
          ),
          itemBuilder: (ctx, d, _) => MoneyTile(
            icon: k.icon,
            accent: k.accent,
            title: d.partyName,
            subtitle: [
              d.number,
              relativeDay(d.date),
              if (d.sourceNumber != null) d.sourceNumber!,
            ].join(' · '),
            amount: d.amount,
            status: d.status,
            struck: d.isCancelled,
            onTap: () => context.push('/${k.route}/${d.id}'),
          ),
        ),
      ),
    );
  }
}

// ── Detail ──────────────────────────────────────────────────────────────

class ReturnDocDetailScreen extends ConsumerWidget {
  const ReturnDocDetailScreen({
    super.key,
    required this.kind,
    required this.docId,
  });
  final ReturnKind kind;
  final String docId;

  String _effect(ReturnDoc d) {
    final party = d.partyName;
    final amt = money(d.amount - d.deductionTotal);
    return switch ((kind, d.refundMode)) {
      (ReturnKind.salesReturn, 'credit_note') =>
        '$amt is credited to $party. Returned items go back into stock.',
      (ReturnKind.salesReturn, _) =>
        '$amt is refunded to $party by ${RefundModes.label(d.refundMode)}. Returned items go back into stock.',
      (ReturnKind.creditNote, 'credit_note') =>
        '$amt is kept as credit for $party.',
      (ReturnKind.creditNote, _) =>
        '$amt is refunded to $party by ${RefundModes.label(d.refundMode)}.',
      (ReturnKind.debitNote, 'debit_note') =>
        'What you owe $party goes down by $amt.',
      (ReturnKind.debitNote, _) =>
        '$amt is recorded as received back from $party by ${RefundModes.label(d.refundMode)}.',
    };
  }

  Future<void> _finalise(
    BuildContext context,
    WidgetRef ref,
    ReturnDoc d,
  ) async {
    final ok = await confirmSheet(
      context,
      title: '${kind.finaliseLabel} ${d.number}?',
      message: '${_effect(d)} This can\'t be undone.',
      confirmLabel: kind.finaliseLabel,
    );
    if (!ok) return;
    final repo = ref.read(salesDocsRepositoryProvider);
    try {
      await switch (kind) {
        ReturnKind.salesReturn => repo.processSalesReturn(d.id),
        ReturnKind.creditNote => repo.issueCreditNote(d.id),
        ReturnKind.debitNote => repo.issueDebitNote(d.id),
      };
      ref.read(dataRevisionProvider.notifier).bump();
      if (context.mounted) {
        showSnack(context, '${d.number} ${kind.finalStatus}');
      }
    } catch (e) {
      if (context.mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  Future<void> _cancelOrDelete(
    BuildContext context,
    WidgetRef ref,
    ReturnDoc d,
  ) async {
    final repo = ref.read(salesDocsRepositoryProvider);
    try {
      if (kind == ReturnKind.salesReturn) {
        final ok = await confirmSheet(
          context,
          title: 'Delete draft ${d.number}?',
          confirmLabel: 'Delete',
          destructive: true,
        );
        if (!ok) return;
        await repo.deleteSalesReturn(d.id);
      } else {
        final reason = await askReason(
          context,
          title: 'Cancel ${d.number}?',
          confirmLabel: 'Cancel ${kind.singular.toLowerCase()}',
        );
        if (reason == null) return;
        await (kind == ReturnKind.creditNote
            ? repo.cancelCreditNote(d.id, reason)
            : repo.cancelDebitNote(d.id, reason));
      }
      ref.read(dataRevisionProvider.notifier).bump();
      if (!context.mounted) return;
      if (kind == ReturnKind.salesReturn) {
        context.pop();
      } else {
        showSnack(context, '${d.number} cancelled');
      }
    } catch (e) {
      if (context.mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(returnDocProvider((kind.key, docId)));
    final d = async.asData?.value;
    final canCancel =
        d != null &&
        (kind == ReturnKind.salesReturn ? d.isDraft : !d.isCancelled);
    return Scaffold(
      appBar: AppBar(
        title: Text(d?.number ?? kind.singular),
        actions: [
          if (canCancel)
            IconButton(
              tooltip: kind == ReturnKind.salesReturn
                  ? 'Delete draft'
                  : 'Cancel',
              icon: Icon(
                kind == ReturnKind.salesReturn
                    ? Icons.delete_outline
                    : Icons.block_rounded,
              ),
              onPressed: () => _cancelOrDelete(context, ref, d),
            ),
        ],
      ),
      bottomNavigationBar: d == null || !d.isDraft
          ? null
          : SaveBar(
              label: kind.finaliseLabel,
              onPressed: () => _finalise(context, ref, d),
            ),
      body: async.when(
        loading: () => const SkeletonList(count: 5),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(returnDocProvider((kind.key, docId))),
        ),
        data: (d) => ListView(
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
                  if (d.isCancelled)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Spacing.md),
                      child: ErrorBanner(
                        'Cancelled${d.cancelReason.isEmpty ? '' : ': ${d.cancelReason}'}',
                      ),
                    ),
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
                                  d.partyName,
                                  style: context.text.titleMedium,
                                ),
                              ),
                              StatusChip(d.status),
                            ],
                          ),
                          const SizedBox(height: Spacing.sm),
                          Text(
                            money(d.amount),
                            style: context.text.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: Spacing.md),
                          KeyValueRow('Date', dateText(d.date)),
                          KeyValueRow(
                            'Settle by',
                            RefundModes.label(d.refundMode),
                          ),
                          if (d.deductionTotal > 0)
                            KeyValueRow(
                              'Deductions',
                              '− ${money(d.deductionTotal)}',
                            ),
                          if (d.refundAmount > 0)
                            KeyValueRow('Refund', money(d.refundAmount)),
                          if (d.reason.isNotEmpty)
                            KeyValueRow('Reason', d.reason),
                          if (d.notes.isNotEmpty) KeyValueRow('Notes', d.notes),
                        ],
                      ),
                    ),
                  ),
                  if (d.sourceId != null) ...[
                    const SizedBox(height: Spacing.md),
                    OutlinedButton.icon(
                      onPressed: () => context.push(
                        kind.fromBill
                            ? '/purchases/${d.sourceId}'
                            : '/invoices/${d.sourceId}',
                      ),
                      icon: Icon(
                        kind.fromBill
                            ? Icons.description_outlined
                            : Icons.receipt_long_outlined,
                      ),
                      label: Text(
                        '${kind.fromBill ? 'Bill' : 'Invoice'} ${d.sourceNumber ?? ''}'
                            .trim(),
                      ),
                    ),
                  ],
                  const SizedBox(height: Spacing.lg),
                  DocItemsCard(lines: d.items, showTax: kind.fromBill),
                  if (d.isDraft) ...[
                    const SizedBox(height: Spacing.md),
                    Text(
                      'Drafts don\'t affect stock or balances. ${_effect(d)}',
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

// ── Create from an invoice or bill ──────────────────────────────────────

/// A source line the user can return/credit part of.
class _SourceLine {
  const _SourceLine(
    this.id,
    this.description,
    this.maxQty,
    this.netPrice,
    this.taxRate,
  );
  final String id;
  final String description;
  final double maxQty;
  final double netPrice;
  final double taxRate;
}

class ReturnDocFormScreen extends ConsumerStatefulWidget {
  const ReturnDocFormScreen({
    super.key,
    required this.kind,
    required this.sourceId,
  });
  final ReturnKind kind;

  /// Invoice id (sales return, credit note) or purchase bill id (debit note).
  final String sourceId;

  @override
  ConsumerState<ReturnDocFormScreen> createState() => _FormState();
}

class _FormState extends ConsumerState<ReturnDocFormScreen> {
  final _reason = TextEditingController();
  final _notes = TextEditingController();
  final _qty = <String, double>{};
  late String _refund = widget.kind.refundModes.last.$1;
  String? _settleInvoiceId;
  DateTime _date = DateTime.now();
  bool _busy = false;
  String? _error;

  Invoice? _invoice;
  PurchaseBill? _bill;
  List<Invoice> _otherOpenInvoices = const [];
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reason.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      if (widget.kind.fromBill) {
        _bill = await ref
            .read(purchasesRepositoryProvider)
            .bill(widget.sourceId);
      } else {
        final inv = await ref
            .read(invoicesRepositoryProvider)
            .get(widget.sourceId);
        _invoice = inv;
        if (widget.kind == ReturnKind.salesReturn) {
          // Credit can be applied against another open invoice of the same customer.
          final page = await ref
              .read(invoicesRepositoryProvider)
              .list(partyId: inv.partyId);
          _otherOpenInvoices = page.items
              .where(
                (i) => i.id != inv.id && !i.isCancelled && i.balanceDue > 0.005,
              )
              .toList();
        }
      }
    } catch (e) {
      _loadError = e;
    }
    if (mounted) setState(() {});
  }

  List<_SourceLine> get _lines => widget.kind.fromBill
      ? [
          for (final l in _bill?.items ?? const <DocLine>[])
            _SourceLine(
              l.id,
              l.description,
              l.quantity,
              l.unitPrice * (1 - l.discount / 100),
              _bill!.taxExempt ? 0 : l.taxRate,
            ),
        ]
      : [
          for (final l in _invoice?.items ?? const <InvoiceItem>[])
            if (l.id.isNotEmpty)
              _SourceLine(
                l.id,
                l.description,
                l.quantity,
                l.unitPrice * (1 - l.discount / 100),
                l.taxRate,
              ),
        ];

  double get _value => _lines.fold(
    0,
    (s, l) => s + (_qty[l.id] ?? 0) * l.netPrice * (1 + l.taxRate / 100),
  );

  Future<void> _save() async {
    if (_qty.values.every((q) => q <= 0)) {
      setState(() => _error = 'Choose at least one item.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final repo = ref.read(salesDocsRepositoryProvider);
    try {
      final doc = switch (widget.kind) {
        ReturnKind.salesReturn => await repo.createSalesReturn(
          invoice: _invoice!,
          qtyByItemId: _qty,
          date: _date,
          refundMode: _refund,
          settleInvoiceId: _settleInvoiceId,
          reason: _reason.text,
          notes: _notes.text,
        ),
        ReturnKind.creditNote => await repo.createCreditNote(
          invoice: _invoice!,
          qtyByItemId: _qty,
          date: _date,
          refundMode: _refund,
          reason: _reason.text,
        ),
        ReturnKind.debitNote => await repo.createDebitNote(
          bill: _bill!,
          qtyByItemId: _qty,
          date: _date,
          refundMode: _refund,
          reason: _reason.text,
        ),
      };
      ref.read(dataRevisionProvider.notifier).bump();
      if (!mounted) return;
      showSnack(
        context,
        '${widget.kind.singular} ${doc.number} saved as draft',
      );
      context.pushReplacement('/${widget.kind.route}/${doc.id}');
    } catch (e) {
      setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final k = widget.kind;
    final sourceNumber = _invoice?.number ?? _bill?.number;
    final loaded = _invoice != null || _bill != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          sourceNumber == null ? k.singular : '${k.singular} · $sourceNumber',
        ),
      ),
      bottomNavigationBar: !loaded
          ? null
          : SaveBar(
              label: 'Save draft',
              busy: _busy,
              onPressed: _save,
              leading: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Value', style: context.text.labelSmall),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      money(_value),
                      style: context.text.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
      body: _loadError != null
          ? ErrorView(
              error: _loadError!,
              onRetry: () {
                setState(() => _loadError = null);
                _load();
              },
            )
          : !loaded
          ? const SkeletonList(count: 5)
          : ListView(
              padding: const EdgeInsets.all(Spacing.lg),
              children: [
                ContentWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null) ErrorBanner(_error!),
                      FormSection(
                        title: 'Items',
                        children: [
                          for (final l in _lines)
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        l.description,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        '${qty(l.maxQty)} × ${money(l.netPrice)}${l.taxRate > 0 ? ' + GST ${qty(l.taxRate)}%' : ''}',
                                        style: context.text.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                QtyStepper(
                                  value: _qty[l.id] ?? 0,
                                  min: 0,
                                  max: l.maxQty,
                                  onChanged: (v) =>
                                      setState(() => _qty[l.id] = v),
                                ),
                              ],
                            ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: () => setState(() {
                                for (final l in _lines) {
                                  _qty[l.id] = l.maxQty;
                                }
                              }),
                              child: Text(
                                k == ReturnKind.salesReturn
                                    ? 'Return everything'
                                    : 'Select everything',
                              ),
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
                              for (final (v, l) in k.refundModes)
                                ChoiceChip(
                                  label: Text(l),
                                  selected: _refund == v,
                                  onSelected: (_) =>
                                      setState(() => _refund = v),
                                ),
                            ],
                          ),
                          if (k == ReturnKind.salesReturn &&
                              _refund == 'credit_note' &&
                              _otherOpenInvoices.isNotEmpty)
                            DropdownButtonFormField<String?>(
                              initialValue: _settleInvoiceId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Apply credit to (optional)',
                              ),
                              items: [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text('Keep as customer credit'),
                                ),
                                for (final i in _otherOpenInvoices)
                                  DropdownMenuItem(
                                    value: i.id,
                                    child: Text(
                                      '${i.number} · due ${money(i.balanceDue)}',
                                    ),
                                  ),
                              ],
                              onChanged: (v) =>
                                  setState(() => _settleInvoiceId = v),
                            ),
                          DateField(
                            label: 'Date',
                            value: _date,
                            onChanged: (d) =>
                                setState(() => _date = d ?? _date),
                          ),
                          TextFormField(
                            controller: _reason,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              labelText: 'Reason',
                              hintText: 'Damaged, wrong item, rate difference…',
                            ),
                          ),
                          if (k == ReturnKind.salesReturn)
                            TextFormField(
                              controller: _notes,
                              maxLines: 2,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: const InputDecoration(
                                labelText: 'Notes',
                              ),
                            ),
                        ],
                      ),
                      Text(
                        // Only processing a sales return moves stock; notes change balances only.
                        'Saved as a draft. ${k == ReturnKind.salesReturn ? 'Process it to update stock and the balance.' : 'Issue it to update the balance.'}',
                        style: context.text.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
