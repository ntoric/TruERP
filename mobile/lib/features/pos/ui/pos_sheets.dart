import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/api/revision.dart';
import '../../../core/models/invoice.dart';
import '../../../core/models/party.dart';
import '../../../core/models/payment.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/utils/share_utils.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/form_widgets.dart';
import '../../payments/data/payments_repository.dart';
import '../data/pos_models.dart';
import '../data/pos_repository.dart';
import 'pos_screen.dart';

// ── Checkout ────────────────────────────────────────────────────────────

/// Takes payment and creates the sale. Returns the invoice, or null if cancelled.
Future<Invoice?> showCheckoutSheet(
  BuildContext context, {
  required PosSession session,
  required List<CartLine> lines,
  Party? party,
  double discount = 0,
}) =>
    showModalBottomSheet<Invoice>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      builder: (_) => _Checkout(session: session, lines: lines, party: party, discount: discount),
    );

class _Checkout extends ConsumerStatefulWidget {
  const _Checkout({required this.session, required this.lines, this.party, this.discount = 0});
  final PosSession session;
  final List<CartLine> lines;
  final Party? party;
  final double discount;

  @override
  ConsumerState<_Checkout> createState() => _CheckoutState();
}

class _CheckoutState extends ConsumerState<_Checkout> {
  /// One idempotency key per checkout attempt.
  final _saleId = PosRepository.newSaleId();
  late final double _total = posTotals(widget.lines, discount: widget.discount).total;
  late final _tenders = <Tender>[Tender(mode: 'cash', amount: _total)];
  late final _received = TextEditingController(text: NumberField.text(_total));
  bool _split = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _received.dispose();
    super.dispose();
  }

  double get _paid => _tenders.fold(0, (s, t) => s + t.amount);

  /// Cash handed over (single cash tender only) minus the bill.
  double get _change => !_split && _tenders.single.mode == 'cash' ? (NumberField.parse(_received) - _total).clamp(0, double.infinity) : 0;

  Future<void> _charge() async {
    if (!_split && _tenders.single.mode == 'cash' && NumberField.parse(_received) < _total - 0.01) {
      // Cash short of the total: record what was actually received.
      _tenders.single.amount = NumberField.parse(_received);
    }
    final due = _total - _paid;
    if (due > 0.01 && widget.party == null) {
      setState(() => _error = 'Choose a customer to leave ${money(due)} unpaid on credit.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final inv = await ref.read(posRepositoryProvider).sell(
            clientSaleId: _saleId,
            session: widget.session,
            lines: widget.lines,
            tenders: _tenders,
            party: widget.party,
            discount: widget.discount,
          );
      ref.read(dataRevisionProvider.notifier).bump();
      if (mounted) Navigator.pop(context, inv);
    } catch (e) {
      setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final banks = ref.watch(bankAccountsProvider).asData?.value ?? const <BankAccount>[];
    final primary = (banks.where((b) => b.isPrimary).firstOrNull ?? banks.firstOrNull)?.id;
    for (final t in _tenders) {
      t.bankAccountId ??= primary;
    }
    final due = _total - _paid;

    return Padding(
      padding: EdgeInsets.fromLTRB(Spacing.xl, 0, Spacing.xl, MediaQuery.viewInsetsOf(context).bottom + Spacing.xl),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text('Charge', style: context.text.titleMedium)),
            IconButton(onPressed: _busy ? null : () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
          ]),
          Text(money(_total), style: context.text.displaySmall?.copyWith(fontWeight: FontWeight.w700)),
          Text('${widget.lines.length} items · ${widget.party?.name ?? 'Walk-in customer'}', style: context.text.bodySmall),
          const SizedBox(height: Spacing.lg),
          if (_error != null) ErrorBanner(_error!),
          if (!_split) ...[
            Wrap(spacing: Spacing.sm, runSpacing: Spacing.sm, children: [
              for (final m in PaymentMode.receipt)
                ChoiceChip(
                  label: Text(m.label),
                  selected: _tenders.single.mode == m.value,
                  onSelected: (_) => setState(() {
                    _tenders.single
                      ..mode = m.value
                      ..amount = _total;
                    _received.text = NumberField.text(_total);
                  }),
                ),
            ]),
            if (_tenders.single.mode == 'cash') ...[
              const SizedBox(height: Spacing.md),
              NumberField(controller: _received, label: 'Cash received', onChanged: (_) => setState(() {})),
              const SizedBox(height: Spacing.sm),
              Wrap(spacing: Spacing.sm, children: [
                for (final note in _quickNotes(_total))
                  ActionChip(label: Text(moneyShort(note)), onPressed: () => setState(() => _received.text = NumberField.text(note))),
              ]),
              if (_change > 0)
                Padding(
                  padding: const EdgeInsets.only(top: Spacing.md),
                  child: KeyValueRow('Change to return', money(_change), bold: true, valueColor: StatusColors.success),
                ),
            ] else if (banks.isNotEmpty) ...[
              const SizedBox(height: Spacing.md),
              DropdownButtonFormField<String>(
                initialValue: _tenders.single.bankAccountId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Deposit to'),
                items: [for (final b in banks) DropdownMenuItem(value: b.id, child: Text(b.label))],
                onChanged: (v) => setState(() => _tenders.single.bankAccountId = v),
              ),
            ],
          ] else ...[
            for (final (i, t) in _tenders.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: Spacing.sm),
                child: Row(children: [
                  SizedBox(
                    width: 130,
                    child: DropdownButtonFormField<String>(
                      initialValue: t.mode,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Mode'),
                      items: [for (final m in PaymentMode.receipt) DropdownMenuItem(value: m.value, child: Text(m.label))],
                      onChanged: (v) => setState(() => t.mode = v ?? 'cash'),
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: TextFormField(
                      initialValue: NumberField.text(t.amount),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ '),
                      onChanged: (v) => setState(() => t.amount = double.tryParse(v) ?? 0),
                    ),
                  ),
                  if (_tenders.length > 1)
                    IconButton(onPressed: () => setState(() => _tenders.removeAt(i)), icon: const Icon(Icons.close_rounded)),
                ]),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _tenders.add(Tender(mode: 'upi', amount: due > 0 ? due : 0, bankAccountId: primary))),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add payment'),
              ),
            ),
            KeyValueRow(due >= 0 ? 'Remaining' : 'Over by', money(due.abs()), bold: true, valueColor: due.abs() < 0.01 ? StatusColors.success : StatusColors.danger),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Split payment'),
            value: _split,
            onChanged: (v) => setState(() {
              _split = v;
              if (!v) {
                _tenders
                  ..clear()
                  ..add(Tender(mode: 'cash', amount: _total, bankAccountId: primary));
                _received.text = NumberField.text(_total);
              }
            }),
          ),
          const SizedBox(height: Spacing.sm),
          FilledButton(
            onPressed: _busy || (_split && due < -0.01) ? null : _charge,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            child: _busy
                ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                : Text(_split && due > 0.01 ? 'Charge (${money(due)} on credit)' : 'Complete sale'),
          ),
        ]),
      ),
    );
  }

  /// Common notes above the total (₹50/100/200/500/2000 steps).
  static List<double> _quickNotes(double total) {
    final out = <double>{total.ceilToDouble()};
    for (final step in const [50.0, 100.0, 500.0, 2000.0]) {
      final up = (total / step).ceil() * step;
      if (up > total) out.add(up);
    }
    return (out.toList()..sort()).take(4).toList();
  }
}

