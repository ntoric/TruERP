import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/api/revision.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/models/reports.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/doc_widgets.dart';
import '../data/reports_repository.dart';
import 'report_widgets.dart';

String _monthKey(DateTime m) =>
    '${m.year}-${m.month.toString().padLeft(2, '0')}';

final _summaryProvider = FutureProvider.autoDispose.family<GstSummary, String>((
  ref,
  m,
) {
  ref.watch(activeStoreIdProvider);
  ref.watch(dataRevisionProvider);
  return ref.watch(reportsRepositoryProvider).gstSummary(m);
});
final _gstr1Provider = FutureProvider.autoDispose
    .family<List<GstReturnRow>, String>((ref, m) {
      ref.watch(activeStoreIdProvider);
      return ref.watch(reportsRepositoryProvider).gstr1(m);
    });
final _gstr2Provider = FutureProvider.autoDispose
    .family<List<GstReturnRow>, String>((ref, m) {
      ref.watch(activeStoreIdProvider);
      return ref.watch(reportsRepositoryProvider).gstr2(m);
    });
final _gstr3bProvider = FutureProvider.autoDispose.family<Gstr3b, String>((
  ref,
  m,
) {
  ref.watch(activeStoreIdProvider);
  return ref.watch(reportsRepositoryProvider).gstr3b(m);
});
final _eDocsProvider =
    FutureProvider.autoDispose<(List<GstDocRow>, List<GstDocRow>)>((ref) async {
      ref.watch(activeStoreIdProvider);
      final repo = ref.watch(reportsRepositoryProvider);
      final r = await Future.wait([repo.eInvoices(), repo.eWayBills()]);
      return (r[0], r[1]);
    });

enum _Section { gstr1, gstr3b, gstr2, edocs }

class GstScreen extends ConsumerStatefulWidget {
  const GstScreen({super.key});

  @override
  ConsumerState<GstScreen> createState() => _State();
}

