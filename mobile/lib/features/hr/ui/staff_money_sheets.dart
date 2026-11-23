import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/revision.dart';
import '../../../core/models/hr.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/form_widgets.dart';
import '../data/hr_repository.dart';
import 'hr_widgets.dart';

/// Frame shared by the HR money sheets: title, error, body, primary button.
class _SheetFrame extends StatelessWidget {
  const _SheetFrame({
    required this.title,
    required this.formKey,
    required this.children,
    required this.action,
    required this.onSubmit,
    this.busy = false,
    this.error,
    this.subtitle,
  });
  final String title;
  final String? subtitle;
  final GlobalKey<FormState> formKey;
  final List<Widget> children;
  final String action;
  final VoidCallback onSubmit;
  final bool busy;
  final String? error;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      Spacing.xl,
      0,
      Spacing.xl,
      MediaQuery.viewInsetsOf(context).bottom + Spacing.xl,
    ),
    child: Form(
      key: formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: context.text.titleMedium),
            if (subtitle != null)
              Text(subtitle!, style: context.text.bodySmall),
            const SizedBox(height: Spacing.lg),
            if (error != null) ErrorBanner(error!),
            for (final (i, c) in children.indexed) ...[
              if (i > 0) const SizedBox(height: Spacing.md),
              c,
            ],
            const SizedBox(height: Spacing.lg),
            FilledButton(
              onPressed: busy ? null : onSubmit,
              child: busy
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Text(action),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _open(BuildContext context, Widget sheet) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => sheet,
    );

/// Runs [action], refreshes data and closes the sheet; returns an error message on failure.
Future<String?> _submit(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function() action,
  String done,
) async {
  try {
    await action();
    ref.read(dataRevisionProvider.notifier).bump();
    if (context.mounted) {
      Navigator.pop(context);
      showSnack(context, done);
    }
    return null;
  } catch (e) {
    return errorMessage(e);
  }
}

// ── Advance ─────────────────────────────────────────────────────────────

Future<void> showAdvanceSheet(BuildContext context, Staff s) =>
    _open(context, _AdvanceSheet(staff: s));

class _AdvanceSheet extends ConsumerStatefulWidget {
  const _AdvanceSheet({required this.staff});
  final Staff staff;

  @override
  ConsumerState<_AdvanceSheet> createState() => _AdvanceState();
}

