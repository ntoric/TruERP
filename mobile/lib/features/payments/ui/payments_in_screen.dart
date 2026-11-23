import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/api/revision.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/models/payment.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/utils/share_utils.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/form_widgets.dart';
import '../../../shared/widgets/paged_list.dart';
import '../data/payments_repository.dart';

const paymentsAccent = Color(0xFF6366F1);

class PaymentsInScreen extends ConsumerStatefulWidget {
  const PaymentsInScreen({super.key});

  @override
  ConsumerState<PaymentsInScreen> createState() => _PaymentsInScreenState();
}

class _PaymentsInScreenState extends ConsumerState<PaymentsInScreen> {
  String _q = '';
  String? _mode;

  @override
  Widget build(BuildContext context) {
    final rev = ref.watch(dataRevisionProvider);
    final store = ref.watch(activeStoreIdProvider);
    final repo = ref.read(paymentsRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Payments received')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new-payment-in',
        onPressed: () => context.push('/payments-in/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Receive payment'),
      ),
      body: ContentWidth(
        maxWidth: 900,
        child: PagedListView<PaymentIn>(
          resetKey: (_q, _mode, rev, store),
          fetch: (page) => repo.list(page: page, search: _q, mode: _mode),
          header: Padding(
            padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.sm, Spacing.lg, Spacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SearchField(hint: 'Search customer, number, reference', onChanged: (v) => setState(() => _q = v)),
                const SizedBox(height: Spacing.sm),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    ChoiceChip(label: const Text('All'), selected: _mode == null, onSelected: (_) => setState(() => _mode = null)),
                    for (final m in PaymentMode.receipt) ...[
                      const SizedBox(width: Spacing.sm),
                      ChoiceChip(
                        label: Text(m.label),
                        selected: _mode == m.value,
                        onSelected: (_) => setState(() => _mode = _mode == m.value ? null : m.value),
                      ),
                    ],
                  ]),
                ),
              ],
            ),
          ),
          empty: EmptyState(
            icon: Icons.call_received_rounded,
            title: _q.isEmpty && _mode == null ? 'No payments yet' : 'No matching payments',
            message: _q.isEmpty && _mode == null ? 'Money you receive from customers shows up here.' : null,
          ),
          itemBuilder: (ctx, p, _) => PaymentInTile(payment: p, onTap: () => showPaymentInSheet(context, p)),
        ),
      ),
    );
  }
}

class PaymentInTile extends StatelessWidget {
  const PaymentInTile({super.key, required this.payment, required this.onTap});
  final PaymentIn payment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = payment;
    return ListTile(
      onTap: onTap,
      leading: IconBadge(Icons.call_received_rounded, color: p.isCancelled ? StatusColors.neutral : StatusColors.success),
      title: Text(p.party?.name ?? 'Payment', maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(
        [if (p.number.isNotEmpty) p.number, relativeDay(p.date), PaymentMode.labelOf(p.mode)].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(money(p.amount),
              style: context.text.labelLarge?.copyWith(
                color: p.isCancelled ? null : StatusColors.success,
                decoration: p.isCancelled ? TextDecoration.lineThrough : null,
              )),
          if (p.isCancelled) const StatusChip('cancelled'),
        ],
      ),
    );
  }
}

/// Payment details with receipt PDF and cancel.
Future<void> showPaymentInSheet(BuildContext context, PaymentIn p) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PaymentSheet(payment: p),
    );

class _PaymentSheet extends ConsumerWidget {
  const _PaymentSheet({required this.payment});
  final PaymentIn payment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = payment;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Spacing.xl, 0, Spacing.xl, Spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              const IconBadge(Icons.call_received_rounded, color: StatusColors.success, size: 44),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(money(p.amount), style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  Text(p.party?.name ?? '', style: context.text.bodyMedium),
                ]),
              ),
              StatusChip(p.status),
            ]),
            const SizedBox(height: Spacing.lg),
            KeyValueRow('Receipt no.', p.number.isEmpty ? '—' : p.number),
            KeyValueRow('Date', dateText(p.date)),
            KeyValueRow('Mode', PaymentMode.labelOf(p.mode)),
            if (p.bankAccountLabel != null) KeyValueRow('Account', p.bankAccountLabel!),
            if (p.invoiceNumber != null) KeyValueRow('Against invoice', p.invoiceNumber!),
            if (p.discount > 0) KeyValueRow('Discount allowed', money(p.discount)),
            if (p.reference.isNotEmpty) KeyValueRow('Reference', p.reference),
            if (p.notes.isNotEmpty) KeyValueRow('Notes', p.notes),
            if (p.isCancelled && p.cancelReason.isNotEmpty) KeyValueRow('Cancel reason', p.cancelReason),
            const SizedBox(height: Spacing.lg),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.ios_share_rounded),
                  label: const Text('Receipt'),
                  onPressed: () => sharePdf(context, ref.read(apiClientProvider), '/payments/${p.id}/pdf',
                      'Receipt_${p.number.isEmpty ? p.id : p.number}.pdf'),
                ),
              ),
              if (p.invoiceId != null) ...[
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('Invoice'),
                    onPressed: () {
                      Navigator.pop(context);
                      context.push('/invoices/${p.invoiceId}');
                    },
                  ),
                ),
              ],
            ]),
            if (!p.isCancelled) ...[
              const SizedBox(height: Spacing.sm),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: StatusColors.danger),
                icon: const Icon(Icons.block_rounded),
                label: const Text('Cancel payment'),
                onPressed: () async {
                  final reason = await askReason(context, title: 'Cancel this payment?', confirmLabel: 'Cancel payment');
                  if (reason == null || !context.mounted) return;
                  try {
                    await ref.read(paymentsRepositoryProvider).cancel(p.id, reason);
                    ref.read(dataRevisionProvider.notifier).bump();
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    showSnack(context, 'Payment cancelled');
                  } catch (e) {
                    if (context.mounted) showSnack(context, errorMessage(e), error: true);
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
