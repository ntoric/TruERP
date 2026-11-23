import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/revision.dart';
import '../../../core/models/party.dart';
import '../../../core/models/payment.dart';
import '../../../core/models/purchase.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/form_widgets.dart';
import '../../../shared/widgets/pickers.dart';
import '../../parties/data/parties_repository.dart';
import '../../purchases/data/purchases_repository.dart';
import '../data/payments_repository.dart';

/// Pay a vendor, optionally against one purchase bill.
class PaymentOutFormScreen extends ConsumerStatefulWidget {
  const PaymentOutFormScreen({super.key, this.partyId, this.billId});
  final String? partyId;
  final String? billId;

  @override
  ConsumerState<PaymentOutFormScreen> createState() => _State();
}

class _State extends ConsumerState<PaymentOutFormScreen> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _discount = TextEditingController();
  final _reference = TextEditingController();
  final _notes = TextEditingController();
  Party? _vendor;
  PurchaseBill? _bill;
  DateTime _date = DateTime.now();
  String _mode = 'cash';
  String? _bankId;
  bool _busy = false;
  bool _loading = false;
  String? _error;
  String? _vendorError;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  @override
  void dispose() {
    for (final c in [_amount, _discount, _reference, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _prefill() async {
    if (widget.partyId == null && widget.billId == null) return;
    setState(() => _loading = true);
    try {
      if (widget.billId != null) {
        final b = await ref.read(purchasesRepositoryProvider).bill(widget.billId!);
        _bill = b;
        _vendor = b.party;
        _amount.text = NumberField.text(b.balanceDue);
      }
      if (_vendor == null && widget.partyId != null) {
        _vendor = await ref.read(partiesRepositoryProvider).get(widget.partyId!);
        if (_bill == null && _vendor!.toPay) _amount.text = NumberField.text(_vendor!.balance.abs());
      }
    } catch (e) {
      _error = errorMessage(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      _error = null;
      _vendorError = _vendor == null ? 'Choose a vendor' : null;
    });
    if (!_form.currentState!.validate() || _vendor == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(paymentsRepositoryProvider).createOut(PaymentOutDraft(
            partyId: _vendor!.id,
            purchaseBillId: _bill?.id,
            amount: NumberField.parse(_amount),
            discount: NumberField.parse(_discount),
            date: _date,
            mode: _mode,
            bankAccountId: _bankId,
            reference: _reference.text,
            notes: _notes.text,
          ));
      ref.read(dataRevisionProvider.notifier).bump();
      if (!mounted) return;
      showSnack(context, '${money(NumberField.parse(_amount))} paid to ${_vendor!.name}');
      context.pop(true);
    } catch (e) {
      setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final banks = ref.watch(bankAccountsProvider).asData?.value ?? const <BankAccount>[];
    if (_bankId == null && banks.isNotEmpty) {
      _bankId = (banks.where((b) => b.isPrimary).firstOrNull ?? banks.first).id;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Pay vendor')),
      bottomNavigationBar: SaveBar(label: 'Save payment', busy: _busy || _loading, onPressed: _save),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(Spacing.lg),
          children: [
            ContentWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_loading) const LinearProgressIndicator(),
                  if (_error != null) ErrorBanner(_error!),
                  FormSection(title: 'To', children: [
                    PickerField(
                      label: 'Vendor',
                      icon: Icons.storefront_rounded,
                      value: _vendor?.name,
                      subtitle: _vendor == null
                          ? null
                          : _vendor!.toPay
                              ? 'You owe ${money(_vendor!.balance.abs())}'
                              : 'Nothing outstanding',
                      errorText: _vendorError,
                      onTap: _bill != null
                          ? () {}
                          : () async {
                              final p = await pickParty(context, type: 'vendor');
                              if (p != null) {
                                setState(() {
                                  _vendor = p;
                                  _vendorError = null;
                                  if (p.toPay) _amount.text = NumberField.text(p.balance.abs());
                                });
                              }
                            },
                    ),
                    if (_bill != null)
                      Container(
                        padding: const EdgeInsets.all(Spacing.md),
                        decoration: BoxDecoration(
                          color: context.colors.primaryContainer.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(Radii.control),
                        ),
                        child: Row(children: [
                          const Icon(Icons.description_rounded),
                          const SizedBox(width: Spacing.sm),
                          Expanded(child: Text('Against bill ${_bill!.number} · due ${money(_bill!.balanceDue)}')),
                        ]),
                      ),
                  ]),
                  FormSection(title: 'Amount', children: [
                    NumberField(
                      controller: _amount,
                      label: 'Amount paid *',
                      validator: (v) {
                        final e = Validators.number(v, required: true, allowZero: false, field: 'Amount');
                        if (e != null) return e;
                        if (_bill != null && (double.tryParse(v!) ?? 0) > _bill!.balanceDue + 0.01) {
                          return 'More than the ${money(_bill!.balanceDue)} due on this bill';
                        }
                        return null;
                      },
                    ),
                    FieldRow(children: [
                      DateField(label: 'Date', value: _date, onChanged: (d) => setState(() => _date = d ?? _date)),
                      NumberField(
                        controller: _discount,
                        label: 'Discount received',
                        validator: (v) => Validators.number(v, field: 'Discount'),
                      ),
                    ]),
                    Wrap(spacing: Spacing.sm, runSpacing: Spacing.sm, children: [
                      for (final m in PaymentMode.receipt)
                        ChoiceChip(
                          label: Text(m.label),
                          selected: _mode == m.value,
                          onSelected: (_) => setState(() => _mode = m.value),
                        ),
                    ]),
                    if (_mode != 'cash' && banks.isNotEmpty)
                      DropdownButtonFormField<String>(
                        initialValue: _bankId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Paid from', prefixIcon: Icon(Icons.account_balance_outlined)),
                        items: [for (final b in banks) DropdownMenuItem(value: b.id, child: Text(b.label))],
                        onChanged: (v) => setState(() => _bankId = v),
                      ),
                  ]),
                  FormSection(title: 'More', children: [
                    TextFormField(
                      controller: _reference,
                      decoration: const InputDecoration(labelText: 'Reference', hintText: 'UTR / cheque no.'),
                    ),
                    TextFormField(
                      controller: _notes,
                      maxLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(labelText: 'Notes'),
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