class _AdvanceState extends ConsumerState<_AdvanceSheet> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _reason = TextEditingController();
  DateTime _date = DateTime.now();
  DateTime? _recoverBy;
  Payout _payout = const Payout();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final err = await _submit(
      context,
      ref,
      () => ref
          .read(hrRepositoryProvider)
          .createAdvance(
            staffId: widget.staff.id,
            amount: NumberField.parse(_amount),
            date: _date,
            reason: _reason.text,
            expectedRecovery: _recoverBy,
            payout: _payout,
          ),
      'Advance of ${money(NumberField.parse(_amount))} given to ${widget.staff.name}',
    );
    if (mounted) {
      setState(() {
        _busy = false;
        _error = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) => _SheetFrame(
    title: 'Give an advance',
    subtitle:
        'Paid now and recovered from ${widget.staff.name}\'s future salary.',
    formKey: _form,
    busy: _busy,
    error: _error,
    action: 'Give advance',
    onSubmit: _save,
    children: [
      NumberField(
        controller: _amount,
        label: 'Amount',
        autofocus: true,
        validator: (v) => Validators.number(
          v,
          required: true,
          allowZero: false,
          field: 'Amount',
        ),
      ),
      TextFormField(
        controller: _reason,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(labelText: 'Reason'),
      ),
      FieldRow(
        children: [
          DateField(
            label: 'Date',
            value: _date,
            onChanged: (d) => setState(() => _date = d ?? _date),
          ),
          DateField(
            label: 'Recover by',
            value: _recoverBy,
            clearable: true,
            firstDate: _date,
            onChanged: (d) => setState(() => _recoverBy = d),
          ),
        ],
      ),
      PayoutPicker(onChanged: (p) => _payout = p),
    ],
  );
}

// ── Extra amount ────────────────────────────────────────────────────────

Future<void> showExtraSheet(BuildContext context, Staff s) =>
    _open(context, _ExtraSheet(staff: s));

class _ExtraSheet extends ConsumerStatefulWidget {
  const _ExtraSheet({required this.staff});
  final Staff staff;

  @override
  ConsumerState<_ExtraSheet> createState() => _ExtraState();
}

class _ExtraState extends ConsumerState<_ExtraSheet> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _reason = TextEditingController();
  String _direction = 'add';
  bool _payNow = false;
  DateTime _date = DateTime.now();
  Payout _payout = const Payout();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final err = await _submit(
      context,
      ref,
      () => ref
          .read(hrRepositoryProvider)
          .createExtra(
            staffId: widget.staff.id,
            direction: _direction,
            amount: NumberField.parse(_amount),
            date: _date,
            reason: _reason.text,
            payNow: _payNow,
            payout: _payout,
          ),
      'Extra amount recorded',
    );
    if (mounted) {
      setState(() {
        _busy = false;
        _error = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) => _SheetFrame(
    title: 'Extra amount',
    formKey: _form,
    busy: _busy,
    error: _error,
    action: 'Save',
    onSubmit: _save,
    children: [
      SegmentedButton<String>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: 'add', label: Text('Owed to staff')),
          ButtonSegment(value: 'deduct', label: Text('Extra payout')),
        ],
        selected: {_direction},
        onSelectionChanged: (s) => setState(() => _direction = s.first),
      ),
      Text(
        _direction == 'add'
            ? 'Incentive, reimbursement or bonus. Added to the next salary unless you pay it now.'
            : 'Money handed over beyond salary (like a draw). Recovered from the next salary.',
        style: context.text.bodySmall,
      ),
      NumberField(
        controller: _amount,
        label: 'Amount',
        validator: (v) => Validators.number(
          v,
          required: true,
          allowZero: false,
          field: 'Amount',
        ),
      ),
      TextFormField(
        controller: _reason,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(labelText: 'Reason'),
      ),
      DateField(
        label: 'Date',
        value: _date,
        onChanged: (d) => setState(() => _date = d ?? _date),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(_direction == 'add' ? 'Pay it now' : 'Hand it over now'),
        value: _payNow,
        onChanged: (v) => setState(() => _payNow = v),
      ),
      if (_payNow) PayoutPicker(onChanged: (p) => _payout = p),
    ],
  );
}

// ── Deduction ───────────────────────────────────────────────────────────

Future<void> showDeductionSheet(BuildContext context, Staff s) =>
    _open(context, _DeductionSheet(staff: s));

class _DeductionSheet extends ConsumerStatefulWidget {
  const _DeductionSheet({required this.staff});
  final Staff staff;

  @override
  ConsumerState<_DeductionSheet> createState() => _DeductionState();
}

