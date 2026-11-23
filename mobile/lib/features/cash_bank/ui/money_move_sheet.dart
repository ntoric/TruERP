import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/revision.dart';
import '../../../core/models/payment.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/form_widgets.dart';
import '../data/cash_bank_repository.dart';

const _cash = '__cash__';

/// Add money, reduce money or transfer between bank accounts.
/// [accountId] preselects the account (`cash` for cash in hand).
Future<void> showMoneyMoveSheet(
  BuildContext context, {
  required MoneyMove kind,
  required List<BankAccount> accounts,
  String? accountId,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MoneyMoveSheet(kind: kind, accounts: accounts.where((a) => a.isActive).toList(), accountId: accountId),
    );

class _MoneyMoveSheet extends ConsumerStatefulWidget {
  const _MoneyMoveSheet({required this.kind, required this.accounts, this.accountId});
  final MoneyMove kind;
  final List<BankAccount> accounts;
  final String? accountId;

  @override
  ConsumerState<_MoneyMoveSheet> createState() => _State();
}

class _State extends ConsumerState<_MoneyMoveSheet> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _description = TextEditingController();
  final _reference = TextEditingController();
  late MoneyMove _kind = widget.kind;
  late String _account = widget.accountId == null || widget.accountId == 'cash' ? _cash : widget.accountId!;
  late String? _from = widget.accountId != null && widget.accountId != 'cash'
      ? widget.accountId
      : (widget.accounts.isEmpty ? null : widget.accounts.first.id);
  late String? _to = widget.accounts.where((a) => a.id != _from).firstOrNull?.id;
  DateTime _date = DateTime.now();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    _reference.dispose();
    super.dispose();
  }

  BankAccount? _byId(String? id) => widget.accounts.where((a) => a.id == id).firstOrNull;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(cashBankRepositoryProvider).move(
            _kind,
            amount: NumberField.parse(_amount),
            date: _date,
            accountId: _account == _cash ? null : _account,
            fromAccountId: _from,
            toAccountId: _to,
            description: _description.text,
            reference: _reference.text,
          );
      ref.read(dataRevisionProvider.notifier).bump();
      if (!mounted) return;
      Navigator.pop(context);
      showSnack(context, switch (_kind) {
        MoneyMove.add => '${money(NumberField.parse(_amount))} added',
        MoneyMove.reduce => '${money(NumberField.parse(_amount))} reduced',
        MoneyMove.transfer => '${money(NumberField.parse(_amount))} transferred',
      });
    } catch (e) {
      setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canTransfer = widget.accounts.length >= 2;
    final from = _byId(_from);

    return Padding(
      padding: EdgeInsets.fromLTRB(Spacing.xl, 0, Spacing.xl, MediaQuery.viewInsetsOf(context).bottom + Spacing.xl),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<MoneyMove>(
                showSelectedIcon: false,
                segments: [
                  const ButtonSegment(value: MoneyMove.add, icon: Icon(Icons.add_rounded), label: Text('Add')),
                  const ButtonSegment(value: MoneyMove.reduce, icon: Icon(Icons.remove_rounded), label: Text('Reduce')),
                  ButtonSegment(
                    value: MoneyMove.transfer,
                    enabled: canTransfer,
                    icon: const Icon(Icons.swap_horiz_rounded),
                    label: const Text('Transfer'),
                  ),
                ],
                selected: {_kind},
                onSelectionChanged: (s) => setState(() => _kind = s.first),
              ),
              const SizedBox(height: Spacing.sm),
              Text(
                switch (_kind) {
                  MoneyMove.add => 'Record money put in — owner capital, a loan, cash found…',
                  MoneyMove.reduce => 'Record money taken out — owner drawings, bank charges…',
                  MoneyMove.transfer => 'Move money between your bank accounts.',
                },
                style: context.text.bodySmall,
              ),
              const SizedBox(height: Spacing.lg),
              if (_error != null) ErrorBanner(_error!),
              if (_kind != MoneyMove.transfer)
                DropdownButtonFormField<String>(
                  initialValue: _account,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Account', prefixIcon: Icon(Icons.account_balance_wallet_outlined)),
                  items: [
                    const DropdownMenuItem(value: _cash, child: Text('Cash in hand')),
                    for (final a in widget.accounts) DropdownMenuItem(value: a.id, child: Text(a.label)),
                  ],
                  onChanged: (v) => setState(() => _account = v ?? _cash),
                )
              else ...[
                DropdownButtonFormField<String>(
                  initialValue: _from,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'From',
                    helperText: from == null ? null : 'Balance ${money(from.balance)}',
                    prefixIcon: const Icon(Icons.north_east_rounded),
                  ),
                  items: [for (final a in widget.accounts) DropdownMenuItem(value: a.id, child: Text(a.label))],
                  onChanged: (v) => setState(() {
                    _from = v;
                    if (_to == v) _to = widget.accounts.where((a) => a.id != v).firstOrNull?.id;
                  }),
                ),
                const SizedBox(height: Spacing.md),
                DropdownButtonFormField<String>(
                  initialValue: _to,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'To', prefixIcon: Icon(Icons.south_west_rounded)),
                  items: [
                    for (final a in widget.accounts.where((a) => a.id != _from)) DropdownMenuItem(value: a.id, child: Text(a.label)),
                  ],
                  onChanged: (v) => setState(() => _to = v),
                  validator: (v) => v == null ? 'Choose an account' : null,
                ),
              ],
              const SizedBox(height: Spacing.md),
              FieldRow(children: [
                NumberField(
                  controller: _amount,
                  label: 'Amount *',
                  autofocus: true,
                  validator: (v) {
                    final e = Validators.number(v, required: true, allowZero: false, field: 'Amount');
                    if (e != null) return e;
                    // The server refuses transfers above the source balance.
                    if (_kind == MoneyMove.transfer && from != null && (double.tryParse(v!) ?? 0) > from.balance) {
                      return 'Only ${money(from.balance)} available';
                    }
                    return null;
                  },
                ),
                DateField(label: 'Date', value: _date, onChanged: (d) => setState(() => _date = d ?? _date)),
              ]),
              const SizedBox(height: Spacing.md),
              TextFormField(
                controller: _description,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: Spacing.md),
              TextFormField(controller: _reference, decoration: const InputDecoration(labelText: 'Reference')),
              const SizedBox(height: Spacing.lg),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                    : Text(switch (_kind) {
                        MoneyMove.add => 'Add money',
                        MoneyMove.reduce => 'Reduce money',
                        MoneyMove.transfer => 'Transfer',
                      }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Inflow/outflow tile used by the cash & bank screens.
class CashTxnTile extends StatelessWidget {
  const CashTxnTile({super.key, required this.inflow, required this.amount, required this.title, required this.subtitle, this.onLongPress});
  final bool inflow;
  final double amount;
  final String title;
  final String subtitle;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final color = inflow ? StatusColors.success : StatusColors.danger;
    return ListTile(
      onLongPress: onLongPress,
      leading: IconBadge(inflow ? Icons.south_west_rounded : Icons.north_east_rounded, color: color),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text('${inflow ? '+' : '−'} ${money(amount)}',
          style: context.text.labelLarge?.copyWith(color: color, fontFeatures: const [FontFeature.tabularFigures()])),
    );
  }
}
