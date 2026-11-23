import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/common.dart';

class _Report {
  const _Report(this.title, this.subtitle, this.icon, this.route);
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
}

const _groups = <(String, Color, List<_Report>)>[
  (
    'Business',
    Color(0xFF9333EA),
    [
      _Report(
        'Day & period summary',
        'Sales, purchases, expenses, payments and profit',
        Icons.today_rounded,
        '/reports/daily',
      ),
      _Report(
        'Profit & loss',
        'Trading account with stock, gross and net profit',
        Icons.balance_rounded,
        '/reports/profit-loss',
      ),
      _Report(
        'Daily profit',
        'Profit for every day in a period',
        Icons.show_chart_rounded,
        '/reports/daily-profit',
      ),
      _Report(
        'Bill-wise profit',
        'Profit and margin on each invoice',
        Icons.receipt_long_rounded,
        '/reports/billwise-profit',
      ),
    ],
  ),
  (
    'Stock & parties',
    Color(0xFF0891B2),
    [
      _Report(
        'Stock report',
        'Opening, in, out and closing stock by product',
        Icons.warehouse_rounded,
        '/reports/stock',
      ),
      _Report(
        'Party balances',
        'What every customer and vendor owes',
        Icons.groups_rounded,
        '/reports/party-balance',
      ),
      _Report(
        'Outstanding & aging',
        'Unpaid invoices by how overdue they are',
        Icons.hourglass_bottom_rounded,
        '/reports/outstanding',
      ),
    ],
  ),
  (
    'Analytics',
    Color(0xFF2563EB),
    [
      _Report(
        'Top customers',
        'Sales and outstanding by customer',
        Icons.person_rounded,
        '/reports/customers',
      ),
      _Report(
        'Top products',
        'Revenue and quantity by product',
        Icons.inventory_2_rounded,
        '/reports/products',
      ),
      _Report(
        'Categories',
        'Revenue by product category',
        Icons.sell_rounded,
        '/reports/categories',
      ),
      _Report(
        'Payments',
        'Money in and out by payment mode',
        Icons.payments_rounded,
        '/reports/payments',
      ),
    ],
  ),
  (
    'GST',
    Color(0xFFC026D3),
    [
      _Report(
        'GST summary & returns',
        'Monthly summary, GSTR-1, GSTR-3B, GSTR-2',
        Icons.calculate_rounded,
        '/gst',
      ),
    ],
  ),
];

class ReportsHubScreen extends StatelessWidget {
  const ReportsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cols = Breakpoints.columns(
      context,
      compactCols: 1,
      mediumCols: 2,
      expandedCols: 3,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Spacing.lg,
          Spacing.sm,
          Spacing.lg,
          Spacing.xxl,
        ),
        children: [
          ContentWidth(
            maxWidth: 1100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (name, accent, reports) in _groups) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Spacing.xs,
                      Spacing.lg,
                      0,
                      Spacing.sm,
                    ),
                    child: Text(
                      name.toUpperCase(),
                      style: context.text.labelMedium?.copyWith(
                        color: context.colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  ResponsiveGrid(
                    columns: cols,
                    spacing: Spacing.sm,
                    children: [
                      for (final r in reports)
                        Card(
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => context.push(r.route),
                            child: Padding(
                              padding: const EdgeInsets.all(Spacing.md),
                              child: Row(
                                children: [
                                  IconBadge(r.icon, color: accent, size: 44),
                                  const SizedBox(width: Spacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          r.title,
                                          style: context.text.titleSmall,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          r.subtitle,
                                          style: context.text.bodySmall,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    color: context.colors.onSurfaceVariant,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
