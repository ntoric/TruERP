// Renders every Phase 1 screen with realistic fake data at phone and tablet
// sizes. Any layout error (overflow, unbounded constraints) or exception
// fails the test.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:truerp_mobile/core/api/api_client.dart';
import 'package:truerp_mobile/core/api/json.dart';
import 'package:truerp_mobile/core/api/paged.dart';
import 'package:truerp_mobile/core/auth/session.dart';
import 'package:truerp_mobile/core/auth/session_controller.dart';
import 'package:truerp_mobile/core/config/app_config.dart';
import 'package:truerp_mobile/core/theme/app_theme.dart';
import 'package:truerp_mobile/features/accounting/ui/accounting_reports.dart';
import 'package:truerp_mobile/features/accounting/ui/accounting_screen.dart';
import 'package:truerp_mobile/features/cash_bank/ui/bank_account_form_screen.dart';
import 'package:truerp_mobile/features/cash_bank/ui/cash_bank_screen.dart';
import 'package:truerp_mobile/features/cash_bank/ui/payment_routing_screen.dart';
import 'package:truerp_mobile/features/dashboard/ui/home_screen.dart';
import 'package:truerp_mobile/features/expenses/ui/expense_categories_screen.dart';
import 'package:truerp_mobile/features/expenses/ui/expense_detail_screen.dart';
import 'package:truerp_mobile/features/expenses/ui/expense_form_screen.dart';
import 'package:truerp_mobile/features/expenses/ui/expenses_screen.dart';
import 'package:truerp_mobile/features/invoices/ui/invoice_detail_screen.dart';
import 'package:truerp_mobile/features/invoices/ui/invoice_form_screen.dart';
import 'package:truerp_mobile/features/invoices/ui/invoices_screen.dart';
import 'package:truerp_mobile/features/more/more_screen.dart';
import 'package:truerp_mobile/features/parties/ui/parties_screen.dart';
import 'package:truerp_mobile/features/parties/ui/party_detail_screen.dart';
import 'package:truerp_mobile/features/parties/ui/party_form_screen.dart';
import 'package:truerp_mobile/features/payments/ui/payment_in_form_screen.dart';
import 'package:truerp_mobile/features/payments/ui/payment_out_form_screen.dart';
import 'package:truerp_mobile/features/payments/ui/payments_in_screen.dart';
import 'package:truerp_mobile/features/payments/ui/payments_out_screen.dart';
import 'package:truerp_mobile/features/products/ui/product_detail_screen.dart';
import 'package:truerp_mobile/features/profit/ui/profit_distribution_screen.dart';
import 'package:truerp_mobile/features/products/ui/product_form_screen.dart';
import 'package:truerp_mobile/features/products/ui/products_screen.dart';
import 'package:truerp_mobile/features/purchases/ui/purchase_bill_detail_screen.dart';
import 'package:truerp_mobile/features/purchases/ui/purchase_bill_form_screen.dart';
import 'package:truerp_mobile/features/purchases/ui/purchase_bills_screen.dart';
import 'package:truerp_mobile/features/purchases/ui/purchase_orders_screen.dart';
import 'package:truerp_mobile/features/purchases/ui/purchase_returns_screen.dart';

