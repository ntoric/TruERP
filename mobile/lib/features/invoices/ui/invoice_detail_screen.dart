import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/api/revision.dart';
import '../../../core/models/invoice.dart';
import '../../../core/models/payment.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/utils/share_utils.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/form_widgets.dart';
import '../../payments/data/payments_repository.dart';
import '../data/invoices_repository.dart';

final _invoicePaymentsProvider = FutureProvider.autoDispose.family<List<PaymentIn>, String>((ref, id) async {
  ref.watch(dataRevisionProvider);
  final page = await ref.watch(paymentsRepositoryProvider).list(invoiceId: id);
  return page.items;
});

class InvoiceDetailScreen extends ConsumerWidget {
  const InvoiceDetailScreen({super.key, required this.invoiceId, this.embedded = false});
  final String invoiceId;
  final bool embedded;

  Future<void> _cancel(BuildContext context, WidgetRef ref, Invoice inv) async {
    final reason = await askReason(context, title: 'Cancel ${inv.number}?', confirmLabel: 'Cancel invoice');
    if (reason == null) return;
    try {
      await ref.read(invoicesRepositoryProvider).cancel(inv.id, reason);
      ref.invalidate(invoiceProvider(inv.id));
      ref.invalidate(invoiceHistoryProvider(inv.id));
      ref.read(dataRevisionProvider.notifier).bump();
      if (context.mounted) showSnack(context, '${inv.number} cancelled');
    } catch (e) {
      if (context.mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  Future<void> _whatsapp(BuildContext context, WidgetRef ref, Invoice inv) async {
    try {
      await ref.read(invoicesRepositoryProvider).sendWhatsApp(inv.id, phone: inv.party?.phone);
      if (context.mounted) showSnack(context, 'Invoice sent on WhatsApp');
    } on ApiException catch (e) {
      if (!context.mounted) return;
      // Server-side WhatsApp may not be configured; fall back to the app.
      final phone = inv.party?.phone ?? '';
      if (phone.isNotEmpty) {
        await openWhatsApp(context, phone,
            text: 'Hi ${inv.partyName}, your invoice ${inv.number} for ${money(inv.totalAmount)} is ready. '
                'Balance due: ${money(inv.balanceDue)}.');
      } else {
        showSnack(context, e.message, error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(invoiceProvider(invoiceId));
    final inv = async.asData?.value;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !embedded,
        title: Text(inv?.number ?? 'Invoice'),
        actions: [
          if (inv != null) ...[
            IconButton(
              tooltip: 'Share PDF',
              icon: const Icon(Icons.ios_share_rounded),
              onPressed: () => sharePdf(context, ref.read(apiClientProvider), '/invoices/${inv.id}/pdf', 'Invoice_${inv.number}.pdf'),
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'wa') _whatsapp(context, ref, inv);
                if (v == 'cancel') _cancel(context, ref, inv);
                if (v == 'party' && inv.party != null) context.push('/parties/${inv.party!.id}');
                if (v == 'return') context.push('/sales-returns/new?invoice=${inv.id}');
                if (v == 'credit') context.push('/credit-notes/new?invoice=${inv.id}');
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'wa', child: ListTile(leading: Icon(Icons.chat_outlined), title: Text('Send on WhatsApp'))),
                if (inv.party != null)
                  const PopupMenuItem(value: 'party', child: ListTile(leading: Icon(Icons.person_outline), title: Text('Open customer'))),
                if (!inv.isCancelled && inv.items.isNotEmpty) ...[
                  const PopupMenuItem(value: 'return', child: ListTile(leading: Icon(Icons.assignment_return_outlined), title: Text('Return items'))),
                  const PopupMenuItem(value: 'credit', child: ListTile(leading: Icon(Icons.note_add_outlined), title: Text('Credit note'))),
                ],
                if (!inv.isCancelled)
                  const PopupMenuItem(
                    value: 'cancel',
                    child: ListTile(leading: Icon(Icons.block_rounded, color: StatusColors.danger), title: Text('Cancel invoice')),
                  ),
              ],
            ),
          ],
        ],
      ),
      bottomNavigationBar: inv == null || inv.isCancelled || inv.balanceDue <= 0.005
          ? null
          : SaveBar(
              label: 'Record payment',
              leading: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Balance due', style: context.text.labelSmall),
                  Text(money(inv.balanceDue),
                      style: context.text.titleMedium?.copyWith(color: StatusColors.danger, fontWeight: FontWeight.w700)),
                ],
              ),
              onPressed: () => context.push('/payments-in/new?party=${inv.partyId}&invoice=${inv.id}'),
            ),
      body: async.when(
        loading: () => const SkeletonList(count: 6),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(invoiceProvider(invoiceId))),
        data: (inv) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(invoiceProvider(invoiceId));
            ref.invalidate(_invoicePaymentsProvider(invoiceId));
            ref.invalidate(invoiceHistoryProvider(invoiceId));
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.sm, Spacing.lg, Spacing.xxl),
            children: [ContentWidth(child: _Body(invoice: inv))],
          ),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.invoice});
  final Invoice invoice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inv = invoice;
    final payments = ref.watch(_invoicePaymentsProvider(inv.id));
    final history = ref.watch(invoiceHistoryProvider(inv.id));
    final progress = inv.totalAmount <= 0 ? 0.0 : (inv.amountPaid / inv.totalAmount).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (inv.isCancelled)
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.md),
            child: ErrorBanner('Cancelled${inv.cancelReason.isEmpty ? '' : ': ${inv.cancelReason}'}'),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Spacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(inv.partyName, style: context.text.titleMedium),
                          if ((inv.party?.phone ?? '').isNotEmpty) Text(inv.party!.phone, style: context.text.bodySmall),
                        ],
                      ),
                    ),
                    StatusChip(inv.status, label: inv.status == 'sent' ? 'Unpaid' : null),
                  ],
                ),
                const SizedBox(height: Spacing.md),
                Text(money(inv.totalAmount),
                    style: context.text.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      decoration: inv.isCancelled ? TextDecoration.lineThrough : null,
                    )),
                const SizedBox(height: Spacing.sm),
                if (!inv.isCancelled) ...[
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
                  Text('${money(inv.amountPaid)} received · ${money(inv.balanceDue)} due', style: context.text.bodySmall),
                ],
                const Divider(height: Spacing.xl),
                Row(children: [
                  Expanded(child: _Meta('Invoice date', dateText(inv.date))),
                  Expanded(child: _Meta('Due date', inv.dueDate == null ? '—' : dateText(inv.dueDate))),
                  if (inv.paymentMode.isNotEmpty && inv.paymentMode != 'unpaid')
                    Expanded(child: _Meta('Mode', PaymentMode.labelOf(inv.paymentMode))),
                ]),
              ],
            ),
          ),
        ),
        const SizedBox(height: Spacing.lg),
        SectionCard(
          title: 'Items (${inv.items.length})',
          padding: const EdgeInsets.fromLTRB(0, Spacing.xs, 0, Spacing.sm),
          child: Column(
            children: [
              for (final it in inv.items)
                ListTile(
                  dense: true,
                  title: Text(it.description, style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text([
                    '${qty(it.quantity)}${it.unit.isEmpty ? '' : ' ${it.unit}'} × ${money(it.unitPrice)}',
                    if (it.discount > 0) '${qty(it.discount)}% off',
                  ].join(' · ')),
                  trailing: Text(money(it.total), style: context.text.labelLarge),
                ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.lg),
        SectionCard(
          title: 'Summary',
          child: Column(children: [
            KeyValueRow('Subtotal', money(inv.subTotal)),
            if (inv.discountTotal > 0) KeyValueRow('Item discounts', '− ${money(inv.discountTotal)}'),
            if (inv.invoiceDiscount > 0) KeyValueRow('Invoice discount', '− ${money(inv.invoiceDiscount)}'),
            if (inv.loyaltyDiscount > 0) KeyValueRow('Loyalty', '− ${money(inv.loyaltyDiscount)}'),
            if (inv.taxTotal > 0) KeyValueRow('Tax', money(inv.taxTotal)),
            if (inv.additionalCharges > 0) KeyValueRow('Additional charges', money(inv.additionalCharges)),
            if (inv.roundOff.abs() >= 0.005) KeyValueRow('Round off', money(inv.roundOff)),
            const Divider(height: Spacing.lg),
            KeyValueRow('Total', money(inv.totalAmount), bold: true),
            KeyValueRow('Received', money(inv.amountPaid), valueColor: StatusColors.success),
            if (!inv.isCancelled)
              KeyValueRow('Balance due', money(inv.balanceDue), bold: true,
                  valueColor: inv.balanceDue > 0.005 ? StatusColors.danger : null),
          ]),
        ),
        const SizedBox(height: Spacing.lg),
        SectionCard(
          title: 'Payments',
          padding: const EdgeInsets.fromLTRB(0, Spacing.xs, 0, Spacing.sm),
          child: payments.when(
            loading: () => const Padding(padding: EdgeInsets.all(Spacing.lg), child: LinearProgressIndicator()),
            error: (e, _) => Padding(padding: const EdgeInsets.all(Spacing.lg), child: Text(errorMessage(e))),
            data: (list) => list.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(Spacing.lg),
                    child: Text('No payments recorded against this invoice.', style: context.text.bodySmall),
                  )
                : Column(children: [
                    for (final p in list)
                      ListTile(
                        dense: true,
                        leading: Icon(Icons.call_received_rounded,
                            color: p.isCancelled ? StatusColors.neutral : StatusColors.success),
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
        if (inv.notes.isNotEmpty || inv.terms.isNotEmpty) ...[
          const SizedBox(height: Spacing.lg),
          SectionCard(
            title: 'Notes & terms',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (inv.notes.isNotEmpty) Text(inv.notes),
                if (inv.notes.isNotEmpty && inv.terms.isNotEmpty) const SizedBox(height: Spacing.sm),
                if (inv.terms.isNotEmpty) Text(inv.terms, style: context.text.bodySmall),
              ],
            ),
          ),
        ],
        const SizedBox(height: Spacing.lg),
        history.maybeWhen(
          data: (h) => h.isEmpty
              ? const SizedBox.shrink()
              : SectionCard(
                  title: 'Activity',
                  child: Column(children: [
                    for (final e in h)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.circle, size: 8, color: StatusChip.colorFor(e.to)),
                            const SizedBox(width: Spacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(e.note.isNotEmpty ? e.note : 'Status → ${titleCase(e.to)}'),
                                  Text([dateTimeText(e.at), if (e.by.isNotEmpty) e.by].join(' · '),
                                      style: context.text.labelSmall),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ]),
                ),
          orElse: () => const SizedBox.shrink(),
        ),
        if (inv.isPos) ...[
          const SizedBox(height: Spacing.md),
          Text('Billed from POS', style: context.text.bodySmall, textAlign: TextAlign.center),
        ],
        const SizedBox(height: Spacing.lg),
        Text('Editing invoices is available on the TruERP web app.',
            style: context.text.bodySmall, textAlign: TextAlign.center),
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
        children: [Text(label, style: context.text.labelSmall), Text(value, style: context.text.bodyMedium)],
      );
}
