import '../api/json.dart';

/// Amount + count pair used throughout the dashboard reports.
class Metric {
  const Metric(this.amount, this.count);
  final double amount;
  final int count;

  factory Metric.fromJson(Object? v) {
    final j = asMap(v);
    return Metric(asDouble(j['total_amount']), asInt(j['count']));
  }
}

/// Header shared by every period-based report.
class ReportHeader {
  const ReportHeader({this.label = '', this.startDate, this.endDate});
  final String label;
  final DateTime? startDate;
  final DateTime? endDate;

  factory ReportHeader.fromJson(JsonMap j) =>
      ReportHeader(label: asString(j['label']), startDate: asDate(j['start_date']), endDate: asDate(j['end_date']));
}

// ── Daily / period report ───────────────────────────────────────────────

class ModeTotal {
  const ModeTotal({required this.label, required this.inAmount, required this.outAmount});
  final String label;
  final double inAmount;
  final double outAmount;

  factory ModeTotal.fromJson(JsonMap j) => ModeTotal(
        label: asString(j['label'], asString(j['method'])),
        inAmount: asDouble(pick(j, 'in.total_amount')),
        outAmount: asDouble(pick(j, 'out.total_amount')),
      );
}

class ExpenseRow {
  const ExpenseRow({required this.category, required this.description, required this.amount, required this.date});
  final String category;
  final String description;
  final double amount;
  final String date;

  factory ExpenseRow.fromJson(JsonMap j) => ExpenseRow(
        category: asString(j['category']),
        description: asStringOrNull(j['item_description']) ?? asString(j['description']),
        amount: asDouble(j['amount']),
        date: asString(j['date']),
      );
}

class PeriodReport {
  const PeriodReport({
    required this.header,
    required this.sales,
    required this.purchases,
    required this.expenses,
    required this.paymentsIn,
    required this.paymentsOut,
    required this.salesReturns,
    required this.purchaseReturns,
    required this.creditNotes,
    required this.debitNotes,
    required this.profitDistributions,
    required this.accountsPayable,
    this.accountsPayableTotal = 0,
    this.gstCollected = 0,
    this.netCashFlow = 0,
    this.dailyProfit = 0,
    this.productProfit = 0,
    this.byMode = const [],
    this.expenseLines = const [],
  });

  final ReportHeader header;
  final Metric sales;
  final Metric purchases;
  final Metric expenses;
  final Metric paymentsIn;
  final Metric paymentsOut;
  final Metric salesReturns;
  final Metric purchaseReturns;
  final Metric creditNotes;
  final Metric debitNotes;
  final Metric profitDistributions;
  final Metric accountsPayable;
  final double accountsPayableTotal;
  final double gstCollected;
  final double netCashFlow;

  /// Net sales − operating expenses (accrual).
  final double dailyProfit;

  /// Gross margin on products sold, net of returns.
  final double productProfit;
  final List<ModeTotal> byMode;
  final List<ExpenseRow> expenseLines;

  factory PeriodReport.fromJson(JsonMap j) => PeriodReport(
        header: ReportHeader.fromJson(j),
        sales: Metric.fromJson(j['sales']),
        purchases: Metric.fromJson(j['purchases']),
        expenses: Metric.fromJson(j['expenses']),
        paymentsIn: Metric.fromJson(j['payments_in']),
        paymentsOut: Metric.fromJson(j['payments_out']),
        salesReturns: Metric.fromJson(j['sales_returns']),
        purchaseReturns: Metric.fromJson(j['purchase_returns']),
        creditNotes: Metric.fromJson(j['credit_notes']),
        debitNotes: Metric.fromJson(j['debit_notes']),
        profitDistributions: Metric.fromJson(j['profit_distributions']),
        accountsPayable: Metric.fromJson(j['accounts_payable']),
        accountsPayableTotal: asDouble(j['accounts_payable_total']),
        gstCollected: asDouble(j['gst_collected']),
        netCashFlow: asDouble(j['net_cash_flow']),
        dailyProfit: asDouble(j['daily_profit']),
        productProfit: asDouble(j['product_profit']),
        byMode: asMapList(j['payments_by_method']).map(ModeTotal.fromJson).toList(),
        expenseLines: asMapList(j['expense_lines']).map(ExpenseRow.fromJson).toList(),
      );
}

