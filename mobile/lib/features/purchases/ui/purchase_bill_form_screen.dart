import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/revision.dart';
import '../../../core/models/line_item.dart';
import '../../../core/models/party.dart';
import '../../../core/models/payment.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/form_widgets.dart';
import '../../../shared/widgets/line_items.dart';
import '../../../shared/widgets/pickers.dart';
import '../../parties/data/parties_repository.dart';
import '../../payments/data/payments_repository.dart';
import '../data/purchase_math.dart';
import '../data/purchases_repository.dart';

class PurchaseBillFormScreen extends ConsumerStatefulWidget {
  const PurchaseBillFormScreen({super.key, this.partyId});
  final String? partyId;

  @override
  ConsumerState<PurchaseBillFormScreen> createState() => _PurchaseBillFormScreenState();
}

class _PurchaseBillFormScreenState extends ConsumerState<PurchaseBillFormScreen> {
  final _form = GlobalKey<FormState>();

  /// One idempotency key per form so a retry can't save the bill twice.
  final _clientBillId = PurchasesRepository.newClientId();
  final _number = TextEditingController();
  final _discount = TextEditingController();
  final _charges = TextEditingController();
  final _paid = TextEditingController();
  final _notes = TextEditingController();
  final _lines = <LineItem>[];

  Party? _vendor;
  DateTime _date = DateTime.now();
  DateTime? _due;
  bool _taxExempt = false;
  bool _roundOff = true;
  String _mode = 'unpaid';
  String? _bankId;
  bool _paidEdited = false;
  bool _showExtras = false;
  bool _busy = false;
  String? _error;
  String? _vendorError;

  @override
  void initState() {
    super.initState();
    if (widget.partyId != null) {
      ref.read(partiesRepositoryProvider).get(widget.partyId!).then((p) {
        if (mounted) setState(() => _vendor = p);
      }).catchError((_) {});
    }
  }

