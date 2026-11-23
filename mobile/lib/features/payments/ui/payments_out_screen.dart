import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/revision.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/models/payment.dart';
import '../../../core/models/purchase.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/doc_widgets.dart';
import '../../../shared/widgets/form_widgets.dart';
import '../../../shared/widgets/paged_list.dart';
import '../data/payments_repository.dart';

class PaymentsOutScreen extends ConsumerStatefulWidget {
  const PaymentsOutScreen({super.key});

  @override
  ConsumerState<PaymentsOutScreen> createState() => _PaymentsOutScreenState();
}

class _PaymentsOutScreenState extends ConsumerState<PaymentsOutScreen> {
  String _q = '';
  String? _mode;

  @override
  Widget build(BuildContext context) {
    final rev = ref.watch(dataRevisionProvider);
    final store = ref.watch(activeStoreIdProvider);
    final repo = ref.read(paymentsRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Payments made')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new-payment-out',
        onPressed: () => context.push('/payments-out/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Pay vendor'),
      ),
      body: ContentWidth(
        maxWidth: 900,
        child: PagedListView<PaymentOut>(
          resetKey: (_q, _mode, rev, store),
          fetch: (page) => repo.listOut(page: page, search: _q, mode: _mode),
          header: ListFilters(
            searchHint: 'Search vendor, number, reference',
            onSearch: (v) => setState(() => _q = v),
            chips: [
              ChoiceChip(
                label: const Text('All'),
                selected: _mode == null,
                onSelected: (_) => setState(() => _mode = null),
              ),
              for (final m in PaymentMode.receipt)
                ChoiceChip(
                  label: Text(m.label),
                  selected: _mode == m.value,
                  onSelected: (_) =>
                      setState(() => _mode = _mode == m.value ? null : m.value),
                ),
            ],
          ),
          empty: EmptyState(
            icon: Icons.call_made_rounded,
            title: _q.isEmpty && _mode == null
                ? 'No payments made yet'
                : 'No matching payments',
            message: _q.isEmpty && _mode == null
                ? 'Money you pay to vendors shows up here.'
                : null,
          ),
          itemBuilder: (ctx, p, _) => MoneyTile(
            icon: Icons.call_made_rounded,
            accent: StatusColors.danger,
            title: p.party?.name ?? 'Payment',
            subtitle: [
              if (p.number.isNotEmpty) p.number,
              relativeDay(p.date),
              PaymentMode.labelOf(p.mode),
            ].join(' · '),
            amount: p.amount,
            amountColor: StatusColors.danger,
            struck: p.isCancelled,
            status: p.isCancelled ? 'cancelled' : null,
            onTap: () => showPaymentOutSheet(context, p),
          ),
        ),
      ),
    );
  }
}

Future<void> showPaymentOutSheet(BuildContext context, PaymentOut p) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _Sheet(payment: p),
    );

class _Sheet extends ConsumerWidget {
  const _Sheet({required this.payment});
  final PaymentOut payment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = payment;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Spacing.xl,
          0,
          Spacing.xl,
          Spacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const IconBadge(
                  Icons.call_made_rounded,
                  color: StatusColors.danger,
                  size: 44,
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        money(p.amount),
                        style: context.text.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(p.party?.name ?? '', style: context.text.bodyMedium),
                    ],
                  ),
                ),
                StatusChip(p.status),
              ],
            ),
            const SizedBox(height: Spacing.lg),
            KeyValueRow('Number', p.number.isEmpty ? '—' : p.number),
            KeyValueRow('Date', dateText(p.date)),
            KeyValueRow('Mode', PaymentMode.labelOf(p.mode)),
            if (p.bankAccountLabel != null)
              KeyValueRow('Account', p.bankAccountLabel!),
            if (p.purchaseBillNumber != null)
              KeyValueRow('Against bill', p.purchaseBillNumber!),
            if (p.discount > 0)
              KeyValueRow('Discount received', money(p.discount)),
            if (p.reference.isNotEmpty) KeyValueRow('Reference', p.reference),
            if (p.notes.isNotEmpty) KeyValueRow('Notes', p.notes),
            if (p.isCancelled && p.cancelReason.isNotEmpty)
              KeyValueRow('Cancel reason', p.cancelReason),
            const SizedBox(height: Spacing.lg),
            if (p.purchaseBillId != null)
              OutlinedButton.icon(
                icon: const Icon(Icons.description_outlined),
                label: const Text('Open bill'),
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/purchases/${p.purchaseBillId}');
                },
              ),
            if (!p.isCancelled)
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: StatusColors.danger,
                ),
                icon: const Icon(Icons.block_rounded),
                label: const Text('Cancel payment'),
                onPressed: () async {
                  final reason = await askReason(
                    context,
                    title: 'Cancel this payment?',
                    confirmLabel: 'Cancel payment',
                  );
                  if (reason == null || !context.mounted) return;
                  try {
                    await ref
                        .read(paymentsRepositoryProvider)
                        .cancelOut(p.id, reason);
                    ref.read(dataRevisionProvider.notifier).bump();
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    showSnack(context, 'Payment cancelled');
                  } catch (e) {
                    if (context.mounted) {
                      showSnack(context, errorMessage(e), error: true);
                    }
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}