// ── Trading profit & loss ───────────────────────────────────────────────

class NamedAmount {
  const NamedAmount(this.name, this.amount);
  final String name;
  final double amount;

  factory NamedAmount.fromJson(JsonMap j) => NamedAmount(asString(j['name']), asDouble(j['amount']));
}

class TradingProfitLoss {
  const TradingProfitLoss({
    required this.header,
    required this.sales,
    required this.salesReturns,
    required this.purchases,
    required this.purchaseReturns,
    required this.openingStock,
    required this.closingStock,
    required this.grossProfit,
    required this.otherIncome,
    required this.indirectExpenses,
    required this.expenses,
    required this.netProfit,
    this.otherIncomeLines = const [],
    this.indirectExpenseLines = const [],
    this.expenseLines = const [],
  });

  final ReportHeader header;
  final Metric sales;
  final Metric salesReturns;
  final Metric purchases;
  final Metric purchaseReturns;
  final double openingStock;
  final double closingStock;
  final double grossProfit;
  final Metric otherIncome;
  final Metric indirectExpenses;
  final Metric expenses;
  final double netProfit;
  final List<NamedAmount> otherIncomeLines;
  final List<NamedAmount> indirectExpenseLines;
  final List<ExpenseRow> expenseLines;

  factory TradingProfitLoss.fromJson(JsonMap j) => TradingProfitLoss(
        header: ReportHeader.fromJson(j),
        sales: Metric.fromJson(j['sales']),
        salesReturns: Metric.fromJson(j['sales_returns']),
        purchases: Metric.fromJson(j['purchases']),
        purchaseReturns: Metric.fromJson(j['purchase_returns']),
        openingStock: asDouble(j['opening_stock']),
        closingStock: asDouble(j['closing_stock']),
        grossProfit: asDouble(j['gross_profit']),
        otherIncome: Metric.fromJson(j['other_income']),
        indirectExpenses: Metric.fromJson(j['indirect_expenses']),
        expenses: Metric.fromJson(j['expenses']),
        netProfit: asDouble(j['net_profit']),
        otherIncomeLines: asMapList(j['other_income_lines']).map(NamedAmount.fromJson).toList(),
        indirectExpenseLines: asMapList(j['indirect_expense_lines']).map(NamedAmount.fromJson).toList(),
        expenseLines: asMapList(j['expense_lines']).map(ExpenseRow.fromJson).toList(),
      );
}

// ── Daily profit ────────────────────────────────────────────────────────

class DailyProfitRow {
  const DailyProfitRow({
    required this.date,
    this.sales = 0,
    this.cogs = 0,
    this.salesReturn = 0,
    this.salesProfit = 0,
    this.purchase = 0,
    this.grossProfit = 0,
    this.expenses = 0,
    this.netProfit = 0,
  });

  final DateTime? date;
  final double sales;
  final double cogs;
  final double salesReturn;
  final double salesProfit;
  final double purchase;
  final double grossProfit;
  final double expenses;
  final double netProfit;

  factory DailyProfitRow.fromJson(JsonMap j) => DailyProfitRow(
        date: asDate(j['date']),
        sales: asDouble(j['sales']),
        cogs: asDouble(j['cogs']),
        salesReturn: asDouble(j['sales_return']),
        salesProfit: asDouble(j['sales_profit']),
        purchase: asDouble(j['purchase']),
        grossProfit: asDouble(j['gross_profit']),
        expenses: asDouble(j['expenses']),
        netProfit: asDouble(j['net_profit']),
      );
}

class DailyProfitReport {
  const DailyProfitReport({required this.header, required this.rows, required this.totals, required this.totalDays});
  final ReportHeader header;
  final List<DailyProfitRow> rows;
  final DailyProfitRow totals;
  final int totalDays;

  factory DailyProfitReport.fromJson(JsonMap j) => DailyProfitReport(
        header: ReportHeader.fromJson(j),
        rows: asMapList(j['rows']).map(DailyProfitRow.fromJson).toList(),
        totals: DailyProfitRow.fromJson(asMap(j['totals'])),
        totalDays: asInt(j['total_days']),
      );
}

// ── Bill-wise profit ────────────────────────────────────────────────────

