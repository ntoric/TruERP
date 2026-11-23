import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/revision.dart';
import '../../../core/models/party.dart';
import '../../../core/models/payment.dart';
import '../../../core/models/product.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/form_widgets.dart';
import '../../../shared/widgets/pickers.dart';
import '../../parties/data/parties_repository.dart';
import '../../payments/data/payments_repository.dart';
import '../data/invoice_math.dart';
import '../data/invoices_repository.dart';

class InvoiceFormScreen extends ConsumerStatefulWidget {
  const InvoiceFormScreen({super.key, this.partyId});
  final String? partyId;

  @override
  ConsumerState<InvoiceFormScreen> createState() => _InvoiceFormScreenState();
}

class _InvoiceFormScreenState extends ConsumerState<InvoiceFormScreen> {
  final _form = GlobalKey<FormState>();

  /// One idempotency key per form: retries after a dropped response can't
  /// create a duplicate invoice.
  final _clientSaleId = const Uuid().v4();
  final _number = TextEditingController();
  final _discount = TextEditingController();
  final _charges = TextEditingController();
  final _received = TextEditingController();
  final _notes = TextEditingController();
  final _lines = <InvoiceLine>[];

  Party? _party;
  DateTime _date = DateTime.now();
  DateTime? _due;
  String _mode = 'cash';
  String? _bankId;
  bool _showExtras = false;
  bool _receivedEdited = false;
  bool _busy = false;
  String? _error;
  String? _partyError;

  @override
  void initState() {
    super.initState();
    _loadNumber();
    if (widget.partyId != null) _loadParty(widget.partyId!);
  }