  @override
  void dispose() {
    for (final c in [_number, _discount, _charges, _paid, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  PurchaseTotals get _totals => PurchaseTotals.compute(
        _lines,
        billDiscount: NumberField.parse(_discount),
        charges: NumberField.parse(_charges),
        taxExempt: _taxExempt,
        roundOff: _roundOff,
      );

  void _syncPaid() {
    if (!_paidEdited && _mode != 'unpaid') _paid.text = NumberField.text(_totals.total);
  }

  Future<void> _addProduct() async {
    final p = await pickProduct(context);
    if (p == null || !mounted) return;
    setState(() {
      final existing = _lines.where((l) => l.productId == p.id).firstOrNull;
      if (existing != null) {
        existing.quantity += 1;
      } else {
        _lines.add(LineItem(
          productId: p.id,
          description: p.name,
          unitPrice: p.purchasePrice,
          unit: p.unit,
          hsnCode: p.hsnCode,
          taxRate: p.taxRate,
          itemCode: p.itemCode,
          mrp: p.mrp,
          salePrice: p.salePrice,
        ));
      }
      _syncPaid();
    });
  }

  Future<void> _addCustom() async {
    final line = LineItem(description: '');
    final ok = await showLineEditor(context, line, isNew: true, showTax: true, priceLabel: 'Purchase price');
    if (ok == true) {
      setState(() {
        _lines.add(line);
        _syncPaid();
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _error = null;
      _vendorError = _vendor == null ? 'Choose a vendor' : null;
    });
    if (!_form.currentState!.validate() || _vendor == null) return;
    if (_lines.isEmpty) {
      setState(() => _error = 'Add at least one item.');
      return;
    }
    if (_totals.total < 0) {
      setState(() => _error = 'The discount is larger than the bill amount.');
      return;
    }
    final draft = PurchaseBillDraft(
      partyId: _vendor!.id,
      number: _number.text,
      date: _date,
      dueDate: _due,
      lines: _lines,
      billDiscount: NumberField.parse(_discount),
      charges: NumberField.parse(_charges),
      taxExempt: _taxExempt,
      roundOff: _roundOff,
      amountPaid: _mode == 'unpaid' ? 0 : NumberField.parse(_paid),
      paymentMode: _mode,
      bankAccountId: _bankId,
      notes: _notes.text,
    );
    setState(() => _busy = true);
    try {
      final bill = await ref.read(purchasesRepositoryProvider).createBill(draft, clientBillId: _clientBillId);
      ref.read(dataRevisionProvider.notifier).bump();
      if (!mounted) return;
      showSnack(context, 'Purchase ${bill.number} saved');
      context.pushReplacement('/purchases/${bill.id}');
    } catch (e) {
      setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _totals;
    final banks = ref.watch(bankAccountsProvider).asData?.value ?? const <BankAccount>[];
    if (_bankId == null && banks.isNotEmpty) {
      _bankId = (banks.where((b) => b.isPrimary).firstOrNull ?? banks.first).id;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('New purchase')),
      bottomNavigationBar: SaveBar(
        label: 'Save purchase',
        busy: _busy,
        onPressed: _save,
        leading: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total', style: context.text.labelSmall),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(money(t.total), style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
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
                  FormSection(title: 'Vendor', children: [
                    PickerField(
                      label: 'Purchased from',
                      icon: Icons.storefront_rounded,
                      value: _vendor?.name,
                      subtitle: _vendor == null || !_vendor!.toPay ? null : 'You owe ${money(_vendor!.balance.abs())}',
                      errorText: _vendorError,
                      onTap: () async {
                        final p = await pickParty(context, type: 'vendor');
                        if (p != null) {
                          setState(() {
                            _vendor = p;
                            _vendorError = null;
                          });
                        }
                      },
                    ),
                  ]),
                  FormSection(title: 'Bill details', children: [
                    TextFormField(
                      controller: _number,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Vendor bill number *',
                        helperText: 'As printed on the vendor\'s invoice',
                      ),
                      validator: (v) => Validators.required(v, 'Bill number'),
                    ),
                    FieldRow(children: [
                      DateField(label: 'Bill date', value: _date, onChanged: (d) => setState(() => _date = d ?? _date)),
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
                      LineItemsEditor(
                        lines: _lines,
                        showTax: !_taxExempt,
                        priceLabel: 'Purchase price',
                        onChanged: () => setState(_syncPaid),
                        onAddProduct: _addProduct,
                        onAddCustom: _addCustom,
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Tax exempt'),
                        subtitle: const Text('No GST on this bill'),
                        value: _taxExempt,
                        onChanged: (v) => setState(() {
                          _taxExempt = v;
                          _syncPaid();
                        }),
                      ),
                    ],
                  ),
                  FormSection(title: 'Summary', children: [
                    KeyValueRow('Subtotal', money(t.subTotal)),
                    if (t.lineDiscounts > 0) KeyValueRow('Item discounts', '− ${money(t.lineDiscounts)}'),
                    if (t.taxTotal > 0) KeyValueRow('GST', money(t.taxTotal)),
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
                          label: 'Bill discount',
                          validator: (v) => Validators.number(v, field: 'Discount'),
                          onChanged: (_) => setState(_syncPaid),
                        ),
                        NumberField(
                          controller: _charges,
                          label: 'Additional charges',
                          helper: 'Transport, loading…',
                          validator: (v) => Validators.number(v, field: 'Charges'),
                          onChanged: (_) => setState(_syncPaid),
                        ),
                      ]),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Round off to the rupee'),
                      value: _roundOff,
                      onChanged: (v) => setState(() {
                        _roundOff = v;
                        _syncPaid();
                      }),
                    ),
                    if (t.roundOff.abs() >= 0.005) KeyValueRow('Round off', money(t.roundOff)),
                    const Divider(height: Spacing.lg),
                    KeyValueRow('Total', money(t.total), bold: true),
                  ]),
                  FormSection(title: 'Payment made', children: [
                    Wrap(
                      spacing: Spacing.sm,
                      runSpacing: Spacing.sm,
                      children: [
                        ChoiceChip(
                          label: const Text('Unpaid'),
                          selected: _mode == 'unpaid',
                          onSelected: (_) => setState(() {
                            _mode = 'unpaid';
                            _paid.clear();
                          }),
                        ),
                        for (final m in PaymentMode.receipt)
                          ChoiceChip(
                            label: Text(m.label),
                            selected: _mode == m.value,
                            onSelected: (_) => setState(() {
                              _mode = m.value;
                              _syncPaid();
                            }),
                          ),
                      ],
                    ),
                    if (_mode != 'unpaid') ...[
                      NumberField(
                        controller: _paid,
                        label: 'Amount paid',
                        validator: (v) {
                          final e = Validators.number(v, field: 'Amount');
                          if (e != null) return e;
                          return (double.tryParse(v ?? '') ?? 0) > t.total + 0.01 ? 'More than the bill total' : null;
                        },
                        onChanged: (_) => setState(() => _paidEdited = true),
                      ),
                      if (_mode != 'cash' && banks.isNotEmpty)
                        DropdownButtonFormField<String>(
                          initialValue: _bankId,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Paid from', prefixIcon: Icon(Icons.account_balance_outlined)),
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
                      decoration: const InputDecoration(hintText: 'Internal notes'),
                    ),
                  ]),
                  Text('Stock is added as soon as you save. Custom lines are added to your products.',
                      style: context.text.bodySmall, textAlign: TextAlign.center),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