class _State extends ConsumerState<GstScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  _Section _section = _Section.gstr3b;

  bool get _isCurrent =>
      _month.year == DateTime.now().year &&
      _month.month == DateTime.now().month;

  @override
  Widget build(BuildContext context) {
    final key = _monthKey(_month);
    final summary = ref.watch(_summaryProvider(key));
    return Scaffold(
      appBar: AppBar(title: const Text('GST')),
      body: ReportBody(
        onRefresh: () async {
          ref.invalidate(_summaryProvider(key));
          ref.invalidate(_gstr1Provider(key));
          ref.invalidate(_gstr2Provider(key));
          ref.invalidate(_gstr3bProvider(key));
          ref.invalidate(_eDocsProvider);
        },
        children: [
          Card(
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Previous month',
                  onPressed: () => setState(
                    () => _month = DateTime(_month.year, _month.month - 1),
                  ),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    DateFormat('MMMM yyyy').format(_month),
                    textAlign: TextAlign.center,
                    style: context.text.titleSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Next month',
                  onPressed: _isCurrent
                      ? null
                      : () => setState(
                          () =>
                              _month = DateTime(_month.year, _month.month + 1),
                        ),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.lg),
          summary.when(
            loading: () =>
                const SizedBox(height: 160, child: SkeletonList(count: 2)),
            error: (e, _) => ErrorView(
              error: e,
              onRetry: () => ref.invalidate(_summaryProvider(key)),
            ),
            data: (s) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SummaryStrip(
                  cells: [
                    ('Output GST', s.totalTax, null),
                    ('Input credit', s.itc, StatusColors.success),
                    (
                      'Net liability',
                      s.liability,
                      s.liability > 0
                          ? StatusColors.danger
                          : StatusColors.success,
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.md),
                SectionCard(
                  title: 'Summary',
                  child: Column(
                    children: [
                      AmountLine('Sales', s.totalSales),
                      AmountLine('Taxable sales', s.salesTaxable, indent: true),
                      AmountLine('CGST', s.cgst, indent: true),
                      AmountLine('SGST', s.sgst, indent: true),
                      AmountLine('IGST', s.igst, indent: true),
                      AmountLine('Purchases', s.totalPurchases),
                      AmountLine(
                        'Taxable purchases',
                        s.purchaseTaxable,
                        indent: true,
                      ),
                      AmountLine(
                        'GST paid on purchases',
                        s.purchaseTax,
                        indent: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.lg),
          SegmentedButton<_Section>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: _Section.gstr3b, label: Text('3B')),
              ButtonSegment(value: _Section.gstr1, label: Text('GSTR-1')),
              ButtonSegment(value: _Section.gstr2, label: Text('GSTR-2')),
              ButtonSegment(value: _Section.edocs, label: Text('E-docs')),
            ],
            selected: {_section},
            onSelectionChanged: (s) => setState(() => _section = s.first),
          ),
          const SizedBox(height: Spacing.md),
          switch (_section) {
            _Section.gstr3b => _Gstr3bView(month: key),
            _Section.gstr1 => _ReturnRows(
              value: ref.watch(_gstr1Provider(key)),
              empty: 'No sales invoices this month.',
              note: 'Outward supplies from sales invoices.',
            ),
            _Section.gstr2 => _ReturnRows(
              value: ref.watch(_gstr2Provider(key)),
              empty: 'No purchase receipts this month.',
              note:
                  'Built from purchase receipts (goods received notes), not purchase bills.',
            ),
            _Section.edocs => const _EDocs(),
          },
          const SizedBox(height: Spacing.lg),
          Text(
            'Filing and e-invoice generation are done from the TruERP web app.',
            style: context.text.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Gstr3bView extends ConsumerWidget {
  const _Gstr3bView({required this.month});
  final String month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(_gstr3bProvider(month))
        .when(
          loading: reportLoading,
          error: (e, _) => ErrorView(
            error: e,
            onRetry: () => ref.invalidate(_gstr3bProvider(month)),
          ),
          data: (g) => SectionCard(
            title: 'GSTR-3B',
            child: Column(
              children: [
                AmountLine('IGST liability', g.igst),
                AmountLine('CGST liability', g.cgst),
                AmountLine('SGST liability', g.sgst),
                AmountLine('Total liability', g.liability, bold: true),
                AmountLine(
                  'Input tax credit',
                  g.itc,
                  negative: true,
                  color: StatusColors.success,
                ),
                const Divider(height: Spacing.lg),
                AmountLine(
                  'Tax payable',
                  g.payable,
                  bold: true,
                  color: g.payable > 0
                      ? StatusColors.danger
                      : StatusColors.success,
                ),
              ],
            ),
          ),
        );
  }
}

class _ReturnRows extends StatelessWidget {
  const _ReturnRows({
    required this.value,
    required this.empty,
    required this.note,
  });
  final AsyncValue<List<GstReturnRow>> value;
  final String empty;
  final String note;

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: reportLoading,
      error: (e, _) => ErrorView(error: e),
      data: (rows) {
        final taxable = rows.fold<double>(0, (s, r) => s + r.taxable);
        final tax = rows.fold<double>(0, (s, r) => s + r.tax);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(note, style: context.text.bodySmall),
            const SizedBox(height: Spacing.sm),
            SummaryStrip(
              cells: [('Taxable value', taxable, null), ('Tax', tax, null)],
            ),
            const SizedBox(height: Spacing.md),
            SectionCard(
              title: 'Documents (${rows.length})',
              padding: const EdgeInsets.only(bottom: Spacing.xs),
              child: rows.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(Spacing.lg),
                      child: Text(empty),
                    )
                  : Column(
                      children: [
                        for (final r in rows.take(200))
                          ListTile(
                            dense: true,
                            title: Text(
                              r.partyName.isEmpty ? r.number : r.partyName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              [
                                r.number,
                                dateShort(r.date),
                                if (r.gstin.isNotEmpty) r.gstin else 'B2C',
                              ].join(' · '),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  money(r.value),
                                  style: context.text.labelLarge,
                                ),
                                Text(
                                  'Tax ${moneyShort(r.tax)}',
                                  style: context.text.labelSmall,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _EDocs extends ConsumerWidget {
  const _EDocs();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(_eDocsProvider)
        .when(
          loading: reportLoading,
          error: (e, _) => ErrorView(
            error: e,
            onRetry: () => ref.invalidate(_eDocsProvider),
          ),
          data: (d) {
            final (einv, ewb) = d;
            Widget list(
              String title,
              List<GstDocRow> rows,
              String emptyText,
              String refLabel,
              String dateLabel,
            ) => SectionCard(
              title: '$title (${rows.length})',
              padding: const EdgeInsets.only(bottom: Spacing.xs),
              child: rows.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(Spacing.lg),
                      child: Text(emptyText),
                    )
                  : Column(
                      children: [
                        for (final r in rows.take(100))
                          ListTile(
                            dense: true,
                            onTap: r.invoiceId.isEmpty
                                ? null
                                : () =>
                                      context.push('/invoices/${r.invoiceId}'),
                            title: Text(r.invoiceNumber),
                            subtitle: Text(
                              '$refLabel ${r.reference.length > 18 ? '${r.reference.substring(0, 18)}…' : r.reference}'
                              '${r.date == null ? '' : ' · $dateLabel ${dateShort(r.date)}'}',
                            ),
                            trailing: StatusChip(
                              r.status == 'generated' ? 'active' : r.status,
                              label: titleCase(r.status),
                            ),
                          ),
                      ],
                    ),
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                list(
                  'E-invoices',
                  einv,
                  'No e-invoices generated yet.',
                  'IRN',
                  'on',
                ),
                const SizedBox(height: Spacing.md),
                list(
                  'E-way bills',
                  ewb,
                  'No e-way bills generated yet.',
                  'EWB',
                  'valid till',
                ),
              ],
            );
          },
        );
  }
}
