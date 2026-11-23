import 'package:flutter/material.dart';

import '../auth/session.dart';

/// One destination in the module hub. Mirrors
/// `frontend/components/layout/nav-config.ts`.
class AppModule {
  const AppModule({
    required this.id,
    required this.name,
    required this.icon,
    required this.route,
    this.phase = 0,
    this.superAdminOnly = false,
    this.userManagementOnly = false,
    this.keywords = '',
  });

  final String id;
  final String name;
  final IconData icon;

  /// Route path when built; modules from later phases open a placeholder.
  final String route;

  /// Roadmap phase this module ships in (see ROADMAP.md).
  final int phase;
  final bool superAdminOnly;
  final bool userManagementOnly;
  final String keywords;

  bool get isBuilt => builtPhases.contains(phase);

  bool visibleTo(AppUser? user) {
    if (superAdminOnly && !(user?.isSuperAdmin ?? false)) return false;
    if (userManagementOnly && !(user?.canManageUsers ?? false)) return false;
    return true;
  }
}

class ModuleGroup {
  const ModuleGroup(this.name, this.accent, this.icon, this.modules);
  final String name;
  final Color accent;
  final IconData icon;
  final List<AppModule> modules;
}

/// Roadmap phases that are built. Modules from other phases open a
/// "coming soon" page. Phases don't land strictly in order.
const builtPhases = {0, 1, 2, 3, 5, 6};