const _party = {
  'id': 'p1', 'name': 'Sharma General Stores Private Limited', 'party_type': 'customer', 'phone': '9876543210',
  'email': 'accounts@sharma.example', 'gstin': '29ABCDE1234F1Z5', 'city': 'Bengaluru', 'state': 'Karnataka',
  'category': 'Wholesale', 'balance': 1234567.89, 'opening_balance': 5000, 'credit_limit': 100000,
};
const _vendor = {'id': 'p2', 'name': 'Acme Supplies', 'party_type': 'vendor', 'balance': -45000};
const _product = {
  'id': 'pr1', 'name': 'Basmati Rice Premium Long Grain 25kg Bag', 'item_code': 'RICE-25', 'category': 'Grocery',
  'unit': 'BAG', 'sale_price': 2450.5, 'purchase_price': 2100, 'mrp': 2600, 'tax_rate': 5, 'min_stock': 10,
  'stock_qty': 4, 'hsn_code': '1006',
};
const _service = {'id': 'pr2', 'name': 'Delivery', 'item_type': 'service', 'sale_price': 150};
final _invoice = {
  'id': 'i1', 'invoice_number': 'INV-2026-000123', 'status': 'partial', 'date': '2026-11-20T00:00:00Z',
  'due_date': '2026-12-05T00:00:00Z', 'party_id': 'p1', 'party': _party, 'sub_total': 4901, 'discount_total': 245.05,
  'invoice_discount': 50, 'additional_charges': 100, 'round_off': 0.05, 'total_amount': 4706, 'amount_paid': 2000,
  'payment_mode': 'upi', 'notes': 'Thanks for your business', 'terms': 'Goods once sold will not be taken back.',
  'items': [
    {'description': 'Basmati Rice Premium Long Grain 25kg Bag', 'quantity': 2, 'unit': 'BAG', 'unit_price': 2450.5,
     'discount': 5, 'total': 4655.95},
  ],
};
final _payment = {
  'id': 'pay1', 'payment_in_number': 'PIN-00042', 'amount_received': 2000, 'mode': 'upi', 'date': '2026-11-21T00:00:00Z',
  'party': _party, 'invoice_id': 'i1', 'invoice': {'invoice_number': 'INV-2026-000123'}, 'reference': 'UTR123',
};

final _bill = {
  'id': 'b1', 'bill_number': 'VND/2026-27/000981', 'status': 'partial', 'stock_status': 'approved',
  'bill_date': '2026-11-18T00:00:00Z', 'due_date': '2026-12-18T00:00:00Z', 'party_id': 'p2', 'party': _vendor,
  'items': [
    {'id': 'bi1', 'product_id': 'pr1', 'description': 'Basmati Rice Premium Long Grain 25kg Bag', 'quantity': 40,
     'unit': 'BAG', 'unit_price': 2100, 'discount': 2.5, 'tax_rate': 5, 'tax_amount': 4095, 'total': 85995},
  ],
  'sub_total': 84000, 'tax_total': 4095, 'invoice_discount': 500, 'additional_charges': 1200,
  'total_amount': 86795, 'paid_amount': 50000, 'balance_due': 36795, 'payment_mode': 'bank_transfer', 'notes': 'Truck no. KA-01-AB-1234',
};
final _paymentOut = {
  'id': 'po1', 'payment_out_number': 'POUT-0012', 'amount_paid': 50000, 'mode': 'bank_transfer',
  'date': '2026-11-19T00:00:00Z', 'party': _vendor, 'purchase_bill_id': 'b1', 'purchase_bill': {'bill_number': 'VND/2026-27/000981'},
};
final _expense = {
  'id': 'e1', 'expense_number': 'EXP-0042', 'category': 'Electricity & Utilities', 'description': 'November electricity bill for the main warehouse',
  'amount': 11800, 'sub_total': 10000, 'tax_total': 1800, 'with_gst': true, 'tax_rate': 18, 'date': '2026-11-20T00:00:00Z',
  'vendor': 'BESCOM', 'payment_mode': 'upi', 'items': [{'description': 'Electricity', 'quantity': 1, 'unit_price': 10000, 'total': 11800}],
};
final _return = {
  'id': 'r1', 'return_number': 'PR-0003', 'status': 'draft', 'date': '2026-11-21', 'amount': 4410, 'refund_mode': 'credit_note',
  'party': _vendor, 'purchase_bill_id': 'b1', 'purchase_bill': {'bill_number': 'VND/2026-27/000981'}, 'reason': 'Damaged bags',
  'items': [{'description': 'Basmati Rice Premium Long Grain 25kg Bag', 'quantity': 2, 'unit_price': 2100, 'tax_rate': 5, 'total': 4410}],
};
final _order = {
  'id': 'o1', 'order_number': 'PO-0007', 'status': 'submitted', 'order_date': '2026-11-15T00:00:00Z', 'party': _vendor,
  'sub_total': 105000, 'tax_total': 5250, 'total_amount': 110250, 'notes': 'Deliver before Diwali',
  'items': [{'description': 'Basmati Rice Premium Long Grain 25kg Bag', 'quantity': 50, 'received_qty': 40, 'unit_price': 2100, 'tax_rate': 5, 'total': 110250}],
};

