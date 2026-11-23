import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/accounting/ui/accounting_reports.dart';
import '../../features/accounting/ui/accounting_screen.dart';
import '../../features/auth/ui/change_password_required_screen.dart';
import '../../features/auth/ui/forgot_password_screen.dart';
import '../../features/auth/ui/login_screen.dart';
import '../../features/auth/ui/register_screen.dart';
import '../../features/cash_bank/ui/bank_account_form_screen.dart';
import '../../features/cash_bank/ui/cash_bank_screen.dart';
import '../../features/cash_bank/ui/payment_routing_screen.dart';
import '../../features/dashboard/ui/home_screen.dart';
import '../../features/expenses/ui/expense_categories_screen.dart';
import '../../features/expenses/ui/expense_detail_screen.dart';
import '../../features/expenses/ui/expense_form_screen.dart';
import '../../features/expenses/ui/expenses_screen.dart';
import '../../features/inventory/ui/categories_screen.dart';
import '../../features/inventory/ui/inventory_screen.dart';
import '../../features/inventory/ui/movements_screen.dart';
import '../../features/inventory/ui/transfers_screens.dart';
import '../../features/inventory/ui/warehouses_screens.dart';
import '../../features/invoices/ui/invoice_detail_screen.dart';
import '../../features/invoices/ui/invoice_form_screen.dart';
import '../../features/invoices/ui/invoices_screen.dart';
import '../../features/more/more_screen.dart';
import '../../features/parties/ui/parties_screen.dart';
import '../../features/parties/ui/party_detail_screen.dart';
import '../../features/parties/ui/party_form_screen.dart';
import '../../features/payments/ui/payment_in_form_screen.dart';
import '../../features/payments/ui/payment_out_form_screen.dart';
import '../../features/payments/ui/payments_in_screen.dart';
import '../../features/payments/ui/payments_out_screen.dart';
import '../../features/products/ui/product_detail_screen.dart';
import '../../features/profit/ui/profit_distribution_screen.dart';
import '../../features/products/ui/product_form_screen.dart';
import '../../features/products/ui/products_screen.dart';
import '../../features/purchases/ui/purchase_bill_detail_screen.dart';
import '../../features/purchases/ui/purchase_bill_form_screen.dart';
import '../../features/purchases/ui/purchase_bills_screen.dart';
import '../../features/purchases/ui/purchase_orders_screen.dart';
import '../../features/purchases/ui/purchase_returns_screen.dart';
import '../../features/reports/ui/business_reports.dart';
import '../../features/reports/ui/gst_screen.dart';
import '../../features/reports/ui/reports_hub_screen.dart';
import '../../features/reports/ui/stock_party_reports.dart';
import '../../features/sales_docs/ui/challans_screens.dart';
import '../../features/sales_docs/ui/discounts_screen.dart';
import '../../features/sales_docs/ui/estimates_screens.dart';
import '../../features/sales_docs/ui/returns_screens.dart';
import '../../features/shell/responsive_shell.dart';
import '../../features/shell/splash_screen.dart';
import '../auth/session_controller.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

const _publicRoutes = {'/login', '/register', '/forgot-password'};

