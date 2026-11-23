import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/api/revision.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/models/party.dart';
import '../../../core/models/payment.dart';
import '../../../core/models/sales_docs.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/utils/share_utils.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/doc_widgets.dart';
import '../../../shared/widgets/form_widgets.dart';
import '../../../shared/widgets/line_items.dart';
import '../../../shared/widgets/master_detail.dart';
import '../../../shared/widgets/paged_list.dart';
import '../../../shared/widgets/pickers.dart';
import '../../invoices/data/invoice_math.dart';
import '../../parties/data/parties_repository.dart';
import '../../payments/data/payments_repository.dart';
import '../data/sales_docs_repository.dart';

const estimatesAccent = Color(0xFF2563EB);

const _statuses = <(String?, String)>[
  (null, 'All'),
  ('draft', 'Draft'),
  ('sent', 'Sent'),
  ('accepted', 'Accepted'),
  ('rejected', 'Rejected'),
  ('converted', 'Converted'),
];

// ── List ────────────────────────────────────────────────────────────────

class EstimatesScreen extends ConsumerStatefulWidget {
  const EstimatesScreen({super.key});

  @override
  ConsumerState<EstimatesScreen> createState() => _ListState();
}

class _ListState extends ConsumerState<EstimatesScreen> {
  String? _status;
  String? _selected;