const _hdfc = {
  'id': 'b1', 'account_name': 'HDFC Current Account Main Branch', 'bank_name': 'HDFC Bank', 'account_number': '50100012345678',
  'ifsc_code': 'HDFC0001234', 'account_type': 'current', 'balance': 1234567.89, 'is_primary': true, 'is_active': true,
};
const _sbi = {'id': 'b2', 'account_name': 'SBI Savings', 'bank_name': 'SBI', 'account_number': '30001234', 'balance': -2500, 'is_active': true};
const _old = {'id': 'b3', 'account_name': 'Old ICICI', 'bank_name': 'ICICI', 'account_number': '1', 'balance': 0, 'is_active': false};
final _cashTxns = [
  {'id': 't1', 'transaction_type': 'add', 'amount': 50000, 'date': '2026-11-20T00:00:00Z', 'description': 'Owner capital introduced for Diwali stock', 'account_id': 'b1', 'account': _hdfc},
  {'id': 't2', 'transaction_type': 'reduce', 'amount': 1200, 'date': '2026-11-21T00:00:00Z', 'reference': 'CHG-NOV'},
  {'id': 't3', 'transaction_type': 'transfer_out', 'amount': 10000, 'date': '2026-11-22T00:00:00Z', 'account_id': 'b1', 'account': _hdfc, 'is_linked': true},
];
const _partner = {'id': 'pt1', 'name': 'Rahul Mehta', 'phone': '9876500000', 'pan': 'ABCDE1234F', 'is_active': true};
final _accounts = [
  {'id': 'a1', 'code': '1000', 'name': 'Cash in Hand', 'account_type': 'asset', 'sub_type': 'current_asset', 'balance': 45000},
  {'id': 'a2', 'code': '2000', 'name': 'Accounts Payable', 'account_type': 'liability', 'balance': 120000},
  {'id': 'a3', 'code': '4000', 'name': 'Sales', 'account_type': 'income', 'balance': 9876543},
  {'id': 'a4', 'code': '5100', 'name': 'General Expenses', 'account_type': 'expense', 'balance': 23456},
];
const _row = {'account_id': 'a1', 'account_code': '1000', 'account_name': 'Cash in Hand', 'debit': 45000, 'credit': 0, 'amount': 45000};

class FakeApi extends ApiClient {
  FakeApi(super.config, super.tokens);

