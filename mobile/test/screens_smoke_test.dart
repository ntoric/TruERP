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
import 'package:truerp_mobile/features/dashboard/ui/home_screen.dart';
import 'package:truerp_mobile/features/invoices/ui/invoice_detail_screen.dart';
import 'package:truerp_mobile/features/invoices/ui/invoice_form_screen.dart';
import 'package:truerp_mobile/features/invoices/ui/invoices_screen.dart';
import 'package:truerp_mobile/features/more/more_screen.dart';
import 'package:truerp_mobile/features/parties/ui/parties_screen.dart';
import 'package:truerp_mobile/features/parties/ui/party_detail_screen.dart';
import 'package:truerp_mobile/features/parties/ui/party_form_screen.dart';
import 'package:truerp_mobile/features/payments/ui/payment_in_form_screen.dart';
import 'package:truerp_mobile/features/payments/ui/payments_in_screen.dart';
import 'package:truerp_mobile/features/products/ui/product_detail_screen.dart';
import 'package:truerp_mobile/features/products/ui/product_form_screen.dart';
import 'package:truerp_mobile/features/products/ui/products_screen.dart';

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