// ── Receipt ─────────────────────────────────────────────────────────────

Future<void> showReceiptSheet(BuildContext context, Invoice inv) => showModalBottomSheet<void>(
      context: context,
      builder: (_) => _Receipt(invoice: inv),
    );

class _Receipt extends ConsumerWidget {
  const _Receipt({required this.invoice});
  final Invoice invoice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inv = invoice;
    final phone = inv.party?.phone ?? '';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Spacing.xl, 0, Spacing.xl, Spacing.xl),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Center(child: IconBadge(Icons.check_rounded, color: StatusColors.success, size: 64)),
          const SizedBox(height: Spacing.md),
          Text('Sale complete', style: context.text.titleLarge, textAlign: TextAlign.center),
          Text('${inv.number} · ${money(inv.totalAmount)}', style: context.text.bodyMedium, textAlign: TextAlign.center),
          if (inv.balanceDue > 0.005)
            Text('${money(inv.balanceDue)} on credit', style: context.text.bodySmall?.copyWith(color: StatusColors.danger), textAlign: TextAlign.center),
          const SizedBox(height: Spacing.xl),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => sharePdf(context, ref.read(apiClientProvider), '/invoices/${inv.id}/pdf', 'Receipt_${inv.number}.pdf'),
                icon: const Icon(Icons.ios_share_rounded),
                label: const Text('Share receipt'),
              ),
            ),
            if (phone.isNotEmpty) ...[
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => openWhatsApp(context, phone, text: 'Thank you for shopping! Bill ${inv.number}: ${money(inv.totalAmount)}.'),
                  icon: const Icon(Icons.chat_outlined),
                  label: const Text('WhatsApp'),
                ),
              ),
            ],
          ]),
          const SizedBox(height: Spacing.sm),
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('New sale')),
        ]),
      ),
    );
  }
}