/// Bridges Riverpod session changes to go_router's refresh.
class _SessionListenable extends ChangeNotifier {
  _SessionListenable(Ref ref) {
    ref.listen(sessionProvider, (_, __) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _SessionListenable(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final loc = state.matchedLocation;

      if (session.isLoading && !session.hasValue || session.hasError) {
        return loc == '/splash' ? null : '/splash';
      }
      final s = session.asData?.value;
      if (s == null) return _publicRoutes.contains(loc) ? null : '/login';
      if (s.user.mustChangePassword) return loc == '/change-password' ? null : '/change-password';
      if (_publicRoutes.contains(loc) || loc == '/splash' || loc == '/change-password') return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(path: '/change-password', builder: (_, __) => const ChangePasswordRequiredScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => ResponsiveShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (_, __) => const HomeScreen())]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/tab/sales', builder: (_, __) => const InvoicesScreen(isTab: true)),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/tab/purchases', builder: (_, __) => const PurchaseBillsScreen(isTab: true)),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/tab/parties', builder: (_, __) => const PartiesScreen(isTab: true)),
          ]),
          StatefulShellBranch(routes: [GoRoute(path: '/more', builder: (_, __) => const MoreScreen())]),
        ],
      ),
      // Parties
      _page('/parties', (s) => PartiesScreen(
            initialType: s.uri.queryParameters['type'],
            initialBalance: s.uri.queryParameters['balance'],
          )),
      _page('/parties/new', (s) => PartyFormScreen(initialType: s.uri.queryParameters['type'])),
      _page('/parties/:id', (s) => PartyDetailScreen(partyId: s.pathParameters['id']!)),
      _page('/parties/:id/edit', (s) => PartyFormScreen(partyId: s.pathParameters['id'])),
      // Products
      _page('/products', (_) => const ProductsScreen()),
      _page('/products/new', (_) => const ProductFormScreen()),
      _page('/products/:id', (s) => ProductDetailScreen(productId: s.pathParameters['id']!)),
      _page('/products/:id/edit', (s) => ProductFormScreen(productId: s.pathParameters['id'])),
      // Invoices
      _page('/invoices', (_) => const InvoicesScreen()),
      _page('/invoices/new', (s) => InvoiceFormScreen(partyId: s.uri.queryParameters['party'])),
      _page('/invoices/:id', (s) => InvoiceDetailScreen(invoiceId: s.pathParameters['id']!)),
      // Payment in
      _page('/payments-in', (_) => const PaymentsInScreen()),
      _page('/payments-in/new', (s) => PaymentInFormScreen(
            partyId: s.uri.queryParameters['party'],
            invoiceId: s.uri.queryParameters['invoice'],
          )),
      // Purchases
      _page('/purchases', (_) => const PurchaseBillsScreen()),
      _page('/purchases/new', (s) => PurchaseBillFormScreen(partyId: s.uri.queryParameters['party'])),
      _page('/purchases/:id', (s) => PurchaseBillDetailScreen(billId: s.pathParameters['id']!)),
      _page('/purchase-returns', (_) => const PurchaseReturnsScreen()),
      _page('/purchase-returns/new', (s) => PurchaseReturnFormScreen(billId: s.uri.queryParameters['bill'] ?? '')),
      _page('/purchase-returns/:id', (s) => PurchaseReturnDetailScreen(returnId: s.pathParameters['id']!)),
      _page('/purchase-orders', (_) => const PurchaseOrdersScreen()),
      _page('/purchase-orders/new', (_) => const PurchaseOrderFormScreen()),
      _page('/purchase-orders/:id', (s) => PurchaseOrderDetailScreen(orderId: s.pathParameters['id']!)),
      // Payment out
      _page('/payments-out', (_) => const PaymentsOutScreen()),
      _page('/payments-out/new', (s) => PaymentOutFormScreen(
            partyId: s.uri.queryParameters['party'],
            billId: s.uri.queryParameters['bill'],
          )),
      // Expenses
      _page('/expenses', (_) => const ExpensesScreen()),
      _page('/expenses/new', (_) => const ExpenseFormScreen()),
      _page('/expenses/categories', (_) => const ExpenseCategoriesScreen()),
      _page('/expenses/:id', (s) => ExpenseDetailScreen(expenseId: s.pathParameters['id']!)),
      _page('/expenses/:id/edit', (s) => ExpenseFormScreen(expenseId: s.pathParameters['id'])),
      // Cash & bank
      _page('/cash-bank', (_) => const CashBankScreen()),
      _page('/cash-bank/transactions', (_) => const CashTransactionsScreen()),
      _page('/cash-bank/routing', (_) => const PaymentRoutingScreen()),
      _page('/cash-bank/accounts/new', (_) => const BankAccountFormScreen()),
      _page('/cash-bank/accounts/:id/edit', (s) => BankAccountFormScreen(accountId: s.pathParameters['id'])),
      _page('/cash-bank/account/:id', (s) => CashAccountScreen(accountId: s.pathParameters['id']!)),
      // Profit distribution
      _page('/profit-distribution', (_) => const ProfitDistributionScreen()),
      _page('/profit-distribution/new', (_) => const ProfitPayoutFormScreen()),
      // Accounting (read-only)
      _page('/accounting', (_) => const AccountingScreen()),
      _page('/accounting/trial-balance', (_) => const TrialBalanceScreen()),
      _page('/accounting/profit-loss', (_) => const ProfitLossScreen()),
      _page('/accounting/balance-sheet', (_) => const BalanceSheetScreen()),
      _page('/accounting/ledger/:id', (s) => GeneralLedgerScreen(accountId: s.pathParameters['id']!)),
      // Reports & GST
      _page('/reports', (_) => const ReportsHubScreen()),
      _page('/reports/daily', (_) => const PeriodReportScreen()),
      _page('/reports/profit-loss', (_) => const ProfitLossReportScreen()),
      _page('/reports/daily-profit', (_) => const DailyProfitScreen()),
      _page('/reports/billwise-profit', (_) => const BillwiseProfitScreen()),
      _page('/reports/stock', (_) => const StockReportScreen()),
      _page('/reports/party-balance', (_) => const PartyBalanceReportScreen()),
      _page('/reports/outstanding', (_) => const OutstandingScreen()),
      _page('/reports/customers', (_) => const RankReportScreen(kind: RankKind.customers)),
      _page('/reports/products', (_) => const RankReportScreen(kind: RankKind.products)),
      _page('/reports/categories', (_) => const RankReportScreen(kind: RankKind.categories)),
      _page('/reports/payments', (_) => const PaymentsAnalyticsScreen()),
      _page('/gst', (_) => const GstScreen()),
      // Other sales documents
      _page('/estimates', (_) => const EstimatesScreen()),
      _page('/estimates/new', (s) => EstimateFormScreen(partyId: s.uri.queryParameters['party'])),
      _page('/estimates/:id', (s) => EstimateDetailScreen(estimateId: s.pathParameters['id']!)),
      _page('/estimates/:id/edit', (s) => EstimateFormScreen(estimateId: s.pathParameters['id'])),
      _page('/delivery-challans', (_) => const ChallansScreen()),
      _page('/delivery-challans/new', (s) => ChallanFormScreen(partyId: s.uri.queryParameters['party'])),
      _page('/delivery-challans/:id', (s) => ChallanDetailScreen(challanId: s.pathParameters['id']!)),
      for (final k in ReturnKind.values) ...[
        _page('/${k.route}', (_) => ReturnDocsScreen(kind: k)),
        _page('/${k.route}/new', (s) => ReturnDocFormScreen(
              kind: k,
              sourceId: s.uri.queryParameters[k.fromBill ? 'bill' : 'invoice'] ?? '',
            )),
        _page('/${k.route}/:id', (s) => ReturnDocDetailScreen(kind: k, docId: s.pathParameters['id']!)),
      ],
      _page('/discounts', (_) => const DiscountsScreen()),
      // Inventory
      _page('/stock', (_) => const InventoryScreen()),
      _page('/stock/movements', (_) => const MovementsScreen()),
      _page('/stock/transfers', (_) => const TransfersScreen()),
      _page('/stock/transfers/new', (_) => const TransferFormScreen()),
      _page('/stock/transfers/:id', (s) => TransferDetailScreen(transferId: s.pathParameters['id']!)),
      _page('/warehouses', (_) => const WarehousesScreen()),
      _page('/warehouses/new', (_) => const WarehouseFormScreen()),
      _page('/warehouses/:id', (s) => WarehouseDetailScreen(warehouseId: s.pathParameters['id']!)),
      _page('/warehouses/:id/edit', (s) => WarehouseFormScreen(warehouseId: s.pathParameters['id'])),
      _page('/categories', (_) => const CategoriesScreen()),
      GoRoute(
        path: '/m/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, state) => ComingSoonScreen(moduleId: state.pathParameters['id']!),
      ),
    ],
  );
});

/// Full-screen page above the tab shell (hides the bottom bar).
GoRoute _page(String path, Widget Function(GoRouterState) build) => GoRoute(
      path: path,
      parentNavigatorKey: _rootKey,
      builder: (_, state) => build(state),
    );
