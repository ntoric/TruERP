import 'package:flutter/material.dart';

import '../../core/models/purchase.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/formatters.dart';
import 'common.dart';
import 'paged_list.dart';

/// Row of headline figures (e.g. Total · Paid · Unpaid) at the top of a list.
class SummaryStrip extends StatelessWidget {
  const SummaryStrip({super.key, required this.cells, this.countCells = const {}});

  /// (label, amount or null while loading, colour or null for default).
  final List<(String, double?, Color?)> cells;

  /// Indices of cells that hold a plain count rather than money.
  final Set<int> countCells;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.md),
        child: Row(children: [
          for (final (i, (label, value, color)) in cells.indexed)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: context.text.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(value == null ? '—' : (countCells.contains(i) ? number(value) : moneyShort(value)),
                        style: context.text.titleSmall?.copyWith(
                            color: color ?? context.colors.onSurface, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
        ]),
      ),
    );
  }
}

/// Read-only list of saved document lines.
class DocItemsCard extends StatelessWidget {
  const DocItemsCard({super.key, required this.lines, this.showTax = false, this.showReceived = false});
  final List<DocLine> lines;
  final bool showTax;
  final bool showReceived;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Items (${lines.length})',
      padding: const EdgeInsets.fromLTRB(0, Spacing.xs, 0, Spacing.sm),
      child: Column(children: [
        for (final it in lines)
          ListTile(
            dense: true,
            title: Text(it.description, style: const TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text([
              '${qty(it.quantity)}${it.unit.isEmpty ? '' : ' ${it.unit}'} × ${money(it.unitPrice)}',
              if (it.discount > 0) '${qty(it.discount)}% off',
              if (showTax && it.taxRate > 0) 'GST ${qty(it.taxRate)}%',
              if (showReceived) 'received ${qty(it.receivedQty)}',
            ].join(' · ')),
            trailing: Text(money(it.total > 0 ? it.total : it.quantity * it.unitPrice), style: context.text.labelLarge),
          ),
      ]),
    );
  }
}

/// Header block for list screens: search, optional date range and chips.
class ListFilters extends StatelessWidget {
  const ListFilters({
    super.key,
    this.summary,
    required this.searchHint,
    required this.onSearch,
    this.chips = const [],
    this.range,
    this.onRange,
  });

  final Widget? summary;
  final String searchHint;
  final ValueChanged<String> onSearch;
  final List<Widget> chips;
  final DateTimeRange? range;

  /// Null hides the date-range button.
  final ValueChanged<DateTimeRange?>? onRange;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2015),
      lastDate: DateTime(now.year + 1),
      initialDateRange: range,
    );
    if (picked != null) onRange!(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.sm, Spacing.lg, Spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (summary != null) ...[summary!, const SizedBox(height: Spacing.md)],
          Row(children: [
            Expanded(child: SearchField(hint: searchHint, onChanged: onSearch)),
            if (onRange != null) ...[
              const SizedBox(width: Spacing.sm),
              IconButton.outlined(
                tooltip: 'Date range',
                isSelected: range != null,
                onPressed: () => _pick(context),
                icon: const Icon(Icons.date_range_rounded),
              ),
            ],
          ]),
          if (range != null && onRange != null)
            Padding(
              padding: const EdgeInsets.only(top: Spacing.sm),
              child: Align(
                alignment: Alignment.centerLeft,
                child: InputChip(
                  label: Text('${dateShort(range!.start)} – ${dateShort(range!.end)}'),
                  onDeleted: () => onRange!(null),
                  onPressed: () => _pick(context),
                ),
              ),
            ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: Spacing.sm),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final c in chips) ...[c, const SizedBox(width: Spacing.sm)],
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

/// Standard list row for a money document (invoice, bill, payment, expense).
class MoneyTile extends StatelessWidget {
  const MoneyTile({
    super.key,
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.onTap,
    this.status,
    this.statusLabel,
    this.amountColor,
    this.struck = false,
    this.selected = false,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final double amount;
  final VoidCallback onTap;
  final String? status;
  final String? statusLabel;
  final Color? amountColor;
  final bool struck;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      selected: selected,
      selectedTileColor: context.colors.primaryContainer.withValues(alpha: 0.5),
      onTap: onTap,
      leading: IconBadge(icon, color: struck ? StatusColors.neutral : accent),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(money(amount),
              style: context.text.labelLarge?.copyWith(
                color: struck ? null : amountColor,
                decoration: struck ? TextDecoration.lineThrough : null,
                fontFeatures: const [FontFeature.tabularFigures()],
              )),
          if (status != null) ...[const SizedBox(height: 2), StatusChip(status!, label: statusLabel)],
        ],
      ),
    );
  }
}

/// A horizontally scrolling row of filter chips, used as a list header.
class ChipsHeader extends StatelessWidget {
  const ChipsHeader({super.key, required this.chips, this.note});
  final List<Widget> chips;

  /// Optional hint shown above the chips.
  final String? note;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.sm, Spacing.lg, Spacing.sm),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (note != null) ...[Text(note!, style: context.text.bodySmall), const SizedBox(height: Spacing.sm)],
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [for (final c in chips) ...[c, const SizedBox(width: Spacing.sm)]]),
          ),
        ]),
      );
}