const moduleGroups = <ModuleGroup>[
  ModuleGroup('Parties', Color(0xFF7C3AED), Icons.groups_rounded, [
    AppModule(id: 'parties', name: 'All Parties', icon: Icons.contacts_rounded, route: '/parties', phase: 1),
    AppModule(id: 'customers', name: 'Customers', icon: Icons.person_rounded, route: '/parties?type=customer', phase: 1),
    AppModule(id: 'vendors', name: 'Vendors', icon: Icons.factory_rounded, route: '/parties?type=vendor', phase: 1, keywords: 'supplier'),
  ]),
  ModuleGroup('Sales', Color(0xFF2563EB), Icons.trending_up_rounded, [
    AppModule(id: 'invoices', name: 'Invoices', icon: Icons.receipt_long_rounded, route: '/invoices', phase: 1, keywords: 'bill sale'),
    AppModule(id: 'estimates', name: 'Estimates', icon: Icons.request_quote_rounded, route: '/estimates', phase: 3, keywords: 'quotation'),
    AppModule(id: 'challans', name: 'Delivery Challans', icon: Icons.local_shipping_rounded, route: '/delivery-challans', phase: 3),
    AppModule(id: 'sales-returns', name: 'Sales Return', icon: Icons.assignment_return_rounded, route: '/sales-returns', phase: 3),
    AppModule(id: 'discounts', name: 'Discounts', icon: Icons.percent_rounded, route: '/discounts', phase: 3),
  ]),
  ModuleGroup('Purchases', Color(0xFFEA580C), Icons.shopping_bag_rounded, [
    AppModule(id: 'purchase-bills', name: 'Purchase Invoices', icon: Icons.description_rounded, route: '/purchases', phase: 2, keywords: 'bill'),
    AppModule(id: 'purchase-returns', name: 'Purchase Return', icon: Icons.undo_rounded, route: '/purchase-returns', phase: 2),
    AppModule(id: 'purchase-orders', name: 'Purchase Orders', icon: Icons.shopping_cart_checkout_rounded, route: '/purchase-orders', phase: 2),
  ]),
  ModuleGroup('Payments', Color(0xFF6366F1), Icons.payments_rounded, [
    AppModule(id: 'payment-in', name: 'Payment In', icon: Icons.call_received_rounded, route: '/payments-in', phase: 1, keywords: 'receipt'),
    AppModule(id: 'payment-out', name: 'Payment Out', icon: Icons.call_made_rounded, route: '/payments-out', phase: 2),
  ]),
  ModuleGroup('Credit / Debit', Color(0xFF0F766E), Icons.balance_rounded, [
    AppModule(id: 'credit-notes', name: 'Credit Notes', icon: Icons.note_add_rounded, route: '/credit-notes', phase: 3),
    AppModule(id: 'debit-notes', name: 'Debit Notes', icon: Icons.note_alt_rounded, route: '/debit-notes', phase: 3),
  ]),
  ModuleGroup('Inventory', Color(0xFF0891B2), Icons.inventory_2_rounded, [
    AppModule(id: 'products', name: 'Products', icon: Icons.inventory_2_rounded, route: '/products', phase: 1, keywords: 'item'),
    AppModule(id: 'categories', name: 'Categories', icon: Icons.sell_rounded, route: '/categories', phase: 4),
    AppModule(id: 'stock', name: 'Stock', icon: Icons.warehouse_rounded, route: '/stock', phase: 4),
    AppModule(id: 'movements', name: 'Stock Movement', icon: Icons.swap_horiz_rounded, route: '/stock/movements', phase: 4),
    AppModule(id: 'warehouses', name: 'Warehouses', icon: Icons.domain_rounded, route: '/warehouses', phase: 4),
  ]),
  ModuleGroup('Money', Color(0xFF16A34A), Icons.account_balance_wallet_rounded, [
    AppModule(id: 'expenses', name: 'Expenses', icon: Icons.receipt_rounded, route: '/expenses', phase: 2),
    AppModule(id: 'cash-bank', name: 'Cash & Bank', icon: Icons.account_balance_rounded, route: '/cash-bank', phase: 5),
    AppModule(id: 'profit-distribution', name: 'Profit Distribution', icon: Icons.volunteer_activism_rounded, route: '/profit-distribution', phase: 5),
    AppModule(id: 'accounting', name: 'Accounting', icon: Icons.menu_book_rounded, route: '/accounting', phase: 5, keywords: 'ledger journal'),
  ]),
  ModuleGroup('Reports', Color(0xFF9333EA), Icons.bar_chart_rounded, [
    AppModule(id: 'reports', name: 'All Reports', icon: Icons.grid_view_rounded, route: '/reports', phase: 6),
    AppModule(id: 'daily-report', name: 'Day & Period', icon: Icons.today_rounded, route: '/reports/daily', phase: 6, keywords: 'daily summary'),
    AppModule(id: 'profit-loss', name: 'Profit & Loss', icon: Icons.balance_rounded, route: '/reports/profit-loss', phase: 6),
    AppModule(id: 'daily-profit', name: 'Daily Profit', icon: Icons.show_chart_rounded, route: '/reports/daily-profit', phase: 6),
    AppModule(id: 'billwise-profit', name: 'Bill-wise Profit', icon: Icons.receipt_long_rounded, route: '/reports/billwise-profit', phase: 6, keywords: 'margin'),
    AppModule(id: 'stock-report', name: 'Stock Report', icon: Icons.warehouse_rounded, route: '/reports/stock', phase: 6),
    AppModule(id: 'party-balance', name: 'Party Balances', icon: Icons.groups_rounded, route: '/reports/party-balance', phase: 6),
    AppModule(id: 'outstanding', name: 'Outstanding', icon: Icons.hourglass_bottom_rounded, route: '/reports/outstanding', phase: 6, keywords: 'aging overdue receivable'),
    AppModule(id: 'gst', name: 'GST Reports', icon: Icons.calculate_rounded, route: '/gst', phase: 6, keywords: 'gstr tax einvoice'),
  ]),
  ModuleGroup('HR & Payroll', Color(0xFFDB2777), Icons.badge_rounded, [
    AppModule(id: 'staff', name: 'Staff', icon: Icons.people_alt_rounded, route: '/staff', phase: 7, keywords: 'employee'),
    AppModule(id: 'attendance', name: 'Attendance', icon: Icons.event_available_rounded, route: '/attendance', phase: 7),
    AppModule(id: 'payroll', name: 'Payroll', icon: Icons.payments_rounded, route: '/payroll', phase: 7, keywords: 'salary'),
  ]),
  ModuleGroup('POS', Color(0xFF0284C7), Icons.point_of_sale_rounded, [
    AppModule(id: 'pos', name: 'POS Terminal', icon: Icons.point_of_sale_rounded, route: '/pos', phase: 8, keywords: 'billing counter'),
    AppModule(id: 'pos-sessions', name: 'Session History', icon: Icons.history_rounded, route: '/pos/sessions', phase: 8),
  ]),
  ModuleGroup('Marketing', Color(0xFFCA8A04), Icons.campaign_rounded, [
    AppModule(id: 'loyalty', name: 'Loyalty Program', icon: Icons.card_giftcard_rounded, route: '/loyalty', phase: 9),
    AppModule(id: 'sms', name: 'SMS Marketing', icon: Icons.sms_rounded, route: '/marketing/sms', phase: 9),
    AppModule(id: 'email', name: 'Email Marketing', icon: Icons.email_rounded, route: '/marketing/email', phase: 9),
    AppModule(id: 'whatsapp', name: 'WhatsApp Marketing', icon: Icons.chat_rounded, route: '/marketing/whatsapp', phase: 9),
  ]),
  ModuleGroup('Admin', Color(0xFFDC2626), Icons.shield_rounded, [
    AppModule(id: 'notifications', name: 'Notifications', icon: Icons.notifications_rounded, route: '/notifications', phase: 9),
    AppModule(id: 'support', name: 'Support', icon: Icons.support_agent_rounded, route: '/support', phase: 9, keywords: 'help ticket'),
    AppModule(id: 'business', name: 'Business Profile', icon: Icons.storefront_rounded, route: '/settings/business', phase: 10),
    AppModule(id: 'users', name: 'User Management', icon: Icons.manage_accounts_rounded, route: '/users', phase: 10, userManagementOnly: true),
    AppModule(id: 'stores', name: 'Stores', icon: Icons.store_mall_directory_rounded, route: '/stores', phase: 10, superAdminOnly: true),
    AppModule(id: 'audit', name: 'Audit Trail', icon: Icons.policy_rounded, route: '/audit', phase: 10, superAdminOnly: true),
  ]),
];

AppModule? moduleById(String id) {
  for (final g in moduleGroups) {
    for (final m in g.modules) {
      if (m.id == id) return m;
    }
  }
  return null;
}

ModuleGroup? groupOf(String moduleId) {
  for (final g in moduleGroups) {
    if (g.modules.any((m) => m.id == moduleId)) return g;
  }
  return null;
}
