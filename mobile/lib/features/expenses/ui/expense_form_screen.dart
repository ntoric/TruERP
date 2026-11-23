import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/revision.dart';
import '../../../core/models/expense.dart';
import '../../../core/models/payment.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/form_widgets.dart';
import '../../../shared/widgets/line_items.dart';
import '../../payments/data/payments_repository.dart';
import '../data/expenses_repository.dart';

/// Create (no [expenseId]) or edit an expense.
class ExpenseFormScreen extends ConsumerWidget {
  const ExpenseFormScreen({super.key, this.expenseId});
  final String? expenseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (expenseId == null) return const _ExpenseForm();
    return ref.watch(expenseProvider(expenseId!)).when(
          loading: () => Scaffold(appBar: AppBar(title: const Text('Edit expense')), body: const SkeletonList(count: 6)),
          error: (e, _) => Scaffold(
            appBar: AppBar(title: const Text('Edit expense')),
            body: ErrorView(error: e, onRetry: () => ref.invalidate(expenseProvider(expenseId!))),
          ),
          data: (e) => _ExpenseForm(existing: e),
        );
  }
}

/// One editable item row's controllers.
class _ItemRow {
  _ItemRow([ExpenseItem? i])
      : desc = TextEditingController(text: i?.description),
        qtyC = TextEditingController(text: NumberField.text(i?.quantity ?? 1)),
        price = TextEditingController(text: NumberField.text(i?.unitPrice ?? 0));

  final TextEditingController desc;
  final TextEditingController qtyC;
  final TextEditingController price;

  double get amount => NumberField.parse(qtyC) * NumberField.parse(price);

  ExpenseItem toItem() => ExpenseItem(
        description: desc.text.trim(),
        quantity: NumberField.parse(qtyC) <= 0 ? 1 : NumberField.parse(qtyC),
        unitPrice: NumberField.parse(price),
      );

  void dispose() {
    desc.dispose();
    qtyC.dispose();
    price.dispose();
  }
}

class _ExpenseForm extends ConsumerStatefulWidget {
  const _ExpenseForm({this.existing});
  final Expense? existing;

