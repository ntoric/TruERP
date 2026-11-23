import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/json.dart';
import '../../../core/api/revision.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/models/invoice.dart';
import '../../../core/models/payment.dart';

/// `period` values accepted by `/dashboard/stats`.
enum DashPeriod {
  today('today', 'Today'),
  week('week', 'This week'),
  month('month', 'This month'),
  year('year', 'This year'),
  all('all', 'All time');

  const DashPeriod(this.value, this.label);
  final String value;
  final String label;
}

class DashboardStats {
  const DashboardStats({
    this.totalSales = 0,
    this.totalSalesPaid = 0,
    this.totalInvoices = 0,
    this.totalCustomers = 0,
    this.totalProducts = 0,
    this.pendingAmount = 0,
    this.todaySales = 0,
    this.todayInvoices = 0,
    this.lowStockProducts = 0,
    this.overdueInvoices = 0,
  });

  final double totalSales;
  final double totalSalesPaid;
  final int totalInvoices;
  final int totalCustomers;
  final int totalProducts;
  final double pendingAmount;
  final double todaySales;
  final int todayInvoices;
  final int lowStockProducts;
  final int overdueInvoices;

  factory DashboardStats.fromJson(JsonMap j) => DashboardStats(
    totalSales: asDouble(j['total_sales']),
    totalSalesPaid: asDouble(j['total_sales_paid']),
    totalInvoices: asInt(j['total_invoices']),
    totalCustomers: asInt(j['total_customers']),
    totalProducts: asInt(j['total_products']),
    pendingAmount: asDouble(j['pending_amount']),
    todaySales: asDouble(j['today_sales']),
    todayInvoices: asInt(j['today_invoices']),
    lowStockProducts: asInt(j['low_stock_products']),
    overdueInvoices: asInt(j['overdue_invoices']),
  );
}

class SalesPoint {
  const SalesPoint(this.date, this.sales, this.count);
  final DateTime date;
  final double sales;
  final int count;
}

class TopParty {
  const TopParty(this.id, this.name, this.totalSales, this.invoiceCount);
  final String id;
  final String name;
  final double totalSales;
  final int invoiceCount;
}

class DashboardRepository {
  DashboardRepository(this._api);
  final ApiClient _api;

  Future<DashboardStats> stats(DashPeriod period) async =>
      DashboardStats.fromJson(
        await _api.getMap('/dashboard/stats', query: {'period': period.value}),
      );

  /// Last 30 days of *paid* sales, oldest first, with missing days filled as 0.
  Future<List<SalesPoint>> dailySales() async {
    final res = await _api.get(
      '/dashboard/sales-report',
      query: {'period': 'daily'},
    );
    final byDay = <String, SalesPoint>{};
    for (final r in (res is List ? asMapList(res) : const <JsonMap>[])) {
      final raw = asString(r['period']);
      final d = DateTime.tryParse(
        raw.length >= 10 ? raw.substring(0, 10) : raw,
      );
      if (d == null) continue;
      byDay[ymd(d)] = SalesPoint(d, asDouble(r['sales']), asInt(r['count']));
    }
    final today = DateTime.now();
    return List.generate(30, (i) {
      final d = DateTime(
        today.year,
        today.month,
        today.day,
      ).subtract(Duration(days: 29 - i));
      return byDay[ymd(d)] ?? SalesPoint(d, 0, 0);
    });
  }

  Future<List<Invoice>> recentInvoices() async {
    final res = await _api.get('/dashboard/recent-invoices');
    return (res is List ? asMapList(res) : asMapList(asMap(res)['data']))
        .map(Invoice.fromJson)
        .toList();
  }

  Future<List<PaymentIn>> recentPayments() async {
    final res = await _api.get('/dashboard/recent-payments');
    return (res is List ? asMapList(res) : asMapList(asMap(res)['data']))
        .map(PaymentIn.fromJson)
        .toList();
  }

  Future<List<TopParty>> topParties() async {
    final res = await _api.get('/dashboard/top-parties');
    return (res is List ? asMapList(res) : const <JsonMap>[])
        .map(
          (r) => TopParty(
            asString(r['party_id']),
            asString(r['name']),
            asDouble(r['total_sales']),
            asInt(r['invoice_count']),
          ),
        )
        .toList();
  }
}

final dashboardRepositoryProvider = Provider(
  (ref) => DashboardRepository(ref.watch(apiClientProvider)),
);

class DashPeriodController extends Notifier<DashPeriod> {
  @override
  DashPeriod build() => DashPeriod.month;
  void set(DashPeriod p) => state = p;
}

final dashPeriodProvider = NotifierProvider<DashPeriodController, DashPeriod>(
  DashPeriodController.new,
);

/// All dashboard data refetch on store switch and after any save.
final dashboardStatsProvider = FutureProvider.autoDispose<DashboardStats>((
  ref,
) {
  ref.watch(activeStoreIdProvider);
  ref.watch(dataRevisionProvider);
  return ref
      .watch(dashboardRepositoryProvider)
      .stats(ref.watch(dashPeriodProvider));
});

final dailySalesProvider = FutureProvider.autoDispose<List<SalesPoint>>((ref) {
  ref.watch(activeStoreIdProvider);
  ref.watch(dataRevisionProvider);
  return ref.watch(dashboardRepositoryProvider).dailySales();
});

final recentInvoicesProvider = FutureProvider.autoDispose<List<Invoice>>((ref) {
  ref.watch(activeStoreIdProvider);
  ref.watch(dataRevisionProvider);
  return ref.watch(dashboardRepositoryProvider).recentInvoices();
});

final recentPaymentsProvider = FutureProvider.autoDispose<List<PaymentIn>>((
  ref,
) {
  ref.watch(activeStoreIdProvider);
  ref.watch(dataRevisionProvider);
  return ref.watch(dashboardRepositoryProvider).recentPayments();
});

final topPartiesProvider = FutureProvider.autoDispose<List<TopParty>>((ref) {
  ref.watch(activeStoreIdProvider);
  ref.watch(dataRevisionProvider);
  return ref.watch(dashboardRepositoryProvider).topParties();
});
