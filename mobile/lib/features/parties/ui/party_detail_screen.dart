import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/api/revision.dart';
import '../../../core/models/party.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/utils/share_utils.dart';
import '../../../shared/widgets/common.dart';
import '../data/parties_repository.dart';

final _ledgerProvider = FutureProvider.autoDispose.family<PartyLedger, String>((ref, id) {
  ref.watch(dataRevisionProvider);
  return ref.watch(partiesRepositoryProvider).ledger(id);
});

class PartyDetailScreen extends ConsumerWidget {
  const PartyDetailScreen({super.key, required this.partyId, this.embedded = false, this.onDeleted});
  final String partyId;

  /// True when shown in the tablet detail pane (no back button).
  final bool embedded;
  final VoidCallback? onDeleted;

  Future<void> _delete(BuildContext context, WidgetRef ref, Party p) async {
    final ok = await confirmSheet(context,
        title: 'Delete ${p.name}?',
        message: 'Parties with invoices or payments can\'t be deleted.',
        confirmLabel: 'Delete',
        destructive: true);
    if (!ok) return;
    try {
      await ref.read(partiesRepositoryProvider).delete(p.id);
      ref.read(dataRevisionProvider.notifier).bump();
      if (!context.mounted) return;
      showSnack(context, '${p.name} deleted');
      if (embedded) {
        onDeleted?.call();
      } else {
        context.pop();
      }
    } catch (e) {
      if (context.mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(dataRevisionProvider);
    final async = ref.watch(partyProvider(partyId));
    final party = async.asData?.value;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !embedded,
        title: Text(party?.name ?? 'Party'),
        actions: [
          if (party != null) ...[
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push('/parties/${party.id}/edit'),
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'delete') _delete(context, ref, party);
                if (v == 'pdf') {
                  sharePdf(context, ref.read(apiClientProvider), '/parties/${party.id}/ledger/pdf', 'Ledger_${party.name}.pdf');
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'pdf', child: ListTile(leading: Icon(Icons.picture_as_pdf_outlined), title: Text('Share ledger PDF'))),
                PopupMenuItem(
                    value: 'delete',
                    child: ListTile(leading: Icon(Icons.delete_outline, color: StatusColors.danger), title: Text('Delete'))),
              ],
            ),
          ],
        ],
      ),
      body: async.when(
        loading: () => const SkeletonList(count: 6),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(partyProvider(partyId))),
        data: (p) => _Body(party: p),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.party});
  final Party party;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = party;
    final ledger = ref.watch(_ledgerProvider(p.id));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(partyProvider(p.id));
        ref.invalidate(_ledgerProvider(p.id));
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.sm, Spacing.lg, Spacing.xxl),
        children: [
          ContentWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HeaderCard(party: p),
                const SizedBox(height: Spacing.md),
                _Actions(party: p),
                const SizedBox(height: Spacing.lg),
                SectionCard(
                  title: 'Ledger',
                  padding: const EdgeInsets.fromLTRB(0, Spacing.sm, 0, Spacing.sm),
                  child: ledger.when(
                    loading: () => const SizedBox(height: 160, child: SkeletonList(count: 3)),
                    error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(_ledgerProvider(p.id))),
                    data: (l) => _LedgerView(ledger: l),
                  ),
                ),
                const SizedBox(height: Spacing.lg),
                _DetailsCard(party: p),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.party});
  final Party party;

  @override
  Widget build(BuildContext context) {
    final p = party;
    final color = p.toCollect ? StatusColors.success : p.toPay ? StatusColors.danger : StatusColors.neutral;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                InitialsAvatar(p.name, size: 52),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name, style: context.text.titleMedium),
                      const SizedBox(height: 4),
                      Wrap(spacing: 6, runSpacing: 4, children: [
                        StatusChip(p.isVendor ? 'info' : 'active', label: p.isVendor ? 'Vendor' : 'Customer'),
                        if (p.category.isNotEmpty) StatusChip('draft', label: p.category),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: Spacing.xl),
            // Balance gets its own line so large amounts never crowd the name.
            Row(
              children: [
                Expanded(
                  child: Text(p.toCollect ? 'To collect' : p.toPay ? 'To pay' : 'Balance',
                      style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant)),
                ),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(money(p.balance.abs()),
                        style: context.text.titleLarge?.copyWith(color: color, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.party});
  final Party party;

  @override
  Widget build(BuildContext context) {
    final p = party;
    // Icon above label so three fit side by side on narrow phones.
    Widget contact(IconData icon, String label, VoidCallback? onTap) => Expanded(
          child: OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20),
                const SizedBox(height: 2),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.labelSmall?.copyWith(
                  color: onTap == null ? null : context.colors.onSurface)),
              ],
            ),
          ),
        );
    return Column(
      children: [
        Row(children: [
          contact(Icons.call_outlined, 'Call', p.phone.isEmpty ? null : () => callPhone(context, p.phone)),
          const SizedBox(width: Spacing.sm),
          contact(Icons.chat_outlined, 'WhatsApp', p.phone.isEmpty ? null : () => openWhatsApp(context, p.phone)),
          const SizedBox(width: Spacing.sm),
          contact(Icons.mail_outline_rounded, 'Email', p.email.isEmpty ? null : () => sendEmail(context, p.email)),
        ]),
        const SizedBox(height: Spacing.sm),
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: () => context.push(p.isVendor ? '/purchases/new?party=${p.id}' : '/invoices/new?party=${p.id}'),
              icon: Icon(p.isVendor ? Icons.shopping_bag_rounded : Icons.receipt_long_rounded),
              label: Text(p.isVendor ? 'New purchase' : 'New invoice'),
            ),
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: FilledButton.tonalIcon(
              onPressed: () => context.push(p.isVendor ? '/payments-out/new?party=${p.id}' : '/payments-in/new?party=${p.id}'),
              icon: Icon(p.isVendor ? Icons.call_made_rounded : Icons.call_received_rounded),
              label: Text(p.isVendor ? 'Pay' : 'Receive'),
            ),
          ),
        ]),
      ],
    );
  }
}