  @override
  void dispose() {
    for (final c in [_number, _discount, _charges, _received, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadNumber() async {
    try {
      final n = await ref.read(invoicesRepositoryProvider).nextNumber();
      if (mounted && _number.text.isEmpty) _number.text = n;
    } catch (_) {
      // The server assigns a number when blank; nothing to do.
    }
  }

  Future<void> _loadParty(String id) async {
    try {
      final p = await ref.read(partiesRepositoryProvider).get(id);
      if (mounted) setState(() => _party = p);
    } catch (_) {}
  }

  InvoiceTotals get _totals => InvoiceTotals.compute(
        _lines,
        invoiceDiscount: NumberField.parse(_discount),
        additionalCharges: NumberField.parse(_charges),
      );

  /// Keeps "received" equal to the total until the user types their own.
  void _syncReceived() {
    if (!_receivedEdited && _mode != 'unpaid') {
      _received.text = NumberField.text(_totals.total);
    }
  }

  Future<void> _addProduct() async {
    final p = await pickProduct(context);
    if (p == null || !mounted) return;
    setState(() {
      final existing = _lines.where((l) => l.productId == p.id).firstOrNull;
      if (existing != null) {
        existing.quantity += 1;
      } else {
        _lines.add(_lineFor(p));
      }
      _syncReceived();
    });
  }

  InvoiceLine _lineFor(Product p) => InvoiceLine(
        productId: p.id,
        description: p.name,
        unitPrice: p.salePrice,
        unit: p.unit,
        hsnCode: p.hsnCode,
        taxRate: p.taxRate,
        stockQty: p.isService ? null : p.stockQty,
      );

  Future<void> _addCustom() async {
    final line = InvoiceLine(description: '');
    final ok = await _editLine(line, isNew: true);
    if (ok == true) setState(() => _lines.add(line));
  }

  Future<bool?> _editLine(InvoiceLine line, {bool isNew = false}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _LineEditor(line: line, isNew: isNew),
    );
    if (result == true) setState(_syncReceived);
    return result;
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
    final totals = _totals;
    if (totals.total < 0) {
      setState(() => _error = 'The discount is larger than the invoice amount.');
      return;
    }
    final draft = InvoiceDraft(
      partyId: _party!.id,
      number: _number.text,
      date: _date,
      dueDate: _due,
      lines: _lines,
      invoiceDiscount: NumberField.parse(_discount),
      additionalCharges: NumberField.parse(_charges),
      amountReceived: _mode == 'unpaid' ? 0 : NumberField.parse(_received),
      paymentMode: _mode,
      bankAccountId: _mode == 'cash' ? null : _bankId,
      notes: _notes.text,
    );
    setState(() => _busy = true);
    try {
      final inv = await ref.read(invoicesRepositoryProvider).create(draft, clientSaleId: _clientSaleId);
      ref.read(dataRevisionProvider.notifier).bump();
      if (!mounted) return;
      showSnack(context, 'Invoice ${inv.number} saved');
      context.pushReplacement('/invoices/${inv.id}');
    } catch (e) {
      setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totals = _totals;
    final banks = ref.watch(bankAccountsProvider).asData?.value ?? const <BankAccount>[];
    if (_bankId == null && banks.isNotEmpty) {
      _bankId = (banks.where((b) => b.isPrimary).firstOrNull ?? banks.first).id;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('New invoice')),
      bottomNavigationBar: SaveBar(
        label: 'Save invoice',
        busy: _busy,
        onPressed: _save,
        leading: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total', style: context.text.labelSmall),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(money(totals.total), style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
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
                  FormSection(title: 'Customer', children: [
                    PickerField(
                      label: 'Bill to',
                      icon: Icons.person_search_rounded,
                      value: _party?.name,
                      subtitle: _party == null
                          ? null
                          : [
                              if (_party!.phone.isNotEmpty) _party!.phone,
                              if (_party!.toCollect) 'Owes ${money(_party!.balance)}',
                            ].join(' · '),
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
                  ]),
                  FormSection(title: 'Invoice details', children: [
                    TextFormField(
                      controller: _number,
                      decoration: const InputDecoration(labelText: 'Invoice number', helperText: 'Auto-filled; you can change it'),
                    ),
                    FieldRow(children: [
                      DateField(label: 'Date', value: _date, onChanged: (d) => setState(() => _date = d ?? _date)),
                      DateField(
                        label: 'Due date',
                        value: _due,
                        clearable: true,
                        firstDate: _date,
                        onChanged: (d) => setState(() => _due = d),
                      ),
                    ]),
                  ]),
                  FormSection(
                    title: 'Items',
                    trailing: _lines.isEmpty ? null : Text('${_lines.length}', style: context.text.labelLarge),
                    children: [
                      if (_lines.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
                          child: Text('No items yet. Add products from your catalogue.', style: context.text.bodySmall),
                        ),
                      for (final (i, l) in _lines.indexed)
                        Dismissible(
                          key: ObjectKey(l),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: Spacing.lg),
                            decoration: BoxDecoration(
                              color: StatusColors.danger.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(Radii.control),
                            ),
                            child: const Icon(Icons.delete_outline, color: StatusColors.danger),
                          ),
                          onDismissed: (_) => setState(() {
                            _lines.removeAt(i);
                            _syncReceived();
                          }),
                          child: _LineTile(
                            line: l,
                            onTap: () => _editLine(l),
                            onQty: (q) => setState(() {
                              l.quantity = q;
                              _syncReceived();
                            }),
                          ),
                        ),
                      Row(children: [
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: _addProduct,
                            icon: const Icon(Icons.add_shopping_cart_rounded),
                            label: const Text('Add item'),
                          ),
                        ),
                        const SizedBox(width: Spacing.sm),
                        OutlinedButton(onPressed: _addCustom, child: const Text('Custom line')),
                      ]),
                    ],
                  ),
                  FormSection(
                    title: 'Summary',
                    children: [
                      KeyValueRow('Subtotal', money(totals.subTotal)),
                      if (totals.lineDiscounts > 0) KeyValueRow('Item discounts', '− ${money(totals.lineDiscounts)}'),
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
                        FieldRow(children: [
                          NumberField(
                            controller: _discount,
                            label: 'Invoice discount',
                            validator: (v) => Validators.number(v, field: 'Discount'),
                            onChanged: (_) => setState(_syncReceived),
                          ),
                          NumberField(
                            controller: _charges,
                            label: 'Additional charges',
                            helper: 'Freight, packing…',
                            validator: (v) => Validators.number(v, field: 'Charges'),
                            onChanged: (_) => setState(_syncReceived),
                          ),
                        ]),
                      if (totals.roundOff.abs() >= 0.005) KeyValueRow('Round off', money(totals.roundOff)),
                      const Divider(height: Spacing.lg),
                      KeyValueRow('Total', money(totals.total), bold: true),
                    ],
                  ),
                  FormSection(title: 'Payment received', children: [
                    Wrap(
                      spacing: Spacing.sm,
                      runSpacing: Spacing.sm,
                      children: [
                        ChoiceChip(
                          label: const Text('Unpaid'),
                          selected: _mode == 'unpaid',
                          onSelected: (_) => setState(() {
                            _mode = 'unpaid';
                            _received.clear();
                          }),
                        ),
                        for (final m in PaymentMode.receipt)
                          ChoiceChip(
                            label: Text(m.label),
                            selected: _mode == m.value,
                            onSelected: (_) => setState(() {
                              _mode = m.value;
                              _syncReceived();
                            }),
                          ),
                      ],
                    ),
                    if (_mode != 'unpaid') ...[
                      NumberField(
                        controller: _received,
                        label: 'Amount received',
                        validator: (v) {
                          final err = Validators.number(v, field: 'Amount');
                          if (err != null) return err;
                          if ((double.tryParse(v ?? '') ?? 0) > totals.total + 0.01) return 'More than the invoice total';
                          return null;
                        },
                        onChanged: (_) => setState(() => _receivedEdited = true),
                      ),
                      Row(children: [
                        Expanded(
                          child: Text.rich(
                            TextSpan(children: [
                              TextSpan(text: 'Balance due: ', style: context.text.bodySmall),
                              TextSpan(
                                text: money((totals.total - NumberField.parse(_received)).clamp(0, double.infinity)),
                                style: context.text.labelLarge?.copyWith(color: StatusColors.danger),
                              ),
                            ]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() {
                            _receivedEdited = false;
                            _syncReceived();
                          }),
                          child: const Text('Full amount'),
                        ),
                      ]),
                      if (_mode != 'cash' && banks.isNotEmpty)
                        DropdownButtonFormField<String>(
                          initialValue: _bankId,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Deposit to', prefixIcon: Icon(Icons.account_balance_outlined)),
                          items: [for (final b in banks) DropdownMenuItem(value: b.id, child: Text(b.label))],
                          onChanged: (v) => setState(() => _bankId = v),
                        ),
                    ],
                  ]),
                  FormSection(title: 'Notes', children: [
                    TextFormField(
                      controller: _notes,
                      maxLines: 3,
                      minLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(hintText: 'Printed on the invoice'),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LineTile extends StatelessWidget {
  const _LineTile({required this.line, required this.onTap, required this.onQty});
  final InvoiceLine line;
  final VoidCallback onTap;
  final ValueChanged<double> onQty;

  @override
  Widget build(BuildContext context) {
    final l = line;
    final short = l.stockQty != null && l.quantity > l.stockQty!;
    return Card(
      margin: const EdgeInsets.only(bottom: Spacing.sm),
      color: context.colors.surfaceContainerLow,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.md, Spacing.sm, Spacing.xs, Spacing.sm),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.description, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                    Text(
                      [
                        '${money(l.unitPrice)}${l.unit.isEmpty ? '' : ' / ${l.unit}'}',
                        if (l.discountPct > 0) '${qty(l.discountPct)}% off',
                      ].join(' · '),
                      style: context.text.bodySmall,
                    ),
                    if (short)
                      Text('Only ${qty(l.stockQty)} in stock',
                          style: context.text.labelSmall?.copyWith(color: StatusColors.warning)),
                    const SizedBox(height: 2),
                    Text(money(l.net), style: context.text.titleSmall),
                  ],
                ),
              ),
              _Stepper(value: l.quantity, onChanged: onQty),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.value, required this.onChanged});
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Decrease',
          onPressed: value > 1 ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove_circle_outline_rounded),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 28),
          child: Text(qty(value), textAlign: TextAlign.center, style: context.text.titleSmall),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Increase',
          onPressed: () => onChanged(value + 1),
          icon: const Icon(Icons.add_circle_outline_rounded),
        ),
      ],
    );
  }
}