  @override
  ConsumerState<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends ConsumerState<_ExpenseForm> {
  final _form = GlobalKey<FormState>();
  late final Expense? _e = widget.existing;
  late final _description = TextEditingController(text: _e?.description);
  late final _vendor = TextEditingController(text: _e?.vendor);
  late final _billNo = TextEditingController(text: _e?.originalInvoiceNum);
  late final _notes = TextEditingController(text: _e?.notes);
  late final List<_ItemRow> _rows = (_e?.items.isNotEmpty ?? false)
      ? _e!.items.map(_ItemRow.new).toList()
      // Legacy expenses saved without items: start from their amount.
      : [_ItemRow(_e == null ? null : ExpenseItem(description: _e.title, unitPrice: _e.subTotal > 0 ? _e.subTotal : _e.amount))];
  late String? _category = _e?.category;
  late DateTime _date = _e?.date ?? DateTime.now();
  late String _mode = (_e?.paymentMode.isNotEmpty ?? false) ? _e!.paymentMode : 'cash';
  late String? _bankId = _e?.bankAccountId;
  late bool _withGst = _e?.withGst ?? false;
  late double _rate = _e?.taxRate ?? 18;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_description, _vendor, _billNo, _notes]) {
      c.dispose();
    }
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  ExpenseDraft get _draft => ExpenseDraft(
        category: _category ?? '',
        date: _date,
        items: _rows.map((r) => r.toItem()).toList(),
        description: _description.text,
        vendor: _vendor.text,
        originalInvoiceNum: _billNo.text,
        paymentMode: _mode,
        bankAccountId: _bankId,
        withGst: _withGst,
        taxRate: _rate,
        notes: _notes.text,
      );

  Future<void> _save() async {
    setState(() => _error = null);
    if (!_form.currentState!.validate()) return;
    if (_draft.total <= 0) {
      setState(() => _error = 'Enter an amount for at least one item.');
      return;
    }
    setState(() => _busy = true);
    try {
      final repo = ref.read(expensesRepositoryProvider);
      final saved = _e == null ? await repo.create(_draft) : await repo.update(_e.id, _draft);
      ref.read(dataRevisionProvider.notifier).bump();
      if (!mounted) return;
      showSnack(context, _e == null ? 'Expense of ${money(saved.amount)} saved' : 'Changes saved');
      if (_e == null) {
        context.pushReplacement('/expenses/${saved.id}');
      } else {
        context.pop(saved);
      }
    } catch (err) {
      setState(() => _error = errorMessage(err));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _newCategory() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New category'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. Rent'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Add')),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null || name.trim().isEmpty) return;
    try {
      final c = await ref.read(expensesRepositoryProvider).createCategory(name);
      ref.invalidate(expenseCategoriesProvider);
      setState(() => _category = c.name);
    } catch (err) {
      if (mounted) showSnack(context, errorMessage(err), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cats = ref.watch(expenseCategoriesProvider).asData?.value.where((c) => c.isActive).map((c) => c.name).toList() ??
        const <String>[];
    final banks = ref.watch(bankAccountsProvider).asData?.value ?? const <BankAccount>[];
    if (_bankId == null && banks.isNotEmpty) {
      _bankId = (banks.where((b) => b.isPrimary).firstOrNull ?? banks.first).id;
    }
    final d = _draft;

    return Scaffold(
      appBar: AppBar(title: Text(_e == null ? 'New expense' : 'Edit expense')),
      bottomNavigationBar: SaveBar(
        label: _e == null ? 'Save expense' : 'Save changes',
        busy: _busy,
        onPressed: _save,
        leading: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total', style: context.text.labelSmall),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(money(d.total), style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
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
                  FormSection(title: 'Expense', children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _category == null || _category!.isEmpty ? null : _category,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Category *'),
                          items: [
                            for (final c in {...cats, if (_category != null && _category!.isNotEmpty) _category!})
                              DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: (v) => setState(() => _category = v),
                          validator: (v) => (v ?? '').isEmpty ? 'Choose a category' : null,
                        ),
                      ),
                      const SizedBox(width: Spacing.sm),
                      IconButton.filledTonal(
                        tooltip: 'New category',
                        onPressed: _newCategory,
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ]),
                    DateField(label: 'Date', value: _date, onChanged: (v) => setState(() => _date = v ?? _date)),
                    TextFormField(
                      controller: _description,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(labelText: 'Description', hintText: 'What was this for?'),
                    ),
                  ]),
                  FormSection(
                    title: 'Items',
                    trailing: TextButton.icon(
                      onPressed: () => setState(() => _rows.add(_ItemRow())),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add'),
                    ),
                    children: [
                      for (final (i, r) in _rows.indexed)
                        Card(
                          color: context.colors.surfaceContainerLow,
                          child: Padding(
                            padding: const EdgeInsets.all(Spacing.md),
                            child: Column(children: [
                              Row(children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: r.desc,
                                    textCapitalization: TextCapitalization.sentences,
                                    decoration: InputDecoration(labelText: 'Item ${i + 1}'),
                                    validator: (v) => Validators.required(v, 'Item description'),
                                  ),
                                ),
                                if (_rows.length > 1)
                                  IconButton(
                                    tooltip: 'Remove item',
                                    onPressed: () => setState(() => _rows.removeAt(i).dispose()),
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                              ]),
                              const SizedBox(height: Spacing.sm),
                              FieldRow(breakpoint: 280, children: [
                                NumberField(
                                  controller: r.qtyC,
                                  label: 'Qty',
                                  money: false,
                                  onChanged: (_) => setState(() {}),
                                  validator: (v) => Validators.number(v, allowZero: false, field: 'Quantity'),
                                ),
                                NumberField(
                                  controller: r.price,
                                  label: 'Amount',
                                  onChanged: (_) => setState(() {}),
                                  validator: (v) => Validators.number(v, required: true, field: 'Amount'),
                                ),
                              ]),
                            ]),
                          ),
                        ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Includes GST bill'),
                        subtitle: const Text('Add GST on top of the item amounts'),
                        value: _withGst,
                        onChanged: (v) => setState(() => _withGst = v),
                      ),
                      if (_withGst)
                        DropdownButtonFormField<double>(
                          initialValue: _rate,
                          decoration: const InputDecoration(labelText: 'GST rate'),
                          items: [for (final r in {...gstRates.where((r) => r > 0), _rate}) DropdownMenuItem(value: r, child: Text(gstLabel(r)))],
                          onChanged: (v) => setState(() => _rate = v ?? 18),
                        ),
                      KeyValueRow('Subtotal', money(d.subTotal)),
                      if (_withGst) KeyValueRow('GST', money(d.tax)),
                      KeyValueRow('Total', money(d.total), bold: true),
                    ],
                  ),
                  FormSection(title: 'Paid by', children: [
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
                        initialValue: banks.any((b) => b.id == _bankId) ? _bankId : null,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Paid from', prefixIcon: Icon(Icons.account_balance_outlined)),
                        items: [for (final b in banks) DropdownMenuItem(value: b.id, child: Text(b.label))],
                        onChanged: (v) => setState(() => _bankId = v),
                      ),
                  ]),
                  FormSection(title: 'More', children: [
                    FieldRow(children: [
                      TextFormField(
                        controller: _vendor,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'Paid to', hintText: 'Shop or person'),
                      ),
                      TextFormField(controller: _billNo, decoration: const InputDecoration(labelText: 'Bill number')),
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
