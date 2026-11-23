import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/payment.dart';
import '../../../core/theme/tokens.dart';
import '../../payments/data/payments_repository.dart';
import '../data/hr_repository.dart';

const hrAccent = Color(0xFFDB2777);

/// Payment mode chips plus bank account (non-cash) for staff payouts.
class PayoutPicker extends ConsumerStatefulWidget {
  const PayoutPicker({
    super.key,
    required this.onChanged,
    this.label = 'Paid by',
  });
  final ValueChanged<Payout> onChanged;
  final String label;

  @override
  ConsumerState<PayoutPicker> createState() => _PayoutPickerState();
}

class _PayoutPickerState extends ConsumerState<PayoutPicker> {
  String _mode = 'cash';
  String? _bankId;
  final _reference = TextEditingController();

  /// Staff payouts on the web offer these four modes.
  static const _modes = [
    PaymentMode.cash,
    PaymentMode.bank,
    PaymentMode.upi,
    PaymentMode.cheque,
  ];

  @override
  void dispose() {
    _reference.dispose();
    super.dispose();
  }

  void _emit() => widget.onChanged(
    Payout(mode: _mode, bankAccountId: _bankId, reference: _reference.text),
  );

  @override
  Widget build(BuildContext context) {
    final banks =
        ref.watch(bankAccountsProvider).asData?.value ?? const <BankAccount>[];
    if (_bankId == null && banks.isNotEmpty) {
      _bankId = (banks.where((b) => b.isPrimary).firstOrNull ?? banks.first).id;
      WidgetsBinding.instance.addPostFrameCallback((_) => _emit());
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: Spacing.sm),
        Wrap(
          spacing: Spacing.sm,
          runSpacing: Spacing.sm,
          children: [
            for (final m in _modes)
              ChoiceChip(
                label: Text(m.label),
                selected: _mode == m.value,
                onSelected: (_) {
                  setState(() => _mode = m.value);
                  _emit();
                },
              ),
          ],
        ),
        if (_mode != 'cash' && banks.isNotEmpty) ...[
          const SizedBox(height: Spacing.md),
          DropdownButtonFormField<String>(
            initialValue: _bankId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'From account',
              prefixIcon: Icon(Icons.account_balance_outlined),
            ),
            items: [
              for (final b in banks)
                DropdownMenuItem(value: b.id, child: Text(b.label)),
            ],
            onChanged: (v) {
              setState(() => _bankId = v);
              _emit();
            },
          ),
        ],
        if (_mode != 'cash') ...[
          const SizedBox(height: Spacing.md),
          TextField(
            controller: _reference,
            onChanged: (_) => _emit(),
            decoration: const InputDecoration(
              labelText: 'Reference',
              hintText: 'UTR / cheque no.',
            ),
          ),
        ],
      ],
    );
  }
}