  dynamic _route(String path) {
    if (path == '/dashboard/stats') {
      return {'total_sales': 98765432.1, 'total_sales_paid': 54321098.7, 'total_invoices': 1234, 'pending_amount': 4444444,
        'today_sales': 12345, 'today_invoices': 7, 'total_customers': 321, 'total_products': 456,
        'low_stock_products': 12, 'overdue_invoices': 5};
    }
    if (path == '/dashboard/sales-report') {
      final now = DateTime.now();
      return [for (var i = 0; i < 30; i += 3) {'period': ymd(now.subtract(Duration(days: i))), 'sales': 1000.0 * (i + 1), 'count': i}];
    }
    if (path == '/dashboard/recent-invoices') return [_invoice, _invoice];
    if (path == '/dashboard/recent-payments') return [_payment];
    if (path == '/dashboard/top-parties') {
      return [{'party_id': 'p1', 'name': 'Sharma General Stores Private Limited', 'total_sales': 999999.99, 'invoice_count': 42}];
    }
    if (path == '/invoices/stats') return {'total_sales': 98765432.1, 'paid': 54321098.7, 'unpaid': 44444333.4};
    if (path == '/invoices/next-number') return {'invoice_number': 'INV-2026-000124'};
    if (path.endsWith('/status-history')) {
      return [{'from_status': '', 'to_status': 'sent', 'note': 'Invoice created', 'changed_by': 'Owner', 'created_at': '2026-11-20T10:00:00Z'}];
    }
    if (path.startsWith('/invoices/')) return _invoice;
    if (path == '/parties/stats') return {'total_parties': 10, 'to_collect': 1234567, 'to_pay': -45000};
    if (path.endsWith('/ledger')) {
      return {'opening_balance': 5000, 'closing_balance': 1234567.89, 'total_debit': 2000000, 'total_credit': 765432.11,
        'entries': [
          {'type': 'invoice', 'voucher': 'Sales Invoice', 'ref_number': 'INV-1', 'ref_id': 'i1', 'date': '2026-11-20', 'debit': 4706, 'balance': 9706},
          {'type': 'payment_in', 'voucher': 'Payment In', 'ref_number': 'PIN-1', 'date': '2026-11-21', 'credit': 2000, 'balance': 7706, 'payment_mode': 'upi'},
        ]};
    }
    if (path == '/parties/p2') return _vendor;
    if (path.startsWith('/parties/')) return _party;
    if (path == '/parties') return {'parties': [_party, _vendor], 'total': 2, 'page': 1, 'per_page': 25, 'categories': ['Wholesale']};
    if (path == '/products/units') return ['BAG', 'PCS'];
    if (path == '/categories') return [{'name': 'Grocery'}, {'name': 'Beverages'}];
    if (path.startsWith('/inventory/stocks/products/')) return {'data': [{'available_qty': 4}]};
    if (path == '/products/pr2') return _service;
    if (path.startsWith('/products/')) return _product;
    if (path == '/purchase/bills/stats') return {'total_purchase': 7654321, 'paid': 5000000, 'unpaid': 2654321};
    if (path.startsWith('/purchase/bills/')) return _bill;
    if (path.startsWith('/purchase-returns/')) return _return;
    if (path.startsWith('/purchase/orders/')) return _order;
    if (path == '/expense-categories') {
      return [{'id': 'c1', 'name': 'Electricity & Utilities', 'is_active': true}, {'id': 'c2', 'name': 'Rent', 'is_active': false}];
    }
    if (path.startsWith('/expenses/')) return _expense;
    if (path == '/cash-bank/summary') {
      return {'total_balance': 1277067.89, 'cash_in_hand': 45000, 'initial_investment': 500000, 'bank_accounts': [_hdfc, _sbi, _old]};
    }
    if (path == '/cash-bank/payment-method-mappings') {
      return {'mappings': [
        {'payment_method': 'cash', 'label': 'Cash'},
        {'payment_method': 'upi', 'label': 'UPI', 'bank_account_id': 'b1'},
        {'payment_method': 'card', 'label': 'Card', 'bank_account_id': 'gone'},
        {'payment_method': 'initial_investment', 'label': 'Initial Investment'},
      ]};
    }
    if (path == '/partners') return [_partner, {'id': 'pt2', 'name': 'Priya Shah', 'is_active': false}];
    if (path == '/accounting/stats') {
      return {'total_assets': 2345678, 'total_liabilities': 120000, 'total_equity': 500000, 'total_income': 9876543, 'total_expense': 23456, 'net_profit': 9853087};
    }
    if (path == '/accounting/accounts') return _accounts;
    if (path == '/accounting/trial-balance') return {'items': [_row, {..._row, 'account_id': 'a3', 'account_name': 'Sales', 'debit': 0, 'credit': 45000}], 'total_debit': 45000, 'total_credit': 45000, 'is_balanced': true};
    if (path == '/accounting/profit-loss') return {'income': [_row], 'expenses': const [], 'total_income': 45000, 'total_expense': 0, 'net_profit': 45000};
    if (path == '/accounting/balance-sheet') {
      return {'assets': [_row], 'liabilities': const [], 'equity': const [], 'total_assets': 45000, 'total_liabilities': 0, 'total_equity': 40000, 'is_balanced': false};
    }
    if (path.startsWith('/accounting/general-ledger/')) {
      return {'account': _accounts.first, 'opening_balance': 1000, 'closing_balance': 45000, 'entries': [
        {'transaction_date': '2026-11-20T00:00:00Z', 'transaction_type': 'invoice', 'reference_number': 'INV-1', 'description': 'Sale', 'debit': 4706, 'balance': 5706},
        {'transaction_date': '2026-11-21T00:00:00Z', 'transaction_type': 'expense', 'credit': 706, 'balance': 5000},
      ]};
    }
    if (path == '/payments/next-number') return {'payment_in_number': 'PIN-00043'};
    if (path == '/cash-bank/accounts') {
      return [{'id': 'b1', 'account_name': 'HDFC Current', 'account_number': '50100012345678', 'is_primary': true, 'is_active': true}];
    }
    return <String, dynamic>{};
  }

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async => _route(path);