class _DeductionState extends ConsumerState<_DeductionSheet> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _description = TextEditingController();
  final _installments = TextEditingController(text: '3');
  String _type = StaffDeduction.types.first.$1;
  bool _recurring = false;
  DateTime _date = DateTime.now();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    _installments.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final err = await _submit(
      context,
      ref,
      () => ref
          .read(hrRepositoryProvider)
          .createDeduction(
            staffId: widget.staff.id,
            type: _type,
            amount: NumberField.parse(_amount),
            date: _date,
            description: _description.text,
            recurring: _recurring,
            installments: int.tryParse(_installments.text) ?? 0,
          ),
      'Deduction added',
    );
    if (mounted) {
      setState(() {
        _busy = false;
        _error = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) => _SheetFrame(
    title: 'Add a deduction',
    subtitle: 'Taken off ${widget.staff.name}\'s next salary.',
    formKey: _form,
    busy: _busy,
    error: _error,
    action: 'Add deduction',
    onSubmit: _save,
    children: [
      Wrap(
        spacing: Spacing.sm,
        runSpacing: Spacing.sm,
        children: [
          for (final (v, l) in StaffDeduction.types)
            ChoiceChip(
              label: Text(l),
              selected: _type == v,
              onSelected: (_) => setState(() => _type = v),
            ),
        ],
      ),
      NumberField(
        controller: _amount,
        label: _recurring ? 'Amount per instalment' : 'Amount',
        validator: (v) => Validators.number(
          v,
          required: true,
          allowZero: false,
          field: 'Amount',
        ),
      ),
      TextFormField(
        controller: _description,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(labelText: 'Description'),
      ),
      DateField(
        label: 'Date',
        value: _date,
        onChanged: (d) => setState(() => _date = d ?? _date),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Monthly instalments'),
        value: _recurring,
        onChanged: (v) => setState(() => _recurring = v),
      ),
      if (_recurring)
        NumberField(
          controller: _installments,
          label: 'Number of instalments',
          money: false,
          validator: (v) =>
              (int.tryParse(v ?? '') ?? 0) < 1 ? 'At least 1' : null,
        ),
    ],
  );
}

// ── Recover advance ─────────────────────────────────────────────────────

Future<void> showRecoverSheet(BuildContext context, StaffAdvance a) =>
    _open(context, _RecoverSheet(advance: a));

class _RecoverSheet extends ConsumerStatefulWidget {
  const _RecoverSheet({required this.advance});
  final StaffAdvance advance;

  @override
  ConsumerState<_RecoverSheet> createState() => _RecoverState();
}

class _RecoverState extends ConsumerState<_RecoverSheet> {
  final _form = GlobalKey<FormState>();
  late final _amount = TextEditingController(
    text: NumberField.text(widget.advance.pending),
  );
  final _notes = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final err = await _submit(
      context,
      ref,
      () => ref
          .read(hrRepositoryProvider)
          .recoverAdvance(
            widget.advance.id,
            NumberField.parse(_amount),
            notes: _notes.text,
          ),
      'Advance recovery recorded',
    );
    if (mounted) {
      setState(() {
        _busy = false;
        _error = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) => _SheetFrame(
    title: 'Recover advance',
    subtitle:
        '${money(widget.advance.pending)} still to recover. Use this when the money is returned directly, not through salary.',
    formKey: _form,
    busy: _busy,
    error: _error,
    action: 'Record recovery',
    onSubmit: _save,
    children: [
      NumberField(
        controller: _amount,
        label: 'Amount recovered',
        validator: (v) {
          final e = Validators.number(
            v,
            required: true,
            allowZero: false,
            field: 'Amount',
          );
          if (e != null) return e;
          return (double.tryParse(v!) ?? 0) > widget.advance.pending + 0.01
              ? 'More than the pending amount'
              : null;
        },
      ),
      TextFormField(
        controller: _notes,
        decoration: const InputDecoration(labelText: 'Notes'),
      ),
    ],
  );
}

// ── Pay out an extra now ────────────────────────────────────────────────

Future<void> showRedeemSheet(BuildContext context, StaffExtra x) =>
    _open(context, _RedeemSheet(extra: x));

class _RedeemSheet extends ConsumerStatefulWidget {
  const _RedeemSheet({required this.extra});
  final StaffExtra extra;

  @override
  ConsumerState<_RedeemSheet> createState() => _RedeemState();
}

class _RedeemState extends ConsumerState<_RedeemSheet> {
  final _form = GlobalKey<FormState>();
  DateTime _date = DateTime.now();
  Payout _payout = const Payout();
  bool _busy = false;
  String? _error;

  Future<void> _save() async {
    setState(() => _busy = true);
    final err = await _submit(
      context,
      ref,
      () => ref
          .read(hrRepositoryProvider)
          .redeemExtra(widget.extra.id, date: _date, payout: _payout),
      '${money(widget.extra.amount)} paid out',
    );
    if (mounted) {
      setState(() {
        _busy = false;
        _error = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) => _SheetFrame(
    title: 'Pay ${money(widget.extra.amount)} now',
    subtitle:
        'Settles this extra outright instead of adding it to the next salary.',
    formKey: _form,
    busy: _busy,
    error: _error,
    action: 'Pay now',
    onSubmit: _save,
    children: [
      DateField(
        label: 'Date',
        value: _date,
        onChanged: (d) => setState(() => _date = d ?? _date),
      ),
      PayoutPicker(onChanged: (p) => _payout = p),
    ],
  );
}