// ── Held bills ──────────────────────────────────────────────────────────

Future<HeldBill?> showHeldBillsSheet(BuildContext context) => showModalBottomSheet<HeldBill>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _HeldBills(),
    );

class _HeldBills extends ConsumerWidget {
  const _HeldBills();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(heldBillsProvider);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Spacing.xl, 0, Spacing.xl, Spacing.sm),
            child: Text('Held bills', style: context.text.titleMedium),
          ),
          Flexible(
            child: async.when(
              loading: () => const Padding(padding: EdgeInsets.all(Spacing.xl), child: LinearProgressIndicator()),
              error: (e, _) => Padding(padding: const EdgeInsets.all(Spacing.xl), child: Text(errorMessage(e))),
              data: (bills) => bills.isEmpty
                  ? const Padding(padding: EdgeInsets.all(Spacing.xl), child: Text('No bills on hold.'))
                  : ListView(shrinkWrap: true, children: [
                      for (final b in bills)
                        ListTile(
                          onTap: () => Navigator.pop(context, b),
                          leading: const IconBadge(Icons.pause_circle_outline_rounded, color: posAccent),
                          title: Text(b.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text('${b.itemCount} items · ${dateTimeText(b.createdAt)}'),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(money(b.total), style: context.text.labelLarge),
                            IconButton(
                              tooltip: 'Discard',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                final ok = await confirmSheet(context, title: 'Discard "${b.title}"?', confirmLabel: 'Discard', destructive: true);
                                if (!ok) return;
                                try {
                                  await ref.read(posRepositoryProvider).deleteHeld(b.id);
                                  ref.read(dataRevisionProvider.notifier).bump();
                                } catch (e) {
                                  if (context.mounted) showSnack(context, errorMessage(e), error: true);
                                }
                              },
                            ),
                          ]),
                        ),
                    ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Cash in / out ───────────────────────────────────────────────────────

Future<void> showCashMovementSheet(BuildContext context, PosSession s, {required bool cashIn}) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _Movement(session: s, cashIn: cashIn),
    );

class _Movement extends ConsumerStatefulWidget {
  const _Movement({required this.session, required this.cashIn});
  final PosSession session;
  final bool cashIn;

  @override
  ConsumerState<_Movement> createState() => _MovementState();
}

class _MovementState extends ConsumerState<_Movement> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _reason = TextEditingController();
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
    try {
      await ref.read(posRepositoryProvider).addMovement(widget.session.id, cashIn: widget.cashIn, amount: NumberField.parse(_amount), reason: _reason.text);
      ref.read(dataRevisionProvider.notifier).bump();
      if (!mounted) return;
      Navigator.pop(context);
      showSnack(context, '${widget.cashIn ? 'Cash in' : 'Cash out'} of ${money(NumberField.parse(_amount))} recorded');
    } catch (e) {
      setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(Spacing.xl, 0, Spacing.xl, MediaQuery.viewInsetsOf(context).bottom + Spacing.xl),
        child: Form(
          key: _form,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(widget.cashIn ? 'Cash in' : 'Cash out', style: context.text.titleMedium),
            Text(widget.cashIn ? 'Money added to the drawer (e.g. change from the bank).' : 'Money taken out (e.g. petty expense, bank deposit).',
                style: context.text.bodySmall),
            const SizedBox(height: Spacing.lg),
            if (_error != null) ErrorBanner(_error!),
            NumberField(controller: _amount, label: 'Amount', autofocus: true, validator: requiredAmount),
            const SizedBox(height: Spacing.md),
            TextFormField(controller: _reason, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Reason')),
            const SizedBox(height: Spacing.lg),
            FilledButton(onPressed: _busy ? null : _save, child: const Text('Save')),
          ]),
        ),
      );
}