  @override
  Future<JsonMap> getMap(String path, {Map<String, dynamic>? query}) async => asMap(_route(path));

  @override
  Future<Paged<T>> getPaged<T>(String path, T Function(JsonMap) fromJson,
      {String? key, int page = 1, int perPage = 25, Map<String, dynamic>? query}) async {
    final body = switch (path) {
      '/parties' => _route(path),
      '/products' => {'products': [_product, _service], 'total': 2, 'page': 1, 'per_page': 25},
      '/invoices' => {'invoices': [_invoice, {..._invoice, 'id': 'i2', 'status': 'cancelled'}], 'total': 2, 'page': 1, 'per_page': 25},
      '/purchase/bills' => {'bills': [_bill, {..._bill, 'id': 'b2', 'status': 'draft'}], 'total': 2, 'page': 1, 'per_page': 25},
      '/payment-outs' => {'payment_outs': [_paymentOut, {..._paymentOut, 'id': 'po2', 'status': 'cancelled'}], 'total': 2, 'page': 1, 'per_page': 25},
      '/expenses' => [_expense, {..._expense, 'id': 'e2', 'status': 'cancelled'}],
      '/purchase-returns' => {'data': [_return, {..._return, 'id': 'r2', 'status': 'processed'}]},
      '/purchase/orders' => {'data': [_order, {..._order, 'id': 'o2', 'status': 'draft'}]},
      '/cash-bank/transactions' => {'transactions': _cashTxns, 'total': 3, 'page': 1, 'per_page': 25},
      '/profit-distributions' => [
          {'id': 'd1', 'distribution_number': 'PD-0001', 'amount': 250000, 'date': '2026-10-01T00:00:00Z', 'partner': _partner, 'account': _hdfc, 'description': 'H1 profit share'},
          {'id': 'd2', 'distribution_number': 'PD-0002', 'amount': 5000, 'date': '2026-11-01T00:00:00Z', 'partner': _partner},
        ],
      '/accounting/journal' => {'data': [
          {'id': 'j1', 'entry_number': 'JE-0001', 'entry_date': '2026-11-20T00:00:00Z', 'description': 'Sales invoice INV-1', 'total_debit': 4706, 'total_credit': 4706, 'status': 'posted',
           'lines': [{'account': {'code': '1100', 'name': 'Accounts Receivable'}, 'debit': 4706}, {'account': {'code': '4000', 'name': 'Sales'}, 'credit': 4706}]},
        ], 'total': 1, 'page': 1, 'per_page': 25},
      '/payments' => {'payments': [_payment, {..._payment, 'id': 'pay2', 'status': 'cancelled'}], 'total': 2, 'page': 1, 'per_page': 25},
      _ => const <dynamic>[],
    };
    return Paged.parse(body, fromJson, key: key, page: page, perPage: perPage);
  }
}

class FakeSession extends SessionController {
  @override
  Future<Session?> build() async => const Session(
        token: 't',
        user: AppUser(id: 'u1', name: 'Mohammed Shahid', email: 'owner@example.com', role: 'owner'),
        stores: [StoreInfo(id: 's1', name: 'Main Store, MG Road'), StoreInfo(id: 's2', name: 'Branch')],
        activeStoreId: 's1',
      );
}

