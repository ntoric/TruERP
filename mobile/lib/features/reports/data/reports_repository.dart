import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/json.dart';
import '../../../core/models/reports.dart';
import 'report_period.dart';

/// Server exports for a report: (path, file extension, MIME type).
typedef ReportExport = (String, String, String);

const pdfMime = 'application/pdf';
const xlsxMime =
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
const csvMime = 'text/csv';

class ReportsRepository {
  ReportsRepository(this._api);
  final ApiClient _api;

  // ── Dashboard reports (period-based) ─────────────────────────────────
  Future<PeriodReport> period(ReportPeriod p) async => PeriodReport.fromJson(
    await _api.getMap('/dashboard/periodic-report', query: p.toQuery()),
  );

  Future<TradingProfitLoss> profitLoss(ReportPeriod p) async =>
      TradingProfitLoss.fromJson(
        await _api.getMap('/dashboard/profit-loss-report', query: p.toQuery()),
      );

  /// Up to 400 days in one request (server caps per_page at 500).
  Future<DailyProfitReport> dailyProfit(ReportPeriod p) async =>
      DailyProfitReport.fromJson(
        await _api.getMap(
          '/dashboard/daily-profit-report',
          query: {...p.toQuery(), 'page': 1, 'per_page': 400, 'sort': 'desc'},
        ),
      );

  /// [sort]: newest | oldest | profit_desc | profit_asc | sale_desc.
  Future<BillwiseProfitReport> billwise(
    ReportPeriod p, {
    String sort = 'newest',
    String? search,
  }) async => BillwiseProfitReport.fromJson(
    await _api.getMap(
      '/dashboard/billwise-profit-report',
      query: {...p.toQuery(), 'sort': sort, 'search': search},
    ),
  );

  Future<StockReport> stock(ReportPeriod p) async => StockReport.fromJson(
    await _api.getMap('/dashboard/stock-report', query: p.toQuery()),
  );

  /// [type]: customer | vendor | null (both).
  Future<PartyBalanceReport> partyBalances(
    DateTime asOf, {
    String? type,
  }) async => PartyBalanceReport.fromJson(
    await _api.getMap(
      '/dashboard/party-balance-report',
      query: {'date': ymd(asOf), 'party_type': type},
    ),
  );

  // ── Analytics (rolling windows) ──────────────────────────────────────
  Future<OutstandingReport> outstanding() async =>
      OutstandingReport.fromJson(await _api.getMap('/reports/outstanding'));

  Future<RankReport> customers(AnalyticsPeriod p) async => RankReport.customers(
    await _api.getMap('/reports/customers', query: {'period': p.value}),
  );

  Future<RankReport> products(AnalyticsPeriod p) async => RankReport.products(
    await _api.getMap('/reports/products', query: {'period': p.value}),
  );

  Future<RankReport> categories(AnalyticsPeriod p) async =>
      RankReport.categories(
        await _api.getMap('/reports/categories', query: {'period': p.value}),
      );

  Future<PaymentsAnalytics> payments(AnalyticsPeriod p) async =>
      PaymentsAnalytics.fromJson(
        await _api.getMap('/reports/payments', query: {'period': p.value}),
      );

  // ── GST (month = YYYY-MM) ────────────────────────────────────────────
  Future<GstSummary> gstSummary(String month) async => GstSummary.fromJson(
    await _api.getMap('/gst/summary', query: {'period': month}),
  );

  Future<List<GstReturnRow>> gstr1(String month) async => asMapList(
    (await _api.getMap('/gst/gstr1', query: {'period': month}))['data'],
  ).map(GstReturnRow.fromJson).toList();

  Future<List<GstReturnRow>> gstr2(String month) async => asMapList(
    (await _api.getMap('/gst/gstr2', query: {'period': month}))['data'],
  ).map(GstReturnRow.fromJson).toList();

  Future<Gstr3b> gstr3b(String month) async => Gstr3b.fromJson(
    await _api.getMap('/gst/gstr3b', query: {'period': month}),
  );

  Future<List<GstDocRow>> eInvoices() async {
    final res = await _api.get('/gst/einvoice/history');
    return (res is List ? asMapList(res) : asMapList(asMap(res)['data']))
        .map(GstDocRow.fromJson)
        .toList();
  }

  Future<List<GstDocRow>> eWayBills() async {
    final res = await _api.get('/gst/ewaybill/history');
    return (res is List ? asMapList(res) : asMapList(asMap(res)['data']))
        .map(GstDocRow.fromJson)
        .toList();
  }
}

/// PDF / Excel exports offered by each period report (all take the same
/// period query as the report itself).
abstract final class ReportExports {
  static const period = [
    ('/dashboard/periodic-report/pdf', 'pdf', pdfMime),
    ('/dashboard/periodic-report/export', 'csv', csvMime),
  ];
  static const profitLoss = [
    ('/dashboard/profit-loss-report/pdf', 'pdf', pdfMime),
    ('/dashboard/profit-loss-report/excel', 'xlsx', xlsxMime),
  ];
  static const dailyProfit = [
    ('/dashboard/daily-profit-report/pdf', 'pdf', pdfMime),
    ('/dashboard/daily-profit-report/excel', 'xlsx', xlsxMime),
  ];
  static const billwise = [
    ('/dashboard/billwise-profit-report/pdf', 'pdf', pdfMime),
    ('/dashboard/billwise-profit-report/excel', 'xlsx', xlsxMime),
  ];
  static const stock = [
    ('/dashboard/stock-report/pdf', 'pdf', pdfMime),
    ('/dashboard/stock-report/excel', 'xlsx', xlsxMime),
  ];
  static const partyBalance = [
    ('/dashboard/party-balance-report/pdf', 'pdf', pdfMime),
    ('/dashboard/party-balance-report/excel', 'xlsx', xlsxMime),
  ];
}

final reportsRepositoryProvider = Provider(
  (ref) => ReportsRepository(ref.watch(apiClientProvider)),
);