/// Bottom sheet to edit one line. Pops true when applied.
class _LineEditor extends StatefulWidget {
  const _LineEditor({required this.line, required this.isNew});
  final InvoiceLine line;
  final bool isNew;

  @override
  State<_LineEditor> createState() => _LineEditorState();
}

class _LineEditorState extends State<_LineEditor> {
  final _form = GlobalKey<FormState>();
  late final _desc = TextEditingController(text: widget.line.description);
  late final _qty = TextEditingController(text: NumberField.text(widget.line.quantity));
  late final _price = TextEditingController(text: NumberField.text(widget.line.unitPrice));
  late final _disc = TextEditingController(text: NumberField.text(widget.line.discountPct));

  @override
  void dispose() {
    for (final c in [_desc, _qty, _price, _disc]) {
      c.dispose();
    }
    super.dispose();
  }

  void _apply() {
    if (!_form.currentState!.validate()) return;
    widget.line
      ..description = _desc.text.trim()
      ..quantity = NumberField.parse(_qty)
      ..unitPrice = NumberField.parse(_price)
      ..discountPct = NumberField.parse(_disc);
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final preview = InvoiceLine(
      description: '',
      quantity: NumberField.parse(_qty),
      unitPrice: NumberField.parse(_price),
      discountPct: NumberField.parse(_disc),
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(Spacing.xl, 0, Spacing.xl, MediaQuery.viewInsetsOf(context).bottom + Spacing.xl),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.isNew ? 'Custom line' : 'Edit item', style: context.text.titleMedium),
            const SizedBox(height: Spacing.lg),
            TextFormField(
              controller: _desc,
              autofocus: widget.isNew,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Description'),
              validator: (v) => Validators.required(v, 'Description'),
            ),
            const SizedBox(height: Spacing.md),
            FieldRow(breakpoint: 300, children: [
              NumberField(
                controller: _qty,
                label: 'Quantity',
                money: false,
                suffix: widget.line.unit.isEmpty ? null : widget.line.unit,
                onChanged: (_) => setState(() {}),
                validator: (v) => Validators.number(v, required: true, allowZero: false, field: 'Quantity'),
              ),
              NumberField(
                controller: _price,
                label: 'Price',
                onChanged: (_) => setState(() {}),
                validator: (v) => Validators.number(v, required: true, field: 'Price'),
              ),
            ]),
            const SizedBox(height: Spacing.md),
            NumberField(
              controller: _disc,
              label: 'Discount',
              money: false,
              suffix: '%',
              onChanged: (_) => setState(() {}),
              validator: (v) {
                final e = Validators.number(v, field: 'Discount');
                if (e != null) return e;
                return (double.tryParse(v ?? '') ?? 0) > 100 ? 'Can\'t exceed 100%' : null;
              },
            ),
            const SizedBox(height: Spacing.lg),
            KeyValueRow('Line total', money(preview.net), bold: true),
            const SizedBox(height: Spacing.md),
            FilledButton(onPressed: _apply, child: Text(widget.isNew ? 'Add line' : 'Apply')),
          ],
        ),
      ),
    );
  }
}
