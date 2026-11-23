import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/revision.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/models/invoice.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/master_detail.dart';
import '../../../shared/widgets/paged_list.dart';
import '../../shell/account_sheet.dart';
import '../data/invoices_repository.dart';
import 'invoice_detail_screen.dart';

const salesAccent = Color(0xFF2563EB);

/// Status filters; "Unpaid" maps to the backend's `sent` status.
const _statusFilters = <(String?, String)>[
  (null, 'All'),
  ('sent', 'Unpaid'),
  ('partial', 'Partial'),
  ('overdue', 'Overdue'),
  ('paid', 'Paid'),
  ('cancelled', 'Cancelled'),
];

class InvoicesScreen extends ConsumerStatefulWidget {
  const InvoicesScreen({super.key, this.isTab = false});
  final bool isTab;

  @override
  ConsumerState<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends ConsumerState<InvoicesScreen> {
  String? _status;
  String _q = '';
  DateTimeRange? _range;
  String? _selected;

  void _open(Invoice inv) {
    if (MasterDetail.isSplit(context)) {
      setState(() => _selected = inv.id);
    } else {
      context.push('/invoices/${inv.id}');
    }
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2015),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _range,
    );
    if (picked != null) setState(() => _range = picked);
  }

  @override
  Widget build(BuildContext context) {
    final rev = ref.watch(dataRevisionProvider);
    final store = ref.watch(activeStoreIdProvider);
    final repo = ref.read(invoicesRepositoryProvider);

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.lg,
        Spacing.sm,
        Spacing.lg,
        Spacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _StatsStrip(),
          const SizedBox(height: Spacing.md),
          Row(
            children: [
              Expanded(
                child: SearchField(
                  hint: 'Search number or customer',
                  onChanged: (v) => setState(() => _q = v),
                ),
              ),
              const SizedBox(width: Spacing.sm),
              IconButton.outlined(
                tooltip: 'Date range',
                isSelected: _range != null,
                onPressed: _pickRange,
                icon: const Icon(Icons.date_range_rounded),
              ),
            ],
          ),
          if (_range != null)
            Padding(
              padding: const EdgeInsets.only(top: Spacing.sm),
              child: Align(
                alignment: Alignment.centerLeft,
                child: InputChip(
                  label: Text(
                    '${dateShort(_range!.start)} – ${dateShort(_range!.end)}',
                  ),
                  onDeleted: () => setState(() => _range = null),
                  onPressed: _pickRange,
                ),
              ),
            ),
          const SizedBox(height: Spacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final (value, label) in _statusFilters) ...[
                  ChoiceChip(
                    label: Text(label),
                    selected: _status == value,
                    onSelected: (_) => setState(() => _status = value),
                  ),
                  const SizedBox(width: Spacing.sm),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    final list = PagedListView<Invoice>(
      resetKey: (_status, _q, _range, rev, store),
      fetch: (page) => repo.list(
        page: page,
        search: _q,
        status: _status,
        from: _range?.start,
        to: _range?.end,
      ),
      header: header,
      empty: EmptyState(
        icon: Icons.receipt_long_rounded,
        title: _status == null && _q.isEmpty && _range == null
            ? 'No invoices yet'
            : 'No matching invoices',
        message: _status == null && _q.isEmpty && _range == null
            ? 'Create your first invoice to start tracking sales.'
            : null,
        action: _status == null && _q.isEmpty && _range == null
            ? FilledButton.icon(
                onPressed: () => context.push('/invoices/new'),
                icon: const Icon(Icons.add_rounded),
                label: const Text('New invoice'),
              )
            : null,
      ),
      itemBuilder: (ctx, inv, _) => InvoiceTile(
        invoice: inv,
        selected: inv.id == _selected,
        onTap: () => _open(inv),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isTab ? 'Sales' : 'Invoices'),
        automaticallyImplyLeading: !widget.isTab,
        actions: [
          if (widget.isTab)
            IconButton(
              tooltip: 'Payments received',
              icon: const Icon(Icons.call_received_rounded),
              onPressed: () => context.push('/payments-in'),
            ),
          if (widget.isTab) const AccountButton(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new-invoice',
        onPressed: () => context.push('/invoices/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New invoice'),
      ),
      body: MasterDetail(
        list: list,
        detail: _selected == null
            ? null
            : InvoiceDetailScreen(
                key: ValueKey(_selected),
                invoiceId: _selected!,
                embedded: true,
              ),
      ),
    );
  }
}

class _StatsStrip extends ConsumerWidget {
  const _StatsStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(dataRevisionProvider);
    final s = ref.watch(invoiceStatsProvider).asData?.value;
    Widget cell(String label, double? v, Color c) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: context.text.labelSmall),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              v == null ? '—' : moneyShort(v),
              style: context.text.titleSmall?.copyWith(
                color: c,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg,
          vertical: Spacing.md,
        ),
        child: Row(
          children: [
            cell('Total sales', s?.totalSales, context.colors.onSurface),
            cell('Received', s?.paid, StatusColors.success),
            cell('Unpaid', s?.unpaid, StatusColors.danger),
          ],
        ),
      ),
    );
  }
}

class InvoiceTile extends StatelessWidget {
  const InvoiceTile({
    super.key,
    required this.invoice,
    required this.onTap,
    this.selected = false,
  });
  final Invoice invoice;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final inv = invoice;
    return ListTile(
      selected: selected,
      selectedTileColor: context.colors.primaryContainer.withValues(alpha: 0.5),
      onTap: onTap,
      leading: const IconBadge(Icons.receipt_long_rounded, color: salesAccent),
      title: Text(
        inv.partyName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        '${inv.number} · ${relativeDay(inv.date)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            money(inv.totalAmount),
            style: context.text.labelLarge?.copyWith(
              decoration: inv.isCancelled ? TextDecoration.lineThrough : null,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          StatusChip(inv.status, label: inv.status == 'sent' ? 'Unpaid' : null),
        ],
      ),
    );
  }
}