void main() {
  late SharedPreferences prefs;

  setUpAll(() async {
    AppTheme.useGoogleFonts = false;
    await initializeDateFormatting('en_IN');
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  final screens = <String, Widget Function()>{
    'home': () => const HomeScreen(),
    'more': () => const MoreScreen(),
    'invoices': () => const InvoicesScreen(isTab: true),
    'invoice detail': () => const InvoiceDetailScreen(invoiceId: 'i1'),
    'invoice form': () => const InvoiceFormScreen(partyId: 'p1'),
    'parties': () => const PartiesScreen(isTab: true),
    'party detail': () => const PartyDetailScreen(partyId: 'p1'),
    'vendor detail': () => const PartyDetailScreen(partyId: 'p2'),
    'party form (edit)': () => const PartyFormScreen(partyId: 'p1'),
    'party form (new)': () => const PartyFormScreen(initialType: 'vendor'),
    'products': () => const ProductsScreen(),
    'product detail': () => const ProductDetailScreen(productId: 'pr1'),
    'service detail': () => const ProductDetailScreen(productId: 'pr2'),
    'product form (edit)': () => const ProductFormScreen(productId: 'pr1'),
    'product form (new)': () => const ProductFormScreen(),
    'payments in': () => const PaymentsInScreen(),
    'payment in form': () => const PaymentInFormScreen(partyId: 'p1', invoiceId: 'i1'),
    'purchases': () => const PurchaseBillsScreen(isTab: true),
    'purchase detail': () => const PurchaseBillDetailScreen(billId: 'b1'),
    'purchase form': () => const PurchaseBillFormScreen(partyId: 'p2'),
    'payments out': () => const PaymentsOutScreen(),
    'payment out form': () => const PaymentOutFormScreen(partyId: 'p2', billId: 'b1'),
    'expenses': () => const ExpensesScreen(),
    'expense detail': () => const ExpenseDetailScreen(expenseId: 'e1'),
    'expense form (new)': () => const ExpenseFormScreen(),
    'expense form (edit)': () => const ExpenseFormScreen(expenseId: 'e1'),
    'expense categories': () => const ExpenseCategoriesScreen(),
    'purchase returns': () => const PurchaseReturnsScreen(),
    'purchase return detail': () => const PurchaseReturnDetailScreen(returnId: 'r1'),
    'purchase return form': () => const PurchaseReturnFormScreen(billId: 'b1'),
    'purchase orders': () => const PurchaseOrdersScreen(),
    'purchase order detail': () => const PurchaseOrderDetailScreen(orderId: 'o1'),
    'purchase order form': () => const PurchaseOrderFormScreen(),
    'cash & bank': () => const CashBankScreen(),
    'cash transactions': () => const CashTransactionsScreen(),
    'cash account (bank)': () => const CashAccountScreen(accountId: 'b1'),
    'cash account (cash)': () => const CashAccountScreen(accountId: 'cash'),
    'bank account form (new)': () => const BankAccountFormScreen(),
    'bank account form (edit)': () => const BankAccountFormScreen(accountId: 'b1'),
    'payment routing': () => const PaymentRoutingScreen(),
    'profit distribution': () => const ProfitDistributionScreen(),
    'profit payout form': () => const ProfitPayoutFormScreen(),
    'accounting': () => const AccountingScreen(),
    'trial balance': () => const TrialBalanceScreen(),
    'profit & loss': () => const ProfitLossScreen(),
    'balance sheet': () => const BalanceSheetScreen(),
    'general ledger': () => const GeneralLedgerScreen(accountId: 'a1'),
  };

  const sizes = {'phone': Size(360, 780), 'tablet': Size(1280, 800)};

  for (final MapEntry(key: sizeName, value: size) in sizes.entries) {
    for (final MapEntry(key: name, value: build) in screens.entries) {
      testWidgets('$name renders on $sizeName', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        // Print the full report (including the offending widget) for any
        // layout error, then let the test framework record it as usual.
        final previous = FlutterError.onError;
        FlutterError.onError = (details) {
          debugPrint(details.toString());
          previous?.call(details);
        };
        addTearDown(() => FlutterError.onError = previous);

        final config = AppConfig(prefs);
        await tester.pumpWidget(ProviderScope(
          overrides: [
            sharedPrefsProvider.overrideWithValue(prefs),
            apiClientProvider.overrideWithValue(FakeApi(config, AuthTokenHolder())),
            sessionProvider.overrideWith(FakeSession.new),
          ],
          child: MaterialApp(theme: AppTheme.light(), home: build()),
        ));
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