class _LedgerView extends StatelessWidget {
  const _LedgerView({required this.ledger});
  final PartyLedger ledger;

  @override
  Widget build(BuildContext context) {
    if (ledger.entries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(Spacing.lg),
        child: Text('No transactions yet.'),
      );
    }
    // Newest first reads better on a phone.
    final entries = ledger.entries.reversed.toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
          child: Row(
            children: [
              Expanded(child: _Mini('Debit', money(ledger.totalDebit))),
              Expanded(child: _Mini('Credit', money(ledger.totalCredit))),
              Expanded(child: _Mini('Closing', money(ledger.closingBalance), bold: true)),
            ],
          ),
        ),
        const SizedBox(height: Spacing.sm),
        const Divider(),
        for (final e in entries.take(50))
          ListTile(
            dense: true,
            onTap: _ledgerRoute(e) == null ? null : () => context.push(_ledgerRoute(e)!),
            title: Text(e.voucher.isNotEmpty ? e.voucher : titleCase(e.type), style: const TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text([dateText(e.date), if (e.refNumber.isNotEmpty) e.refNumber, if (e.paymentMode.isNotEmpty) titleCase(e.paymentMode)].join(' · ')),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  e.debit > 0 ? '+ ${money(e.debit)}' : '− ${money(e.credit)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: e.debit > 0 ? StatusColors.success : StatusColors.danger,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text('Bal ${money(e.balance)}', style: context.text.labelSmall),
              ],
            ),
          ),
        if (entries.length > 50)
          Padding(
            padding: const EdgeInsets.all(Spacing.md),
            child: Text('Showing latest 50 of ${entries.length}. Share the ledger PDF for the full history.',
                style: context.text.bodySmall, textAlign: TextAlign.center),
          ),
      ],
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini(this.label, this.value, {this.bold = false});
  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: context.text.labelSmall),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: bold ? context.text.titleSmall : context.text.bodyMedium),
          ),
        ],
      );
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.party});
  final Party party;

  @override
  Widget build(BuildContext context) {
    final p = party;
    final rows = <(String, String)>[
      ('Phone', p.phone),
      ('Email', p.email),
      ('GSTIN', p.gstin),
      ('PAN', p.pan),
      ('Address', p.fullAddress),
      ('Opening balance', p.openingBalance == 0 ? '' : money(p.openingBalance)),
      ('Credit limit', p.creditLimit == 0 ? '' : money(p.creditLimit)),
      if (p.loyaltyPoints > 0) ('Loyalty points', number(p.loyaltyPoints)),
      ('Notes', p.notes),
    ].where((r) => r.$2.trim().isNotEmpty).toList();
    return SectionCard(
      title: 'Details',
      child: rows.isEmpty
          ? Text('No other details.', style: context.text.bodySmall)
          : Column(children: [for (final r in rows) KeyValueRow(r.$1, r.$2)]),
    );
  }
}

/// Screen for a ledger row's source document, if mobile has one.
String? _ledgerRoute(LedgerEntry e) {
  final id = e.refId;
  if (id == null || id.isEmpty) return null;
  return switch (e.type) {
    'invoice' => '/invoices/$id',
    'purchase_bill' => '/purchases/$id',
    'purchase_return' => '/purchase-returns/$id',
    'expense' => '/expenses/$id',
    _ => null,
  };
}