class BillProfitItem {
  const BillProfitItem({required this.description, this.quantity = 0, this.saleAmount = 0, this.costAmount = 0, this.profit = 0});
  final String description;
  final double quantity;
  final double saleAmount;
  final double costAmount;
  final double profit;

  factory BillProfitItem.fromJson(JsonMap j) => BillProfitItem(
        description: asString(j['description']),
        quantity: asDouble(j['quantity']),
        saleAmount: asDouble(j['sale_amount']),
        costAmount: asDouble(j['cost_amount']),
        profit: asDouble(j['profit']),
      );
}

class BillProfit {
  const BillProfit({
    required this.invoiceId,
    required this.invoiceNumber,
    required this.date,
    required this.partyName,
    this.status = '',
    this.saleAmount = 0,
    this.discount = 0,
    this.costAmount = 0,
    this.returnsAmount = 0,
    this.profit = 0,
    this.marginPct = 0,
    this.items = const [],
  });

  final String invoiceId;
  final String invoiceNumber;
  final DateTime? date;
  final String partyName;
  final String status;
  final double saleAmount;
  final double discount;
  final double costAmount;
  final double returnsAmount;
  final double profit;
  final double marginPct;
  final List<BillProfitItem> items;

  factory BillProfit.fromJson(JsonMap j) => BillProfit(
        invoiceId: asString(j['invoice_id']),
        invoiceNumber: asString(j['invoice_number']),
        date: asDate(j['date']),
        partyName: asString(j['party_name']),
        status: asString(j['status']),
        saleAmount: asDouble(j['sale_amount']),
        discount: asDouble(j['discount']),
        costAmount: asDouble(j['cost_amount']),
        returnsAmount: asDouble(j['returns_amount']),
        profit: asDouble(j['profit']),
        marginPct: asDouble(j['margin_pct']),
        items: asMapList(j['items']).map(BillProfitItem.fromJson).toList(),
      );
}

class BillwiseProfitReport {
  const BillwiseProfitReport({
    required this.header,
    required this.bills,
    this.billCount = 0,
    this.saleAmount = 0,
    this.costAmount = 0,
    this.profit = 0,
    this.marginPct = 0,
  });

  final ReportHeader header;
  final List<BillProfit> bills;
  final int billCount;
  final double saleAmount;
  final double costAmount;
  final double profit;
  final double marginPct;

  factory BillwiseProfitReport.fromJson(JsonMap j) => BillwiseProfitReport(
        header: ReportHeader.fromJson(j),
        bills: asMapList(j['bills']).map(BillProfit.fromJson).toList(),
        billCount: asInt(j['bill_count']),
        saleAmount: asDouble(j['sale_amount']),
        costAmount: asDouble(j['cost_amount']),
        profit: asDouble(j['profit']),
        marginPct: asDouble(j['margin_pct']),
      );
}

// ── Stock ───────────────────────────────────────────────────────────────

class StockLine {
  const StockLine({
    required this.productId,
    required this.name,
    this.category = '',
    this.unit = '',
    this.openingQty = 0,
    this.inQty = 0,
    this.outQty = 0,
    this.closingQty = 0,
    this.closingValue = 0,
  });

  final String productId;
  final String name;
  final String category;
  final String unit;
  final double openingQty;
  final double inQty;
  final double outQty;
  final double closingQty;
  final double closingValue;

  factory StockLine.fromJson(JsonMap j) => StockLine(
        productId: asString(j['product_id']),
        name: asString(j['product_name']),
        category: asString(j['category']),
        unit: asString(j['unit']),
        openingQty: asDouble(j['opening_qty']),
        inQty: asDouble(j['in_qty']),
        outQty: asDouble(j['out_qty']),
        closingQty: asDouble(j['closing_qty']),
        closingValue: asDouble(j['closing_value']),
      );
}

class StockReport {
  const StockReport({
    required this.header,
    required this.lines,
    this.openingValue = 0,
    this.closingValue = 0,
    this.inQty = 0,
    this.outQty = 0,
    this.change = 0,
  });

  final ReportHeader header;
  final List<StockLine> lines;
  final double openingValue;
  final double closingValue;
  final double inQty;
  final double outQty;
  final double change;

