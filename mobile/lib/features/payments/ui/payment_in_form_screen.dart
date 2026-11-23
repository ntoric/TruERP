import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/revision.dart';
import '../../../core/models/invoice.dart';
import '../../../core/models/party.dart';
import '../../../core/models/payment.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/form_widgets.dart';
import '../../../shared/widgets/pickers.dart';
import '../../invoices/data/invoices_repository.dart';
import '../../parties/data/parties_repository.dart';
import '../data/payments_repository.dart';

/// Receive money from a customer, optionally against one invoice.
class PaymentInFormScreen extends ConsumerStatefulWidget {
  const PaymentInFormScreen({super.key, this.partyId, this.invoiceId});
  final String? partyId;
  final String? invoiceId;

  @override
  ConsumerState<PaymentInFormScreen> createState() => _PaymentInFormScreenState();
}

class _PaymentInFormScreenState extends ConsumerState<PaymentInFormScreen> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _discount = TextEditingController();
  final _number = TextEditingController();
  final _reference = TextEditingController();
  final _notes = TextEditingController();
  Party? _party;
  Invoice? _invoice;
  DateTime _date = DateTime.now();
  String _mode = 'cash';
  String? _bankId;
  bool _busy = false;
  bool _loading = false;
  String? _error;
  String? _partyError;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  @override
  void dispose() {
    for (final c in [_amount, _discount, _number, _reference, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _prefill() async {
    setState(() => _loading = true);
    try {
      final payments = ref.read(paymentsRepositoryProvider);
      final results = await Future.wait<Object?>([
        payments.nextNumber().catchError((_) => ''),
        if (widget.partyId != null) ref.read(partiesRepositoryProvider).get(widget.partyId!),
        if (widget.invoiceId != null) ref.read(invoicesRepositoryProvider).get(widget.invoiceId!),
      ]);
      if (!mounted) return;
      setState(() {
        _number.text = results[0] as String;
        for (final r in results.skip(1)) {
          if (r is Party) _party = r;
          if (r is Invoice) {
            _invoice = r;
            _party ??= r.party;
            _amount.text = NumberField.text(r.balanceDue);
          }
        }
        if (_invoice == null && _party != null && _party!.toCollect) {
          _amount.text = NumberField.text(_party!.balance);
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      _error = null;
      _partyError = _party == null ? 'Choose a customer' : null;
    });
    if (!_form.currentState!.validate() || _party == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(paymentsRepositoryProvider).create(PaymentInDraft(
            partyId: _party!.id,
            invoiceId: _invoice?.id,
            amount: NumberField.parse(_amount),
            discount: NumberField.parse(_discount),
            date: _date,
            mode: _mode,
            bankAccountId: _bankId,
            number: _number.text,
            reference: _reference.text,
            notes: _notes.text,
          ));
      ref.read(dataRevisionProvider.notifier).bump();
      if (!mounted) return;
      showSnack(context, '${money(NumberField.parse(_amount))} received from ${_party!.name}');
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
      appBar: AppBar(title: const Text('Receive payment')),
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
                  FormSection(title: 'From', children: [
                    PickerField(
                      label: 'Customer',
                      icon: Icons.person_search_rounded,
                      value: _party?.name,
                      subtitle: _party == null
                          ? null
                          : _party!.toCollect
                              ? 'Owes ${money(_party!.balance)}'
                              : 'No outstanding balance',
                      errorText: _partyError,
                      onTap: _invoice != null
                          ? () {}
                          : () async {
                              final p = await pickParty(context, type: 'customer');
                              if (p != null) {
                                setState(() {
                                  _party = p;
                                  _partyError = null;
                                  if (p.toCollect) _amount.text = NumberField.text(p.balance);
                                });
                              }
                            },
                    ),
                    if (_invoice != null)
                      Container(
                        padding: const EdgeInsets.all(Spacing.md),
                        decoration: BoxDecoration(
                          color: context.colors.primaryContainer.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(Radii.control),
                        ),
                        child: Row(children: [
                          const Icon(Icons.receipt_long_rounded),
                          const SizedBox(width: Spacing.sm),
                          Expanded(
                            child: Text('Against ${_invoice!.number} · due ${money(_invoice!.balanceDue)}'),
                          ),
                        ]),
                      ),
                  ]),
                  FormSection(title: 'Amount', children: [
                    NumberField(
                      controller: _amount,
                      label: 'Amount received *',
                      autofocus: widget.partyId != null,
                      validator: (v) {
                        final e = Validators.number(v, required: true, allowZero: false, field: 'Amount');
                        if (e != null) return e;
                        if (_invoice != null && (double.tryParse(v!) ?? 0) > _invoice!.balanceDue + 0.01) {
                          return 'More than the ${money(_invoice!.balanceDue)} due on this invoice';
                        }
                        return null;
                      },
                    ),
                    FieldRow(children: [
                      DateField(label: 'Date', value: _date, onChanged: (d) => setState(() => _date = d ?? _date)),
                      NumberField(
                        controller: _discount,
                        label: 'Discount allowed',
                        validator: (v) => Validators.number(v, field: 'Discount'),
                      ),
                    ]),
                    Wrap(
                      spacing: Spacing.sm,
                      runSpacing: Spacing.sm,
                      children: [
                        for (final m in PaymentMode.receipt)
                          ChoiceChip(
                            label: Text(m.label),
                            selected: _mode == m.value,
                            onSelected: (_) => setState(() => _mode = m.value),
                          ),
                      ],
                    ),
                    if (_mode != 'cash' && banks.isNotEmpty)
                      DropdownButtonFormField<String>(
                        initialValue: _bankId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Deposit to', prefixIcon: Icon(Icons.account_balance_outlined)),
                        items: [for (final b in banks) DropdownMenuItem(value: b.id, child: Text(b.label))],
                        onChanged: (v) => setState(() => _bankId = v),
                      ),
                  ]),
                  FormSection(title: 'More', children: [
                    FieldRow(children: [
                      TextFormField(controller: _number, decoration: const InputDecoration(labelText: 'Receipt number')),
                      TextFormField(
                        controller: _reference,
                        decoration: const InputDecoration(labelText: 'Reference', hintText: 'UTR / cheque no.'),
                      ),
                    ]),
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