// ── Close session ───────────────────────────────────────────────────────

Future<void> showCloseSessionSheet(BuildContext context, PosSession s) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _Close(session: s),
    );

class _Close extends ConsumerStatefulWidget {
  const _Close({required this.session});
  final PosSession session;

  @override
  ConsumerState<_Close> createState() => _CloseState();
}

class _CloseState extends ConsumerState<_Close> {
  late final _counted = TextEditingController(text: NumberField.text(widget.session.expectedCash));
  final _notes = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _counted.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    setState(() => _busy = true);
    try {
      await ref.read(posRepositoryProvider).closeSession(widget.session.id, closingCash: NumberField.parse(_counted), notes: _notes.text);
      ref.read(dataRevisionProvider.notifier).bump();
      if (!mounted) return;
      Navigator.pop(context);
      showSnack(context, 'Session closed');
    } catch (e) {
      setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final diff = NumberField.parse(_counted) - s.expectedCash;
    return Padding(
      padding: EdgeInsets.fromLTRB(Spacing.xl, 0, Spacing.xl, MediaQuery.viewInsetsOf(context).bottom + Spacing.xl),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Close session', style: context.text.titleMedium),
          Text('Opened ${dateTimeText(s.openedAt)}', style: context.text.bodySmall),
          const SizedBox(height: Spacing.lg),
          if (_error != null) ErrorBanner(_error!),
          KeyValueRow('Opening cash', money(s.openingCash)),
          KeyValueRow('Sales (${s.totalInvoices})', money(s.totalSales)),
          if (s.cashIn > 0) KeyValueRow('Cash in', money(s.cashIn)),
          if (s.cashOut > 0) KeyValueRow('Cash out', '− ${money(s.cashOut)}'),
          KeyValueRow('Expected in drawer', money(s.expectedCash), bold: true),
          Text('Expected assumes every sale was paid in cash; UPI and card sales lower what should be in the drawer.',
              style: context.text.bodySmall),
          const SizedBox(height: Spacing.md),
          NumberField(controller: _counted, label: 'Counted cash', onChanged: (_) => setState(() {})),
          if (diff.abs() >= 0.5)
            Padding(
              padding: const EdgeInsets.only(top: Spacing.sm),
              child: KeyValueRow(diff > 0 ? 'Over by' : 'Short by', money(diff.abs()), valueColor: diff > 0 ? StatusColors.success : StatusColors.danger),
            ),
          const SizedBox(height: Spacing.md),
          TextFormField(controller: _notes, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Notes')),
          const SizedBox(height: Spacing.lg),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: StatusColors.danger),
            onPressed: _busy ? null : _close,
            child: const Text('Close session'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/pos/sessions');
            },
            child: const Text('Session history'),
          ),
        ]),
      ),
    );
  }
}