  factory StockReport.fromJson(JsonMap j) => StockReport(
        header: ReportHeader.fromJson(j),
        lines: asMapList(j['lines']).map(StockLine.fromJson).toList(),
        openingValue: asDouble(j['opening_stock']),
        closingValue: asDouble(j['closing_stock']),
        inQty: asDouble(j['in_qty']),
        outQty: asDouble(j['out_qty']),
        change: asDouble(j['stock_change']),
      );
}

// ── Party balances ──────────────────────────────────────────────────────

class PartyBalanceLine {
  const PartyBalanceLine({
    required this.partyId,
    required this.name,
    required this.type,
    this.phone = '',
    this.opening = 0,
    this.debit = 0,
    this.credit = 0,
    this.closing = 0,
  });

  final String partyId;
  final String name;
  final String type;
  final String phone;
  final double opening;
  final double debit;
  final double credit;

  /// Positive = receivable, negative = payable (party balance convention).
  final double closing;

  factory PartyBalanceLine.fromJson(JsonMap j) => PartyBalanceLine(
        partyId: asString(j['party_id']),
        name: asString(j['party_name']),
        type: asString(j['party_type']),
        phone: asString(j['phone']),
        opening: asDouble(j['opening_balance']),
        debit: asDouble(j['debit']),
        credit: asDouble(j['credit']),
        closing: asDouble(j['closing_balance']),
      );
}

class PartyBalanceReport {
  const PartyBalanceReport({required this.lines, this.receivable = 0, this.payable = 0, this.net = 0});
  final List<PartyBalanceLine> lines;
  final double receivable;
  final double payable;
  final double net;

  factory PartyBalanceReport.fromJson(JsonMap j) => PartyBalanceReport(
        lines: asMapList(j['lines']).map(PartyBalanceLine.fromJson).toList(),
        receivable: asDouble(j['closing_receivable']),
        payable: asDouble(j['closing_payable']).abs(),
        net: asDouble(j['net_closing']),
      );
}

// ── Analytics ───────────────────────────────────────────────────────────

/// Rolling windows used by `/reports/*` (see reportPeriodStart in reports.go).
enum AnalyticsPeriod {
  daily('daily', 'Last 30 days'),
  weekly('weekly', 'Last 12 weeks'),
  monthly('monthly', 'Last 12 months'),
  yearly('yearly', 'Last 5 years');

  const AnalyticsPeriod(this.value, this.label);
  final String value;
  final String label;
}

/// Generic ranked row (customer, product or category).
class RankRow {
  const RankRow({required this.id, required this.name, this.subtitle = '', this.value = 0, this.secondary = 0, this.share = 0});
  final String id;
  final String name;
  final String subtitle;
  final double value;
  final double secondary;
  final double share;
}

class AgingBuckets {
  const AgingBuckets({this.current = 0, this.d1To30 = 0, this.d31To60 = 0, this.d61To90 = 0, this.d90Plus = 0});
  final double current;
  final double d1To30;
  final double d31To60;
  final double d61To90;
  final double d90Plus;

  double get total => current + d1To30 + d31To60 + d61To90 + d90Plus;

  List<(String, double)> get buckets => [
        ('Not due', current),
        ('1–30 days', d1To30),
        ('31–60 days', d31To60),
        ('61–90 days', d61To90),
        ('90+ days', d90Plus),
      ];

  factory AgingBuckets.fromJson(JsonMap j) => AgingBuckets(
        current: asDouble(j['current']),
        d1To30: asDouble(j['days_1_30']),
        d31To60: asDouble(j['days_31_60']),
        d61To90: asDouble(j['days_61_90']),
        d90Plus: asDouble(j['days_90_plus']),
      );
}

class OutstandingInvoice {
  const OutstandingInvoice({
    required this.id,
    required this.number,
    required this.partyName,
    required this.date,
    this.outstanding = 0,
    this.daysOverdue = 0,
  });

  final String id;
  final String number;
  final String partyName;
  final DateTime? date;
  final double outstanding;
  final int daysOverdue;

  factory OutstandingInvoice.fromJson(JsonMap j) => OutstandingInvoice(
        id: asString(j['id']),
        number: asString(j['invoice_number']),
        partyName: asString(j['party_name']),
        date: asDate(j['date']),
        outstanding: asDouble(j['outstanding']),
        daysOverdue: asInt(j['days_overdue']),
      );
}

