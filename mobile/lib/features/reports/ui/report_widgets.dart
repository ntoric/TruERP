import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/utils/share_utils.dart';
import '../../../shared/widgets/common.dart';
import '../data/report_period.dart';
import '../data/reports_repository.dart';

const reportsAccent = Color(0xFF9333EA);

/// Period kind chips plus a ‹ label › stepper. Custom opens a range picker.
class PeriodBar extends StatelessWidget {
  const PeriodBar({
    super.key,
    required this.period,
    required this.onChanged,
    this.serverLabel,
    this.kinds = PeriodKind.values,
  });
  final ReportPeriod period;
  final ValueChanged<ReportPeriod> onChanged;

  /// The server's own label for the period, once loaded.
  final String? serverLabel;
  final List<PeriodKind> kinds;

  Future<void> _custom(BuildContext context) async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2015),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: period.kind == PeriodKind.custom && period.start != null
          ? DateTimeRange(
              start: period.start!,
              end: period.end ?? period.start!,
            )
          : null,
    );
    if (r != null) onChanged(period.custom(r.start, r.end));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final k in kinds) ...[
                ChoiceChip(
                  label: Text(k.label),
                  selected: period.kind == k,
                  onSelected: (_) => k == PeriodKind.custom
                      ? _custom(context)
                      : onChanged(period.withKind(k)),
                ),
                const SizedBox(width: Spacing.sm),
              ],
            ],
          ),
        ),
        const SizedBox(height: Spacing.sm),
        Card(
          child: Row(
            children: [
              IconButton(
                tooltip: 'Previous',
                onPressed: period.canShift
                    ? () => onChanged(period.shift(-1))
                    : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: InkWell(
                  onTap: period.kind == PeriodKind.custom
                      ? () => _custom(context)
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: Spacing.md),
                    child: Text(
                      (serverLabel?.isNotEmpty ?? false)
                          ? serverLabel!
                          : period.label,
                      textAlign: TextAlign.center,
                      style: context.text.titleSmall,
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Next',
                onPressed: period.canShift && !period.isCurrent
                    ? () => onChanged(period.shift(1))
                    : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// AppBar action that downloads a server export (PDF / Excel / CSV) and shares it.
class ExportMenu extends ConsumerWidget {
  const ExportMenu({
    super.key,
    required this.exports,
    required this.query,
    required this.baseName,
  });
  final List<ReportExport> exports;
  final Map<String, dynamic> query;
  final String baseName;

  static String _label(String ext) => switch (ext) {
    'pdf' => 'Share PDF',
    'xlsx' => 'Share Excel',
    _ => 'Share CSV',
  };
  static IconData _icon(String ext) => switch (ext) {
    'pdf' => Icons.picture_as_pdf_outlined,
    'xlsx' => Icons.table_chart_outlined,
    _ => Icons.description_outlined,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<ReportExport>(
      tooltip: 'Share',
      icon: const Icon(Icons.ios_share_rounded),
      onSelected: (e) {
        final (path, ext, mime) = e;
        final stamp = query['start_date'] ?? query['date'] ?? '';
        shareFile(
          context,
          ref.read(apiClientProvider),
          path,
          '${baseName}_$stamp.$ext',
          query: query,
          mimeType: mime,
        );
      },
      itemBuilder: (_) => [
        for (final e in exports)
          PopupMenuItem(
            value: e,
            child: ListTile(
              leading: Icon(_icon(e.$2)),
              title: Text(_label(e.$2)),
            ),
          ),
      ],
    );
  }
}

/// Scrollable report body with pull-to-refresh and a readable max width.
class ReportBody extends StatelessWidget {
  const ReportBody({
    super.key,
    required this.onRefresh,
    required this.children,
    this.maxWidth = 900,
  });
  final Future<void> Function() onRefresh;
  final List<Widget> children;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: onRefresh,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(
        Spacing.lg,
        Spacing.sm,
        Spacing.lg,
        Spacing.xxl,
      ),
      children: [
        ContentWidth(
          maxWidth: maxWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
    ),
  );
}

/// Loading / error placeholder used inside report bodies.
Widget reportLoading() =>
    const SizedBox(height: 320, child: SkeletonList(count: 5));

/// "Label ........ ₹amount (n)" row with optional colour and emphasis.
class AmountLine extends StatelessWidget {
  const AmountLine(
    this.label,
    this.amount, {
    super.key,
    this.count,
    this.color,
    this.bold = false,
    this.negative = false,
    this.indent = false,
  });
  final String label;
  final double amount;
  final int? count;
  final Color? color;
  final bool bold;

  /// Shown with a minus sign (deductions).
  final bool negative;
  final bool indent;

  @override
  Widget build(BuildContext context) {
    final style = bold ? context.text.titleSmall : context.text.bodyMedium;
    return Padding(
      padding: EdgeInsets.only(
        top: 5,
        bottom: 5,
        left: indent ? Spacing.lg : 0,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: label,
                    style: bold
                        ? style
                        : style?.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                  ),
                  if (count != null && count! > 0)
                    TextSpan(
                      text: '  ($count)',
                      style: context.text.labelSmall,
                    ),
                ],
              ),
            ),
          ),
          Text(
            '${negative && amount != 0 ? '− ' : ''}${money(amount)}',
            style: style?.copyWith(
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Big headline figure card (e.g. Net profit).
class HeadlineCard extends StatelessWidget {
  const HeadlineCard({
    super.key,
    required this.label,
    required this.amount,
    this.caption,
    this.signed = true,
  });
  final String label;
  final double amount;
  final String? caption;

  /// Colour green/red by sign.
  final bool signed;

  @override
  Widget build(BuildContext context) {
    final color = !signed
        ? null
        : amount >= 0
        ? StatusColors.success
        : StatusColors.danger;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: context.text.titleMedium),
                  if (caption != null)
                    Text(caption!, style: context.text.bodySmall),
                ],
              ),
            ),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  money(amount),
                  style: context.text.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontal share bar for ranked rows.
class ShareBar extends StatelessWidget {
  const ShareBar({
    super.key,
    required this.fraction,
    this.color = reportsAccent,
  });
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(99),
    child: LinearProgressIndicator(
      value: fraction.clamp(0, 1).toDouble(),
      minHeight: 5,
      color: color,
      backgroundColor: context.colors.surfaceContainerHigh,
    ),
  );
}
