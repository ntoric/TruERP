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
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/form_widgets.dart';
import '../data/expenses_repository.dart';
import 'expenses_screen.dart';

class ExpenseDetailScreen extends ConsumerWidget {
  const ExpenseDetailScreen({super.key, required this.expenseId, this.embedded = false});
  final String expenseId;
  final bool embedded;

  Future<void> _cancel(BuildContext context, WidgetRef ref, Expense e) async {
    final reason = await askReason(context, title: 'Cancel expense ${e.number}?', confirmLabel: 'Cancel expense');
    if (reason == null) return;
    try {
      await ref.read(expensesRepositoryProvider).cancel(e.id, reason);
      ref.read(dataRevisionProvider.notifier).bump();
      if (context.mounted) showSnack(context, 'Expense cancelled');
    } catch (err) {
      if (context.mounted) showSnack(context, errorMessage(err), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(expenseProvider(expenseId));
    final e = async.asData?.value;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !embedded,
        title: Text(e?.number.isNotEmpty == true ? e!.number : 'Expense'),
        actions: [
          if (e != null && !e.isCancelled) ...[
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push('/expenses/${e.id}/edit'),
            ),
            IconButton(
              tooltip: 'Cancel expense',
              icon: const Icon(Icons.block_rounded),
              onPressed: () => _cancel(context, ref, e),
            ),
          ],
        ],
      ),
      body: async.when(
        loading: () => const SkeletonList(count: 6),
        error: (err, _) => ErrorView(error: err, onRetry: () => ref.invalidate(expenseProvider(expenseId))),
        data: (e) => ListView(
          padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.sm, Spacing.lg, Spacing.xxl),
          children: [
            ContentWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (e.isCancelled)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Spacing.md),
                      child: ErrorBanner('Cancelled${e.cancelReason.isEmpty ? '' : ': ${e.cancelReason}'}'),
                    ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(Spacing.lg),
                      child: Row(children: [
                        const IconBadge(Icons.receipt_rounded, color: expensesAccent, size: 48),
                        const SizedBox(width: Spacing.md),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(e.title, style: context.text.titleMedium),
                            Text(e.category, style: context.text.bodySmall),
                          ]),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: Spacing.md),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(Spacing.lg),
                      child: Row(children: [
                        Expanded(child: Text('Amount', style: context.text.bodyMedium)),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(money(e.amount),
                                style: context.text.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  decoration: e.isCancelled ? TextDecoration.lineThrough : null,
                                )),
                          ),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: Spacing.lg),
                  SectionCard(
                    title: 'Details',
                    child: Column(children: [
                      KeyValueRow('Date', dateText(e.date)),
                      if (e.paymentMode.isNotEmpty) KeyValueRow('Paid by', PaymentMode.labelOf(e.paymentMode)),
                      if (e.bankAccountLabel != null) KeyValueRow('Account', e.bankAccountLabel!),
                      if (e.vendor.isNotEmpty) KeyValueRow('Vendor', e.vendor),
                      if (e.originalInvoiceNum.isNotEmpty) KeyValueRow('Bill no.', e.originalInvoiceNum),
                      if (e.notes.isNotEmpty) KeyValueRow('Notes', e.notes),
                    ]),
                  ),
                  if (e.items.isNotEmpty) ...[
                    const SizedBox(height: Spacing.lg),
                    SectionCard(
                      title: 'Items',
                      padding: const EdgeInsets.fromLTRB(0, Spacing.xs, 0, Spacing.sm),
                      child: Column(children: [
                        for (final it in e.items)
                          ListTile(
                            dense: true,
                            title: Text(it.description),
                            subtitle: Text('${qty(it.quantity)} × ${money(it.unitPrice)}'),
                            trailing: Text(money(it.total > 0 ? it.total : it.amount), style: context.text.labelLarge),
                          ),
                      ]),
                    ),
                  ],
                  if (e.withGst) ...[
                    const SizedBox(height: Spacing.lg),
                    SectionCard(
                      title: 'GST',
                      child: Column(children: [
                        KeyValueRow('Taxable amount', money(e.subTotal)),
                        KeyValueRow('GST @ ${qty(e.taxRate)}%', money(e.taxTotal)),
                        KeyValueRow('Total', money(e.amount), bold: true),
                      ]),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