class OutstandingReport {
  const OutstandingReport({
    required this.aging,
    required this.byParty,
    required this.invoices,
    this.total = 0,
    this.overdueCount = 0,
  });

  final AgingBuckets aging;
  final List<RankRow> byParty;
  final List<OutstandingInvoice> invoices;
  final double total;
  final int overdueCount;

  factory OutstandingReport.fromJson(JsonMap j) => OutstandingReport(
        aging: AgingBuckets.fromJson(asMap(j['aging'])),
        byParty: asMapList(j['by_party'])
            .map((p) => RankRow(
                  id: asString(p['party_id']),
                  name: asString(p['party_name']),
                  subtitle: '${asInt(p['invoice_count'])} invoices',
                  value: asDouble(p['outstanding']),
                ))
            .toList(),
        invoices: asMapList(j['invoices']).map(OutstandingInvoice.fromJson).toList(),
        total: asDouble(pick(j, 'summary.total_outstanding')),
        overdueCount: asInt(pick(j, 'summary.overdue_count')),
      );
}

/// Customer-, product- or category-wise analytics, normalised to [RankRow]s.
class RankReport {
  const RankReport({required this.rows, required this.total, this.count = 0});
  final List<RankRow> rows;
  final double total;
  final int count;

  static RankReport customers(JsonMap j) => RankReport(
        rows: asMapList(j['customers'])
            .map((c) => RankRow(
                  id: asString(c['party_id']),
                  name: asString(c['name']),
                  subtitle: '${asInt(c['invoice_count'])} invoices',
                  value: asDouble(c['total_sales']),
                  secondary: asDouble(c['total_outstanding']),
                ))
            .toList(),
        total: asDouble(pick(j, 'summary.total_paid_sales')),
        count: asInt(pick(j, 'summary.customer_count')),
      );

  static RankReport products(JsonMap j) => RankReport(
        rows: asMapList(j['products'])
            .map((p) => RankRow(
                  id: asString(p['product_id']),
                  name: asString(p['name']),
                  subtitle: '${_qtyText(asDouble(p['quantity_sold']))} ${asString(p['unit'])} sold'.trim(),
                  value: asDouble(p['revenue']),
                  share: asDouble(p['share_percent']),
                ))
            .toList(),
        total: asDouble(pick(j, 'summary.total_revenue')),
        count: asInt(pick(j, 'summary.product_count')),
      );

  static RankReport categories(JsonMap j) => RankReport(
        rows: asMapList(j['categories'])
            .map((c) => RankRow(
                  id: asString(c['category']),
                  name: asString(c['category']).isEmpty ? 'Uncategorised' : asString(c['category']),
                  subtitle: '${asInt(c['product_count'])} products · ${_qtyText(asDouble(c['quantity_sold']))} sold',
                  value: asDouble(c['revenue']),
                  share: asDouble(c['share_percent']),
                ))
            .toList(),
        total: asDouble(pick(j, 'summary.total_revenue')),
        count: asInt(pick(j, 'summary.category_count')),
      );
}

String _qtyText(double q) => q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(2);

class PaymentsAnalytics {
  const PaymentsAnalytics({required this.totalIn, required this.totalOut, required this.byMode});
  final double totalIn;
  final double totalOut;
  final List<ModeTotal> byMode;

  double get net => totalIn - totalOut;

  factory PaymentsAnalytics.fromJson(JsonMap j) {
    // by_mode rows are one per mode+direction; fold them into one row per mode.
    final byLabel = <String, (double, double)>{};
    for (final r in asMapList(j['by_mode'])) {
      final mode = asString(r['mode'], 'other');
      final amount = asDouble(r['total'] ?? r['amount']);
      final inbound = asString(r['direction']) != 'out';
      final cur = byLabel[mode] ?? (0, 0);
      byLabel[mode] = inbound ? (cur.$1 + amount, cur.$2) : (cur.$1, cur.$2 + amount);
    }
    return PaymentsAnalytics(
      totalIn: asDouble(pick(j, 'summary.total_in')),
      totalOut: asDouble(pick(j, 'summary.total_out')),
      byMode: [for (final e in byLabel.entries) ModeTotal(label: e.key, inAmount: e.value.$1, outAmount: e.value.$2)],
    );
  }
}