  void _open(Quotation q) {
    if (MasterDetail.isSplit(context)) {
      setState(() => _selected = q.id);
    } else {
      context.push('/estimates/${q.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final rev = ref.watch(dataRevisionProvider);
    final store = ref.watch(activeStoreIdProvider);
    final repo = ref.read(salesDocsRepositoryProvider);
    final list = PagedListView<Quotation>(
      resetKey: (_status, rev, store),
      fetch: (page) => repo.quotations(page: page, status: _status),
      header: ChipsHeader(
        chips: [
          for (final (v, l) in _statuses)
            ChoiceChip(
              label: Text(l),
              selected: _status == v,
              onSelected: (_) => setState(() => _status = v),
            ),
        ],
      ),
      empty: EmptyState(
        icon: Icons.request_quote_rounded,
        title: _status == null
            ? 'No estimates yet'
            : 'No ${_status!} estimates',
        message: _status == null
            ? 'Send quotes to customers and turn accepted ones into invoices.'
            : null,
        action: _status == null
            ? FilledButton.icon(
                onPressed: () => context.push('/estimates/new'),
                icon: const Icon(Icons.add_rounded),
                label: const Text('New estimate'),
              )
            : null,
      ),
      itemBuilder: (ctx, q, _) => MoneyTile(
        icon: Icons.request_quote_rounded,
        accent: estimatesAccent,
        title: q.partyName,
        subtitle:
            '${q.number} · ${relativeDay(q.date)}${q.isExpired ? ' · expired' : ''}',
        amount: q.totalAmount,
        status: q.status,
        selected: q.id == _selected,
        onTap: () => _open(q),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Estimates')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new-estimate',
        onPressed: () => context.push('/estimates/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New estimate'),
      ),
      body: MasterDetail(
        list: list,
        detail: _selected == null
            ? null
            : EstimateDetailScreen(
                key: ValueKey(_selected),
                estimateId: _selected!,
                embedded: true,
              ),
      ),
    );
  }
}

// ── Detail ──────────────────────────────────────────────────────────────

class EstimateDetailScreen extends ConsumerWidget {
  const EstimateDetailScreen({
    super.key,
    required this.estimateId,
    this.embedded = false,
  });
  final String estimateId;
  final bool embedded;

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action,
    String done,
  ) async {
    try {
      await action();
      ref.read(dataRevisionProvider.notifier).bump();
      if (context.mounted) showSnack(context, done);
    } catch (e) {
      if (context.mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(quotationProvider(estimateId));
    final q = async.asData?.value;
    final repo = ref.read(salesDocsRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !embedded,
        title: Text(q?.number ?? 'Estimate'),
        actions: [
          if (q != null) ...[
            IconButton(
              tooltip: 'Share estimate',
              icon: const Icon(Icons.ios_share_rounded),
              // The backend renders estimates as a printable HTML page.
              onPressed: () => shareFile(
                context,
                ref.read(apiClientProvider),
                '/quotations/${q.id}/pdf',
                'Estimate_${q.number}.html',
                mimeType: 'text/html',
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (v) async {
                switch (v) {
                  case 'edit':
                    context.push('/estimates/${q.id}/edit');
                  case 'email':
                    await _run(
                      context,
                      ref,
                      () => repo.sendQuotation(q.id),
                      'Estimate emailed to ${q.party?.email ?? 'customer'}',
                    );
                  case 'accept':
                    await _run(
                      context,
                      ref,
                      () => repo.acceptQuotation(q.id),
                      'Marked as accepted',
                    );
                  case 'reject':
                    final reason = await askReason(
                      context,
                      title: 'Mark ${q.number} as rejected?',
                      confirmLabel: 'Mark rejected',
                    );
                    if (reason != null && context.mounted) {
                      await _run(
                        context,
                        ref,
                        () => repo.rejectQuotation(q.id, reason),
                        'Marked as rejected',
                      );
                    }
                  case 'delete':
                    final ok = await confirmSheet(
                      context,
                      title: 'Delete ${q.number}?',
                      confirmLabel: 'Delete',
                      destructive: true,
                    );
                    if (!ok || !context.mounted) return;
                    await _run(
                      context,
                      ref,
                      () => repo.deleteQuotation(q.id),
                      'Estimate deleted',
                    );
                    if (context.mounted && !embedded) context.pop();
                }
              },
              itemBuilder: (_) => [
                if (q.canEdit)
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Edit'),
                    ),
                  ),
                if (!q.isConverted && (q.party?.email.isNotEmpty ?? false))
                  const PopupMenuItem(
                    value: 'email',
                    child: ListTile(
                      leading: Icon(Icons.email_outlined),
                      title: Text('Email to customer'),
                    ),
                  ),
                if (!q.isConverted && q.status != 'accepted')
                  const PopupMenuItem(
                    value: 'accept',
                    child: ListTile(
                      leading: Icon(Icons.thumb_up_alt_outlined),
                      title: Text('Mark accepted'),
                    ),
                  ),
                if (!q.isConverted && q.status != 'rejected')
                  const PopupMenuItem(
                    value: 'reject',
                    child: ListTile(
                      leading: Icon(Icons.thumb_down_alt_outlined),
                      title: Text('Mark rejected'),
                    ),
                  ),
                if (!q.isConverted)
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(
                        Icons.delete_outline,
                        color: StatusColors.danger,
                      ),
                      title: Text('Delete'),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
      bottomNavigationBar: q == null || q.isConverted || q.status == 'rejected'
          ? null
          : SaveBar(
              label: 'Convert to invoice',
              onPressed: () => _showConvert(context, ref, q),
            ),
      body: async.when(
        loading: () => const SkeletonList(count: 6),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(quotationProvider(estimateId)),
        ),
        data: (q) => ListView(
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
                  if (q.isConverted && q.convertedInvoiceId != null)
                    Card(
                      color: StatusColors.success.withValues(alpha: 0.08),
                      child: ListTile(
                        leading: const Icon(
                          Icons.check_circle_rounded,
                          color: StatusColors.success,
                        ),
                        title: const Text('Converted to an invoice'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () =>
                            context.push('/invoices/${q.convertedInvoiceId}'),
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
                                  q.partyName,
                                  style: context.text.titleMedium,
                                ),
                              ),
                              StatusChip(
                                q.isExpired ? 'overdue' : q.status,
                                label: q.isExpired ? 'Expired' : null,
                              ),
                            ],
                          ),
                          const SizedBox(height: Spacing.sm),
                          Text(
                            money(q.totalAmount),
                            style: context.text.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: Spacing.md),
                          KeyValueRow('Date', dateText(q.date)),
                          KeyValueRow(
                            'Valid until',
                            q.validUntil == null ? '—' : dateText(q.validUntil),
                          ),
                          if (q.version > 1)
                            KeyValueRow('Revision', 'v${q.version}'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Spacing.lg),
                  DocItemsCard(lines: q.items),
                  const SizedBox(height: Spacing.lg),
                  SectionCard(
                    title: 'Summary',
                    child: Column(
                      children: [
                        KeyValueRow('Subtotal', money(q.subTotal)),
                        if (q.discountTotal > 0)
                          KeyValueRow(
                            'Item discounts',
                            '− ${money(q.discountTotal)}',
                          ),
                        if (q.quotationDiscount > 0)
                          KeyValueRow(
                            'Discount',
                            '− ${money(q.quotationDiscount)}',
                          ),
                        if (q.additionalCharges > 0)
                          KeyValueRow(
                            'Additional charges',
                            money(q.additionalCharges),
                          ),
                        if (q.roundOff.abs() >= 0.005)
                          KeyValueRow('Round off', money(q.roundOff)),
                        KeyValueRow('Total', money(q.totalAmount), bold: true),
                      ],
                    ),
                  ),
                  if (q.notes.isNotEmpty || q.terms.isNotEmpty) ...[
                    const SizedBox(height: Spacing.lg),
                    SectionCard(
                      title: 'Notes & terms',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (q.notes.isNotEmpty) Text(q.notes),
                          if (q.terms.isNotEmpty)
                            Text(q.terms, style: context.text.bodySmall),
                        ],
                      ),
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

  Future<void> _showConvert(BuildContext context, WidgetRef ref, Quotation q) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _ConvertSheet(quotation: q),
      );
}

class _ConvertSheet extends ConsumerStatefulWidget {
  const _ConvertSheet({required this.quotation});
  final Quotation quotation;

  @override
  ConsumerState<_ConvertSheet> createState() => _ConvertState();
}

class _ConvertState extends ConsumerState<_ConvertSheet> {
  final _form = GlobalKey<FormState>();
  late final _amount = TextEditingController(
    text: NumberField.text(widget.quotation.totalAmount),
  );
  String _mode = 'unpaid';
  String? _bankId;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _convert() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final inv = await ref
          .read(salesDocsRepositoryProvider)
          .convertQuotation(
            widget.quotation.id,
            mode: _mode,
            amountPaid: _mode == 'unpaid' ? 0 : NumberField.parse(_amount),
            bankAccountId: _bankId,
          );
      ref.read(dataRevisionProvider.notifier).bump();
      if (!mounted) return;
      Navigator.pop(context);
      showSnack(context, 'Invoice ${inv.number} created');
      context.push('/invoices/${inv.id}');
    } catch (e) {
      setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final banks =
        ref.watch(bankAccountsProvider).asData?.value ?? const <BankAccount>[];
    if (_bankId == null && banks.isNotEmpty) {
      _bankId = (banks.where((b) => b.isPrimary).firstOrNull ?? banks.first).id;
    }
    final total = widget.quotation.totalAmount;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Spacing.xl,
        0,
        Spacing.xl,
        MediaQuery.viewInsetsOf(context).bottom + Spacing.xl,
      ),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Convert ${widget.quotation.number} to an invoice',
              style: context.text.titleMedium,
            ),
            Text('Total ${money(total)}', style: context.text.bodySmall),
            const SizedBox(height: Spacing.lg),
            if (_error != null) ErrorBanner(_error!),
            Text('Payment received now', style: context.text.labelLarge),
            const SizedBox(height: Spacing.sm),
            Wrap(
              spacing: Spacing.sm,
              runSpacing: Spacing.sm,
              children: [
                ChoiceChip(
                  label: const Text('Unpaid'),
                  selected: _mode == 'unpaid',
                  onSelected: (_) => setState(() => _mode = 'unpaid'),
                ),
                for (final m in PaymentMode.receipt)
                  ChoiceChip(
                    label: Text(m.label),
                    selected: _mode == m.value,
                    onSelected: (_) => setState(() => _mode = m.value),
                  ),
              ],
            ),
            if (_mode != 'unpaid') ...[
              const SizedBox(height: Spacing.md),
              NumberField(
                controller: _amount,
                label: 'Amount received',
                validator: (v) {
                  final e = Validators.number(
                    v,
                    required: true,
                    allowZero: false,
                    field: 'Amount',
                  );
                  if (e != null) return e;
                  return (double.tryParse(v!) ?? 0) > total + 0.01
                      ? 'More than the estimate total'
                      : null;
                },
              ),
              if (_mode != 'cash' && banks.isNotEmpty) ...[
                const SizedBox(height: Spacing.md),
                DropdownButtonFormField<String>(
                  initialValue: _bankId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Deposit to'),
                  items: [
                    for (final b in banks)
                      DropdownMenuItem(value: b.id, child: Text(b.label)),
                  ],
                  onChanged: (v) => setState(() => _bankId = v),
                ),
              ],
            ],
            const SizedBox(height: Spacing.lg),
            FilledButton(
              onPressed: _busy ? null : _convert,
              child: _busy
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Create invoice'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Create / edit ───────────────────────────────────────────────────────

class EstimateFormScreen extends ConsumerWidget {
  const EstimateFormScreen({super.key, this.estimateId, this.partyId});
  final String? estimateId;
  final String? partyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (estimateId == null) return _EstimateForm(partyId: partyId);
    return ref
        .watch(quotationProvider(estimateId!))
        .when(
          loading: () => Scaffold(
            appBar: AppBar(title: const Text('Edit estimate')),
            body: const SkeletonList(count: 6),
          ),
          error: (e, _) => Scaffold(
            appBar: AppBar(title: const Text('Edit estimate')),
            body: ErrorView(
              error: e,
              onRetry: () => ref.invalidate(quotationProvider(estimateId!)),
            ),
          ),
          data: (q) => q.canEdit
              ? _EstimateForm(existing: q)
              : Scaffold(
                  appBar: AppBar(title: const Text('Edit estimate')),
                  body: const EmptyState(
                    icon: Icons.lock_outline_rounded,
                    title: 'Accepted or converted estimates can\'t be edited',
                  ),
                ),
        );
  }
}

class _EstimateForm extends ConsumerStatefulWidget {
  const _EstimateForm({this.existing, this.partyId});
  final Quotation? existing;
  final String? partyId;

  @override
  ConsumerState<_EstimateForm> createState() => _FormState();
}

class _FormState extends ConsumerState<_EstimateForm> {
  final _form = GlobalKey<FormState>();
  late final Quotation? _e = widget.existing;
  late final _number = TextEditingController(text: _e?.number);
  late final _discount = TextEditingController(
    text: NumberField.text(_e?.quotationDiscount ?? 0),
  );
  late final _charges = TextEditingController(
    text: NumberField.text(_e?.additionalCharges ?? 0),
  );
  late final _notes = TextEditingController(text: _e?.notes);
  late final _terms = TextEditingController(text: _e?.terms);
  late final List<LineItem> _lines = [
    for (final l in _e?.items ?? const [])
      LineItem(
        productId: l.productId,
        description: l.description,
        quantity: l.quantity,
        unitPrice: l.unitPrice,
        discountPct: l.discount,
        unit: l.unit,
        taxRate: l.taxRate,
      ),
  ];
  late Party? _party = _e?.party;
  late DateTime _date = _e?.date ?? DateTime.now();
  late DateTime? _validUntil =
      _e?.validUntil ?? DateTime.now().add(const Duration(days: 15));
  late bool _showExtras =
      (_e?.quotationDiscount ?? 0) > 0 || (_e?.additionalCharges ?? 0) > 0;
  bool _busy = false;
  String? _error;
  String? _partyError;

  @override
  void initState() {
    super.initState();
    final repo = ref.read(salesDocsRepositoryProvider);
    if (_e == null) {
      repo
          .nextQuotationNumber()
          .then((n) {
            if (mounted && _number.text.isEmpty) _number.text = n;
          })
          .catchError((_) {});
    }
    if (widget.partyId != null && _party == null) {
      ref
          .read(partiesRepositoryProvider)
          .get(widget.partyId!)
          .then((p) {
            if (mounted) setState(() => _party = p);
          })
          .catchError((_) {});
    }
  }

  @override
  void dispose() {
    for (final c in [_number, _discount, _charges, _notes, _terms]) {
      c.dispose();
    }
    super.dispose();
  }

  InvoiceTotals get _totals => InvoiceTotals.compute(
    _lines,
    invoiceDiscount: NumberField.parse(_discount),
    additionalCharges: NumberField.parse(_charges),
  );

  Future<void> _addProduct() async {
    final p = await pickProduct(context);
    if (p == null || !mounted) return;
    setState(() {
      final existing = _lines.where((l) => l.productId == p.id).firstOrNull;
      if (existing != null) {
        existing.quantity += 1;
      } else {
        _lines.add(
          LineItem(
            productId: p.id,
            description: p.name,
            unitPrice: p.salePrice,
            unit: p.unit,
            hsnCode: p.hsnCode,
            taxRate: p.taxRate,
          ),
        );
      }
    });
  }

  Future<void> _addCustom() async {
    final line = LineItem(description: '');
    if (await showLineEditor(context, line, isNew: true) == true) {
      setState(() => _lines.add(line));
    }
  }

  Future<void> _save() async {
    setState(() {
      _error = null;
      _partyError = _party == null ? 'Choose a customer' : null;
    });
    if (!_form.currentState!.validate() || _party == null) return;
    if (_lines.isEmpty) {
      setState(() => _error = 'Add at least one item.');
      return;
    }
    final d = QuotationDraft(
      partyId: _party!.id,
      number: _number.text,
      date: _date,
      validUntil: _validUntil,
      lines: _lines,
      discount: NumberField.parse(_discount),
      charges: NumberField.parse(_charges),
      notes: _notes.text,
      terms: _terms.text,
    );
    setState(() => _busy = true);
    try {
      final repo = ref.read(salesDocsRepositoryProvider);
      final saved = _e == null
          ? await repo.createQuotation(d)
          : await repo.updateQuotation(_e, d);
      ref.read(dataRevisionProvider.notifier).bump();
      if (!mounted) return;
      showSnack(
        context,
        _e == null ? 'Estimate ${saved.number} saved' : 'Changes saved',
      );
      _e == null
          ? context.pushReplacement('/estimates/${saved.id}')
          : context.pop();
    } catch (err) {
      setState(() => _error = errorMessage(err));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _totals;
    final chargesLocked = _e?.hasChargeItems ?? false;
    return Scaffold(
      appBar: AppBar(
        title: Text(_e == null ? 'New estimate' : 'Edit estimate'),
      ),
      bottomNavigationBar: SaveBar(
        label: _e == null ? 'Save estimate' : 'Save changes',
        busy: _busy,
        onPressed: _save,
        leading: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total', style: context.text.labelSmall),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                money(t.total),
                style: context.text.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(Spacing.lg),
          children: [
            ContentWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null) ErrorBanner(_error!),
                  FormSection(
                    title: 'Customer',
                    children: [
                      PickerField(
                        label: 'Estimate for',
                        icon: Icons.person_search_rounded,
                        value: _party?.name,
                        errorText: _partyError,
                        onTap: () async {
                          final p = await pickParty(context, type: 'customer');
                          if (p != null) {
                            setState(() {
                              _party = p;
                              _partyError = null;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  FormSection(
                    title: 'Details',
                    children: [
                      TextFormField(
                        controller: _number,
                        decoration: const InputDecoration(
                          labelText: 'Estimate number',
                        ),
                      ),
                      FieldRow(
                        children: [
                          DateField(
                            label: 'Date',
                            value: _date,
                            onChanged: (d) =>
                                setState(() => _date = d ?? _date),
                          ),
                          DateField(
                            label: 'Valid until',
                            value: _validUntil,
                            clearable: true,
                            firstDate: _date,
                            onChanged: (d) => setState(() => _validUntil = d),
                          ),
                        ],
                      ),
                    ],
                  ),
                  FormSection(
                    title: 'Items',
                    children: [
                      LineItemsEditor(
                        lines: _lines,
                        onChanged: () => setState(() {}),
                        onAddProduct: _addProduct,
                        onAddCustom: _addCustom,
                      ),
                    ],
                  ),
                  FormSection(
                    title: 'Summary',
                    children: [
                      KeyValueRow('Subtotal', money(t.subTotal)),
                      if (t.lineDiscounts > 0)
                        KeyValueRow(
                          'Item discounts',
                          '− ${money(t.lineDiscounts)}',
                        ),
                      if (!_showExtras)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => setState(() => _showExtras = true),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Add discount or charges'),
                          ),
                        )
                      else
                        FieldRow(
                          children: [
                            NumberField(
                              controller: _discount,
                              label: 'Discount',
                              validator: (v) =>
                                  Validators.number(v, field: 'Discount'),
                              onChanged: (_) => setState(() {}),
                            ),
                            chargesLocked
                                ? InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: 'Additional charges',
                                      helperText: 'Itemised on the web',
                                    ),
                                    child: Text(
                                      money(NumberField.parse(_charges)),
                                    ),
                                  )
                                : NumberField(
                                    controller: _charges,
                                    label: 'Additional charges',
                                    validator: (v) =>
                                        Validators.number(v, field: 'Charges'),
                                    onChanged: (_) => setState(() {}),
                                  ),
                          ],
                        ),
                      KeyValueRow('Total', money(t.total), bold: true),
                    ],
                  ),
                  FormSection(
                    title: 'Notes & terms',
                    children: [
                      TextFormField(
                        controller: _notes,
                        maxLines: 2,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(labelText: 'Notes'),
                      ),
                      TextFormField(
                        controller: _terms,
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Terms',
                          hintText: 'Prices valid for 15 days…',
                        ),
                      ),
                    ],
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
