import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/api/revision.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/models/payment.dart';
import '../../../core/models/purchase.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/utils/share_utils.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/doc_widgets.dart';
import '../../../shared/widgets/form_widgets.dart';
import '../../payments/data/payments_repository.dart';
import '../data/purchases_repository.dart';

final _billPaymentsProvider = FutureProvider.autoDispose.family<List<PaymentOut>, String>((ref, id) async {
  ref.watch(dataRevisionProvider);
  return (await ref.watch(paymentsRepositoryProvider).listOut(purchaseBillId: id)).items;
});

/// Where the bill's stock entries stand (the backend approves them on save;
/// older bills may still be pending).
(String, String) _stockStatus(String s) => switch (s) {
      'pending' => ('pending', 'Stock pending approval'),
      'approved' => ('approved', 'Stock added'),
      'partial' => ('partial', 'Stock partly added'),
      'rejected' => ('rejected', 'Stock rejected'),
      _ => ('draft', 'No stock change'),
    };

class PurchaseBillDetailScreen extends ConsumerWidget {
  const PurchaseBillDetailScreen({super.key, required this.billId, this.embedded = false, this.onDeleted});
  final String billId;
  final bool embedded;
  final VoidCallback? onDeleted;

  Future<void> _delete(BuildContext context, WidgetRef ref, PurchaseBill b) async {
    final ok = await confirmSheet(context,
        title: 'Delete bill ${b.number}?',
        message: 'This reverses the vendor balance, linked payments and pending stock for this bill. It can\'t be undone.',
        confirmLabel: 'Delete bill',
        destructive: true);
    if (!ok) return;
    try {
      await ref.read(purchasesRepositoryProvider).deleteBill(b.id);
      ref.read(dataRevisionProvider.notifier).bump();
      if (!context.mounted) return;
      showSnack(context, 'Bill ${b.number} deleted');
      embedded ? onDeleted?.call() : context.pop();
    } catch (e) {
      if (context.mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(purchaseBillProvider(billId));
    final b = async.asData?.value;
    final isSuperAdmin = ref.watch(currentUserProvider)?.isSuperAdmin ?? false;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !embedded,
        title: Text(b?.number ?? 'Purchase bill'),
        actions: [
          if (b != null) ...[
            IconButton(
              tooltip: 'Share PDF',
              icon: const Icon(Icons.ios_share_rounded),
              onPressed: () => sharePdf(
                  context, ref.read(apiClientProvider), '/purchase/bills/${b.id}/download-pdf', 'Purchase_${b.number}.pdf'),
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'return') context.push('/purchase-returns/new?bill=${b.id}');
                if (v == 'vendor') context.push('/parties/${b.partyId}');
                if (v == 'delete') _delete(context, ref, b);
              },
              itemBuilder: (_) => [
                if (!b.isDraft && b.items.isNotEmpty)
                  const PopupMenuItem(value: 'return', child: ListTile(leading: Icon(Icons.undo_rounded), title: Text('Return items'))),
                const PopupMenuItem(value: 'vendor', child: ListTile(leading: Icon(Icons.storefront_outlined), title: Text('Open vendor'))),
                if (isSuperAdmin)
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(leading: Icon(Icons.delete_outline, color: StatusColors.danger), title: Text('Delete bill')),
                  ),
              ],
            ),
          ],
        ],
      ),
      bottomNavigationBar: b == null || b.isDraft || b.balanceDue <= 0.005
          ? null
          : SaveBar(
              label: 'Pay vendor',
              leading: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('To pay', style: context.text.labelSmall),
                  Text(money(b.balanceDue),
                      style: context.text.titleMedium?.copyWith(color: StatusColors.danger, fontWeight: FontWeight.w700)),
                ],
              ),
              onPressed: () => context.push('/payments-out/new?party=${b.partyId}&bill=${b.id}'),
            ),
      body: async.when(
        loading: () => const SkeletonList(count: 6),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(purchaseBillProvider(billId))),
        data: (b) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(purchaseBillProvider(billId)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.sm, Spacing.lg, Spacing.xxl),
            children: [ContentWidth(child: _Body(bill: b))],
          ),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.bill});
  final PurchaseBill bill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = bill;
    final payments = ref.watch(_billPaymentsProvider(b.id));
    final progress = b.totalAmount <= 0 ? 0.0 : (b.paidAmount / b.totalAmount).clamp(0.0, 1.0);
    final (stockKey, stockLabel) = _stockStatus(b.stockStatus);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Spacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Expanded(child: Text(b.vendorName, style: context.text.titleMedium)),
                  StatusChip(b.status),
                ]),
                const SizedBox(height: Spacing.md),
                Text(money(b.totalAmount), style: context.text.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: Spacing.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    color: StatusColors.success,
                    backgroundColor: context.colors.surfaceContainerHigh,
                  ),
                ),
                const SizedBox(height: Spacing.xs),
                Text('${money(b.paidAmount)} paid · ${money(b.balanceDue)} to pay', style: context.text.bodySmall),
                const Divider(height: Spacing.xl),
                Wrap(spacing: Spacing.xl, runSpacing: Spacing.sm, children: [
                  _Meta('Bill date', dateText(b.date)),
                  _Meta('Due date', b.dueDate == null ? '—' : dateText(b.dueDate)),
                  if (b.paymentMode.isNotEmpty && b.paymentMode != 'unpaid') _Meta('Mode', PaymentMode.labelOf(b.paymentMode)),
                ]),
                const SizedBox(height: Spacing.md),
                Align(alignment: Alignment.centerLeft, child: StatusChip(stockKey, label: stockLabel)),
              ],
            ),
          ),
        ),
        const SizedBox(height: Spacing.lg),
        DocItemsCard(lines: b.items, showTax: !b.taxExempt),
        const SizedBox(height: Spacing.lg),
        SectionCard(
          title: 'Summary',
          child: Column(children: [
            KeyValueRow('Subtotal', money(b.subTotal)),
            if (b.lineDiscounts > 0.005) KeyValueRow('Item discounts', '− ${money(b.lineDiscounts)}'),
            if (b.taxTotal > 0) KeyValueRow('GST', money(b.taxTotal)),
            if (b.taxExempt) const KeyValueRow('GST', 'Exempt'),
            if (b.invoiceDiscount > 0) KeyValueRow('Bill discount', '− ${money(b.invoiceDiscount)}'),
            if (b.additionalCharges > 0) KeyValueRow('Additional charges', money(b.additionalCharges)),
            const Divider(height: Spacing.lg),
            KeyValueRow('Total', money(b.totalAmount), bold: true),
            KeyValueRow('Paid', money(b.paidAmount), valueColor: StatusColors.success),
            KeyValueRow('To pay', money(b.balanceDue), bold: true, valueColor: b.balanceDue > 0.005 ? StatusColors.danger : null),
          ]),
        ),
        const SizedBox(height: Spacing.lg),
        SectionCard(
          title: 'Payments made',
          padding: const EdgeInsets.fromLTRB(0, Spacing.xs, 0, Spacing.sm),
          child: payments.when(
            loading: () => const Padding(padding: EdgeInsets.all(Spacing.lg), child: LinearProgressIndicator()),
            error: (e, _) => Padding(padding: const EdgeInsets.all(Spacing.lg), child: Text(errorMessage(e))),
            data: (list) => list.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(Spacing.lg),
                    child: Text('No payments recorded against this bill.', style: context.text.bodySmall),
                  )
                : Column(children: [
                    for (final p in list)
                      ListTile(
                        dense: true,
                        leading: Icon(Icons.call_made_rounded, color: p.isCancelled ? StatusColors.neutral : StatusColors.danger),
                        title: Text('${p.number.isEmpty ? 'Payment' : p.number} · ${PaymentMode.labelOf(p.mode)}'),
                        subtitle: Text(dateText(p.date)),
                        trailing: Text(money(p.amount),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              decoration: p.isCancelled ? TextDecoration.lineThrough : null,
                            )),
                      ),
                  ]),
          ),
        ),
        if (b.notes.isNotEmpty) ...[
          const SizedBox(height: Spacing.lg),
          SectionCard(title: 'Notes', child: Text(b.notes)),
        ],
        const SizedBox(height: Spacing.lg),
        Text('Editing bills is available on the TruERP web app.', style: context.text.bodySmall, textAlign: TextAlign.center),
      ],
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [Text(label, style: context.text.labelSmall), Text(value, style: context.text.bodyMedium)],
      );
}
