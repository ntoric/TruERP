import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/ui/change_password_required_screen.dart';
import '../../features/auth/ui/forgot_password_screen.dart';
import '../../features/auth/ui/login_screen.dart';
import '../../features/auth/ui/register_screen.dart';
import '../../features/dashboard/ui/home_screen.dart';
import '../../features/invoices/ui/invoice_detail_screen.dart';
import '../../features/invoices/ui/invoice_form_screen.dart';
import '../../features/invoices/ui/invoices_screen.dart';
import '../../features/more/more_screen.dart';
import '../../features/parties/ui/parties_screen.dart';
import '../../features/parties/ui/party_detail_screen.dart';
import '../../features/parties/ui/party_form_screen.dart';
import '../../features/payments/ui/payment_in_form_screen.dart';
import '../../features/payments/ui/payments_in_screen.dart';
import '../../features/products/ui/product_detail_screen.dart';
import '../../features/products/ui/product_form_screen.dart';
import '../../features/products/ui/products_screen.dart';
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
            GoRoute(path: '/tab/purchases', builder: (_, __) => const ComingSoonScreen(moduleId: 'purchase-bills')),
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
