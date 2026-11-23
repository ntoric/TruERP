import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/revision.dart';
import '../../../core/models/payment.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/form_widgets.dart';
import '../data/cash_bank_repository.dart';

/// Same choices as the web form.
const _types = [('savings', 'Savings'), ('current', 'Current')];

/// Create (no [accountId]) or edit a bank account.
class BankAccountFormScreen extends ConsumerWidget {
  const BankAccountFormScreen({super.key, this.accountId});
  final String? accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (accountId == null) return const _Form();
    final async = ref.watch(cashBankSummaryProvider);
    return async.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Edit account')),
        body: const SkeletonList(count: 5),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Edit account')),
        body: ErrorView(
          error: e,
          onRetry: () => ref.invalidate(cashBankSummaryProvider),
        ),
      ),
      data: (s) {
        final a = s.accounts.where((a) => a.id == accountId).firstOrNull;
        if (a == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(
              icon: Icons.search_off_rounded,
              title: 'Account not found',
            ),
          );
        }
        return _Form(existing: a);
      },
    );
  }
}

class _Form extends ConsumerStatefulWidget {
  const _Form({this.existing});
  final BankAccount? existing;

  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  final _form = GlobalKey<FormState>();
  late final BankAccount? _e = widget.existing;
  late final _name = TextEditingController(text: _e?.accountName);
  late final _bank = TextEditingController(text: _e?.bankName);
  late final _number = TextEditingController(text: _e?.accountNumber);
  late final _ifsc = TextEditingController(text: _e?.ifscCode);
  late final _opening = TextEditingController();
  late final _notes = TextEditingController(text: _e?.notes);
  late String _type = (_e?.accountType.isNotEmpty ?? false)
      ? _e!.accountType
      : 'savings';
  late bool _active = _e?.isActive ?? true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _bank, _number, _ifsc, _opening, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = ref.read(cashBankRepositoryProvider);
      if (_e == null) {
        await repo.createAccount(
          name: _name.text,
          number: _number.text,
          bank: _bank.text,
          ifsc: _ifsc.text,
          type: _type,
          opening: NumberField.parse(_opening),
          notes: _notes.text,
        );
      } else {
        await repo.updateAccount(
          _e.id,
          name: _name.text,
          number: _number.text,
          bank: _bank.text,
          ifsc: _ifsc.text,
          type: _type,
          isActive: _active,
          notes: _notes.text,
        );
      }
      ref.read(dataRevisionProvider.notifier).bump();
      if (!mounted) return;
      showSnack(context, _e == null ? 'Bank account added' : 'Changes saved');
      context.pop();
    } catch (e) {
      setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_e == null ? 'New bank account' : 'Edit bank account'),
      ),
      bottomNavigationBar: SaveBar(
        label: _e == null ? 'Add account' : 'Save changes',
        busy: _busy,
        onPressed: _save,
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
                    title: 'Account',
                    children: [
                      TextFormField(
                        controller: _name,
                        autofocus: _e == null,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Account name *',
                          hintText: 'e.g. HDFC Current',
                        ),
                        validator: (v) =>
                            Validators.required(v, 'Account name'),
                      ),
                      TextFormField(
                        controller: _bank,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Bank name *',
                        ),
                        validator: (v) => Validators.required(v, 'Bank name'),
                      ),
                      FieldRow(
                        children: [
                          TextFormField(
                            controller: _number,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Account number *',
                            ),
                            validator: (v) =>
                                Validators.required(v, 'Account number'),
                          ),
                          TextFormField(
                            controller: _ifsc,
                            textCapitalization: TextCapitalization.characters,
                            maxLength: 11,
                            decoration: const InputDecoration(
                              labelText: 'IFSC',
                              counterText: '',
                            ),
                            validator: (v) {
                              final s = (v ?? '').trim().toUpperCase();
                              if (s.isEmpty) return null;
                              return RegExp(
                                    r'^[A-Z]{4}0[A-Z0-9]{6}$',
                                  ).hasMatch(s)
                                  ? null
                                  : 'Enter a valid IFSC';
                            },
                          ),
                        ],
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: _type,
                        decoration: const InputDecoration(
                          labelText: 'Account type',
                        ),
                        items: [
                          for (final (v, l) in _types)
                            DropdownMenuItem(value: v, child: Text(l)),
                          // Keep a value set elsewhere selectable.
                          if (_types.every((t) => t.$1 != _type))
                            DropdownMenuItem(value: _type, child: Text(_type)),
                        ],
                        onChanged: (v) =>
                            setState(() => _type = v ?? 'savings'),
                      ),
                      if (_e == null)
                        NumberField(
                          controller: _opening,
                          label: 'Opening balance',
                          helper: 'Current balance in this account today',
                          validator: (v) =>
                              Validators.number(v, field: 'Opening balance'),
                        )
                      else
                        Text(
                          'The opening balance can\'t be changed after the account is created.',
                          style: context.text.bodySmall,
                        ),
                      TextFormField(
                        controller: _notes,
                        maxLines: 2,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(labelText: 'Notes'),
                      ),
                      if (_e != null)
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Active'),
                          subtitle: const Text(
                            'Inactive accounts are hidden from payment forms',
                          ),
                          value: _active,
                          onChanged: (v) => setState(() => _active = v),
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