// ── GST ─────────────────────────────────────────────────────────────────

class GstSummary {
  const GstSummary({
    this.totalSales = 0,
    this.totalPurchases = 0,
    this.cgst = 0,
    this.sgst = 0,
    this.igst = 0,
    this.totalTax = 0,
    this.liability = 0,
    this.salesTaxable = 0,
    this.purchaseTaxable = 0,
    this.purchaseTax = 0,
    this.itc = 0,
  });

  final double totalSales;
  final double totalPurchases;
  final double cgst;
  final double sgst;
  final double igst;
  final double totalTax;
  final double liability;
  final double salesTaxable;
  final double purchaseTaxable;
  final double purchaseTax;
  final double itc;

  factory GstSummary.fromJson(JsonMap j) {
    final s = asMap(j['summary']);
    final p = asMap(pick(j, 'details.purchases'));
    return GstSummary(
      totalSales: asDouble(s['total_sales']),
      totalPurchases: asDouble(s['total_purchases']),
      cgst: asDouble(s['cgst']),
      sgst: asDouble(s['sgst']),
      igst: asDouble(s['igst']),
      totalTax: asDouble(s['total_tax']),
      liability: asDouble(s['liability']),
      salesTaxable: asDouble(pick(j, 'details.sales.taxable_value')),
      purchaseTaxable: asDouble(p['taxable_value']),
      purchaseTax: asDouble(p['cgst']) + asDouble(p['sgst']) + asDouble(p['igst']),
      itc: asDouble(pick(j, 'details.itc.total_itc')),
    );
  }
}

/// One invoice/bill row in GSTR-1 or GSTR-2.
class GstReturnRow {
  const GstReturnRow({
    required this.number,
    required this.date,
    required this.partyName,
    this.gstin = '',
    this.type = '',
    this.value = 0,
    this.taxable = 0,
    this.cgst = 0,
    this.sgst = 0,
    this.igst = 0,
  });

  final String number;
  final DateTime? date;
  final String partyName;
  final String gstin;
  final String type;
  final double value;
  final double taxable;
  final double cgst;
  final double sgst;
  final double igst;

  double get tax => cgst + sgst + igst;

  factory GstReturnRow.fromJson(JsonMap j) => GstReturnRow(
        number: asString(j['invoice_number'] ?? j['bill_number']),
        date: asDate(j['invoice_date'] ?? j['receipt_date']),
        partyName: asString(j['party_name']),
        gstin: asString(j['party_gstin']),
        type: asString(j['invoice_type']),
        value: asDouble(j['invoice_value']),
        taxable: asDouble(j['taxable_value']),
        cgst: asDouble(j['cgst']),
        sgst: asDouble(j['sgst']),
        igst: asDouble(j['igst']),
      );
}

class Gstr3b {
  const Gstr3b({this.liability = 0, this.igst = 0, this.cgst = 0, this.sgst = 0, this.itc = 0, this.payable = 0});
  final double liability;
  final double igst;
  final double cgst;
  final double sgst;
  final double itc;
  final double payable;

  factory Gstr3b.fromJson(JsonMap j) => Gstr3b(
        liability: asDouble(j['total_tax_liability']),
        igst: asDouble(j['igst_liability']),
        cgst: asDouble(j['cgst_liability']),
        sgst: asDouble(j['sgst_liability']),
        itc: asDouble(j['total_itc']),
        payable: asDouble(j['tax_payable']),
      );
}

/// E-invoice (IRN) or e-way bill history row.
class GstDocRow {
  const GstDocRow({required this.invoiceId, required this.invoiceNumber, required this.reference, required this.status, this.date});
  final String invoiceId;
  final String invoiceNumber;

  /// IRN or e-way bill number.
  final String reference;
  final String status;
  final DateTime? date;

  factory GstDocRow.fromJson(JsonMap j) => GstDocRow(
        invoiceId: asString(j['invoice_id']),
        invoiceNumber: asString(j['invoice_number']),
        reference: asString(j['irn'] ?? j['ewb_number']),
        status: asString(j['status']),
        date: asDate(j['generated_at'] ?? j['valid_until']),
      );
}
