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
import 'package:truerp_mobile/features/inventory/ui/categories_screen.dart';
import 'package:truerp_mobile/features/inventory/ui/inventory_screen.dart';
import 'package:truerp_mobile/features/inventory/ui/movements_screen.dart';
import 'package:truerp_mobile/features/inventory/ui/transfers_screens.dart';
import 'package:truerp_mobile/features/inventory/ui/warehouses_screens.dart';
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
import 'package:truerp_mobile/features/reports/ui/business_reports.dart';
import 'package:truerp_mobile/features/reports/ui/gst_screen.dart';
import 'package:truerp_mobile/features/reports/ui/reports_hub_screen.dart';
import 'package:truerp_mobile/features/reports/ui/stock_party_reports.dart';
import 'package:truerp_mobile/features/sales_docs/ui/challans_screens.dart';
import 'package:truerp_mobile/features/sales_docs/ui/discounts_screen.dart';
import 'package:truerp_mobile/features/sales_docs/ui/estimates_screens.dart';
import 'package:truerp_mobile/features/sales_docs/ui/returns_screens.dart';
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
    {'id': 'ii1', 'product_id': 'pr1', 'description': 'Basmati Rice Premium Long Grain 25kg Bag', 'quantity': 2, 'unit': 'BAG',
     'unit_price': 2450.5, 'discount': 5, 'total': 4655.95},
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

Map<String, dynamic> _m(num amount, [int count = 0]) => {'total_amount': amount, 'count': count};
final _periodReport = {
  'label': 'November 2026', 'start_date': '2026-11-01', 'end_date': '2026-11-30',
  'sales': _m(9876543.21, 1234), 'purchases': _m(4567890, 210), 'expenses': _m(123456, 40), 'payments_in': _m(8765432, 900),
  'payments_out': _m(4000000, 150), 'sales_returns': _m(12000, 3), 'purchase_returns': _m(5000, 1), 'credit_notes': _m(0),
  'debit_notes': _m(0), 'profit_distributions': _m(250000, 1), 'accounts_payable': _m(56789, 4), 'accounts_payable_total': 345678,
  'gst_collected': 0, 'net_cash_flow': 4765432, 'daily_profit': 1234567, 'product_profit': 2345678,
  'payments_by_method': [
    {'method': 'cash', 'label': 'Cash', 'in': _m(1234567, 300), 'out': _m(345678, 20)},
    {'method': 'bank_transfer', 'label': 'Bank Transfer', 'in': _m(7530865, 600), 'out': _m(3654322, 130)},
  ],
  'expense_lines': [{'category': 'Electricity & Utilities', 'description': 'November electricity bill for the main warehouse', 'amount': 11800, 'date': '2026-11-20'}],
};

final _quote = {
  'id': 'q1', 'quotation_number': 'EST-2026-000045', 'status': 'sent', 'date': '2026-11-20T00:00:00Z',
  'valid_until': '2026-11-01T00:00:00Z', 'party_id': 'p1', 'party': _party, 'sub_total': 4901, 'discount_total': 245.05,
  'quotation_discount': 100, 'additional_charges': 250, 'additional_charge_items': [{'label': 'Freight', 'amount': 250}],
  'total_amount': 4805.95, 'notes': 'Prices valid for 15 days', 'terms': '50% advance', 'version': 2,
  'items': [{'description': 'Basmati Rice Premium Long Grain 25kg Bag', 'quantity': 2, 'unit': 'BAG', 'unit_price': 2450.5, 'discount': 5, 'total': 4655.95}],
};
final _challan = {
  'id': 'c1', 'challan_number': 'DC-0012', 'status': 'draft', 'date': '2026-11-21T00:00:00Z', 'party_id': 'p1', 'party': _party,
  'sub_total': 4901, 'total_quantity': 2, 'vehicle_number': 'KA01AB1234', 'transport_mode': 'road', 'notes': 'Handle with care',
  'items': [{'description': 'Basmati Rice Premium Long Grain 25kg Bag', 'quantity': 2, 'unit': 'BAG', 'unit_price': 2450.5, 'total': 4901}],
};
final _returnItems = [{'description': 'Basmati Rice Premium Long Grain 25kg Bag', 'quantity': 1, 'unit_price': 2327.98, 'total': 2327.98}];
final _salesReturn = {'id': 'sr1', 'return_number': 'SR-0004', 'status': 'draft', 'date': '2026-11-22T00:00:00Z', 'amount': 2327.98,
  'party': _party, 'invoice_id': 'i1', 'invoice': {'invoice_number': 'INV-2026-000123'}, 'refund_mode': 'credit_note', 'reason': 'Damaged', 'items': _returnItems};
final _creditNote = {'id': 'cn1', 'credit_note_number': 'CN-0002', 'status': 'issued', 'date': '2026-11-22T00:00:00Z', 'total_amount': 500,
  'party': _party, 'invoice_id': 'i1', 'refund_mode': 'cash', 'items': _returnItems};
final _debitNote = {'id': 'dn1', 'debit_note_number': 'DN-0001', 'status': 'cancelled', 'cancel_reason': 'Raised by mistake', 'date': '2026-11-22T00:00:00Z',
  'total_amount': 2205, 'party': _vendor, 'purchase_bill_id': 'b1', 'refund_mode': 'debit_note', 'items': _returnItems};

const _wh = {'id': 'w1', 'name': 'Main Godown, Peenya Industrial Area', 'code': 'MAIN', 'city': 'Bengaluru', 'state': 'Karnataka', 'is_default': true, 'is_active': true};
const _wh2 = {'id': 'w2', 'name': 'Shop Floor', 'code': 'SHOP', 'is_active': true};
final _stockRow = {
  'id': 's1', 'product_id': 'pr1', 'product': {'name': 'Basmati Rice Premium Long Grain 25kg Bag', 'unit': 'BAG'}, 'outlet_id': 'w1',
  'outlet_name': 'Main Godown, Peenya Industrial Area', 'batch_no': 'B-2026-11', 'available_qty': 104, 'reserved_qty': 4,
  'average_cost': 2100, 'exp_date': '2026-12-01T00:00:00Z',
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
    if (path == '/dashboard/periodic-report') return _periodReport;
    if (path == '/dashboard/profit-loss-report') {
      return {'label': 'November 2026', 'sales': _m(9876543, 1234), 'sales_returns': _m(12000), 'purchases': _m(4567890, 210),
        'purchase_returns': _m(5000), 'opening_stock': 2345678, 'closing_stock': 2456789, 'gross_profit': 5412345,
        'other_income': _m(1000), 'indirect_expenses': _m(2000), 'expenses': _m(123456, 40), 'net_profit': -5000,
        'other_income_lines': [{'name': 'Interest received from fixed deposit', 'amount': 1000}],
        'indirect_expense_lines': [{'name': 'Bank charges', 'amount': 2000}],
        'expense_lines': _periodReport['expense_lines']};
    }
    if (path == '/dashboard/daily-profit-report') {
      Map<String, dynamic> row(String d, num n) => {'date': d, 'sales': 123456.78, 'cogs': 100000, 'gross_profit': 23456.78, 'expenses': 1200, 'net_profit': n};
      return {'label': 'November 2026', 'total_days': 2, 'rows': [row('2026-11-23', 22256.78), row('2026-11-22', -1500)], 'totals': row('', 20756.78)};
    }
    if (path == '/dashboard/billwise-profit-report') {
      return {'label': 'November 2026', 'bill_count': 2, 'sale_amount': 9000, 'cost_amount': 7000, 'profit': 2000, 'margin_pct': 22.2,
        'bills': [
          {'invoice_id': 'i1', 'invoice_number': 'INV-2026-000123', 'date': '2026-11-20', 'party_name': 'Sharma General Stores Private Limited',
           'sale_amount': 4655.95, 'cost_amount': 4200, 'profit': 455.95, 'margin_pct': 9.8,
           'items': [{'description': 'Basmati Rice Premium Long Grain 25kg Bag', 'quantity': 2, 'sale_amount': 4655.95, 'cost_amount': 4200, 'profit': 455.95}]},
          {'invoice_id': 'i2', 'invoice_number': 'INV-2', 'date': '2026-11-21', 'party_name': '', 'sale_amount': 100, 'cost_amount': 150, 'profit': -50, 'margin_pct': -50},
        ]};
    }
    if (path == '/dashboard/stock-report') {
      return {'label': 'November 2026', 'opening_stock': 2345678, 'closing_stock': 2456789, 'stock_change': 111111, 'lines': [
        {'product_id': 'pr1', 'product_name': 'Basmati Rice Premium Long Grain 25kg Bag', 'category': 'Grocery', 'unit': 'BAG',
         'opening_qty': 100, 'in_qty': 40, 'out_qty': 36, 'closing_qty': 104, 'closing_value': 218400},
        {'product_id': 'pr2', 'product_name': 'Idle item', 'closing_qty': 5, 'closing_value': 50},
      ]};
    }
    if (path == '/dashboard/party-balance-report') {
      return {'closing_receivable': 1234567, 'closing_payable': -45000, 'net_closing': 1189567, 'lines': [
        {'party_id': 'p1', 'party_name': 'Sharma General Stores Private Limited', 'party_type': 'customer', 'debit': 2000000, 'credit': 765432, 'closing_balance': 1234567.89},
        {'party_id': 'p2', 'party_name': 'Acme Supplies', 'party_type': 'vendor', 'closing_balance': -45000},
        {'party_id': 'p3', 'party_name': 'Settled Co', 'closing_balance': 0},
      ]};
    }
    if (path == '/reports/outstanding') {
      return {'summary': {'total_outstanding': 4444444, 'overdue_count': 5},
        'aging': {'current': 1000000, 'days_1_30': 2000000, 'days_31_60': 444444, 'days_61_90': 500000, 'days_90_plus': 500000},
        'by_party': [{'party_id': 'p1', 'party_name': 'Sharma General Stores Private Limited', 'invoice_count': 12, 'outstanding': 1234567}],
        'invoices': [{'id': 'i1', 'invoice_number': 'INV-2026-000123', 'party_name': 'Sharma General Stores Private Limited', 'date': '2026-10-01', 'outstanding': 2706, 'days_overdue': 53}]};
    }
    if (path == '/reports/customers') {
      return {'summary': {'customer_count': 2, 'total_paid_sales': 1500000}, 'customers': [
        {'party_id': 'p1', 'name': 'Sharma General Stores Private Limited', 'invoice_count': 42, 'total_sales': 999999.99, 'total_outstanding': 1234567},
        {'party_id': 'p9', 'name': 'Walk-in', 'invoice_count': 1, 'total_sales': 500}]};
    }
    if (path == '/reports/products') {
      return {'summary': {'product_count': 1, 'total_revenue': 999999}, 'products': [
        {'product_id': 'pr1', 'name': 'Basmati Rice Premium Long Grain 25kg Bag', 'quantity_sold': 412.5, 'unit': 'BAG', 'revenue': 999999, 'share_percent': 100}]};
    }
    if (path == '/reports/categories') {
      return {'summary': {'category_count': 2, 'total_revenue': 1000}, 'categories': [
        {'category': 'Grocery', 'product_count': 12, 'quantity_sold': 40, 'revenue': 900, 'share_percent': 90}, {'category': '', 'revenue': 100}]};
    }
    if (path == '/reports/payments') {
      return {'summary': {'total_in': 900, 'total_out': 300}, 'by_mode': [
        {'mode': 'cash', 'direction': 'in', 'total': 500}, {'mode': 'bank_transfer', 'direction': 'out', 'total': 300}, {'mode': '', 'direction': 'in', 'total': 400}]};
    }
    if (path == '/gst/summary') {
      return {'summary': {'total_sales': 9876543, 'total_purchases': 4567890, 'cgst': 0, 'sgst': 0, 'igst': 0, 'total_tax': 0, 'liability': -234567},
        'details': {'sales': {'taxable_value': 9876543}, 'purchases': {'taxable_value': 4300000, 'cgst': 117283.5, 'sgst': 117283.5, 'igst': 0}, 'itc': {'total_itc': 234567}}};
    }
    if (path == '/gst/gstr1') {
      return {'data': [{'invoice_number': 'INV-2026-000123', 'invoice_date': '2026-11-20', 'party_name': 'Sharma General Stores Private Limited',
        'party_gstin': '29ABCDE1234F1Z5', 'invoice_value': 4706, 'taxable_value': 4706}]};
    }
    if (path == '/gst/gstr2') return {'data': const []};
    if (path == '/gst/gstr3b') return {'total_tax_liability': 0, 'total_itc': 234567, 'tax_payable': 0};
    if (path == '/gst/einvoice/history') {
      return [{'invoice_id': 'i1', 'invoice_number': 'INV-2026-000123', 'irn': 'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6abcd', 'status': 'generated', 'generated_at': '2026-11-20T10:00:00Z'}];
    }
    if (path == '/gst/ewaybill/history') return const [];
    if (path == '/quotations/next-number') return {'quotation_number': 'EST-2026-000046'};
    if (path.startsWith('/quotations/')) return _quote;
    if (path == '/delivery-challans/next-number') return {'challan_number': 'DC-0013'};
    if (path.startsWith('/delivery-challans/')) return _challan;
    if (path.startsWith('/sales-returns/')) return _salesReturn;
    if (path.startsWith('/credit-notes/')) return _creditNote;
    if (path.startsWith('/debit-notes/')) return _debitNote;
    if (path == '/discounts/transactions') return {'summary': {'total_discount': 12345.5}};
    if (path == '/inventory/stats') return {'total_value': 2456789, 'total_qty': 12345, 'product_count': 456, 'outlet_count': 2, 'low_stock_count': 12};
    if (path == '/inventory/stocks') return [_stockRow];
    if (path == '/inventory/movements/summary') {
      return {'summary': {'opening_qty': 1200, 'opening_value': 2345678, 'in_qty': 400, 'out_qty': 360, 'closing_qty': 1240, 'closing_value': 2456789}};
    }
    if (path == '/warehouses') return [_wh, _wh2, {'id': 'w3', 'name': 'Old store', 'code': 'OLD', 'is_active': false}];
    if (path.endsWith('/stock') && path.startsWith('/warehouses/')) {
      return {'items': [{'item_name': 'Basmati Rice Premium Long Grain 25kg Bag', 'stock_qty': 104, 'cost_price': 2100, 'value': 218400}], 'total_value': 218400};
    }
    if (path.startsWith('/inventory/transfers/')) {
      return {'id': 't1', 'from_outlet_id': 'w1', 'to_outlet_id': 'w2', 'status': 'submitted', 'total_items': 1, 'total_quantity': 10,
        'sent_date': '2026-11-22T00:00:00Z', 'created_at': '2026-11-21T00:00:00Z', 'notes': 'For weekend sale',
        'items': [{'product_id': 'pr1', 'quantity': 10, 'sent_quantity': 10}]};
    }
    if (path == '/categories') return [{'id': 'c1', 'name': 'Grocery', 'description': 'Rice, dal, oil', 'is_active': true}, {'id': 'c2', 'name': 'Old', 'is_active': false}];
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
      '/quotations' => [_quote, {..._quote, 'id': 'q2', 'status': 'converted', 'converted_to_invoice_id': 'i1'}],
      '/delivery-challans' => [_challan, {..._challan, 'id': 'c2', 'status': 'delivered'}],
      '/sales-returns' => {'data': [_salesReturn]},
      '/credit-notes' => {'data': [_creditNote]},
      '/debit-notes' => {'data': [_debitNote]},
      '/discounts/transactions' => {'transactions': [
          {'id': 'i1', 'type': 'sale_invoice', 'type_label': 'Sale Invoice', 'reference': 'INV-2026-000123', 'date': '2026-11-20',
           'party_name': 'Sharma General Stores Private Limited', 'total_discount': 345.05, 'document_total': 4706},
        ], 'total': 1, 'page': 1, 'per_page': 25},
      '/inventory/stocks' => {'data': [_stockRow, {..._stockRow, 'id': 's2', 'available_qty': 0, 'exp_date': null, 'batch_no': ''}], 'total': 2, 'page': 1, 'per_page': 25},
      '/inventory/alerts/low-stock' => {'data': [
          {'product_id': 'pr1', 'product_name': 'Basmati Rice Premium Long Grain 25kg Bag', 'current_stock': 4, 'min_stock': 10, 'outlet_name': 'Main'},
          {'product_id': 'pr3', 'product_name': 'Sugar', 'current_stock': 0, 'min_stock': 5},
        ], 'total': 2, 'page': 1, 'per_page': 25},
      '/inventory/entries' => {'data': [
          {'id': 'e1', 'item_name': 'Basmati Rice Premium Long Grain 25kg Bag', 'entry_type': 'purchase', 'quantity': 40, 'approval_status': 'pending', 'outlet_name': 'Main Godown', 'entry_date': '2026-11-20T00:00:00Z'},
        ], 'total': 1, 'page': 1, 'per_page': 25},
      '/inventory/movements' => {'data': [
          {'id': 'm1', 'date': '2026-11-20', 'product_id': 'pr1', 'product_name': 'Basmati Rice Premium Long Grain 25kg Bag', 'transaction_type': 'purchase',
           'type_label': 'Purchase', 'document_no': 'VND/2026-27/000981', 'reference_type': 'purchase_bill', 'reference_id': 'b1', 'qty_in': 40, 'stock': 104, 'unit': 'BAG', 'outlet_name': 'Main Godown'},
          {'id': 'm2', 'date': '2026-11-21', 'product_id': 'pr1', 'product_name': 'Basmati Rice', 'transaction_type': 'sale', 'type_label': 'Sale', 'qty_out': 2, 'stock': 102},
        ], 'total': 2, 'page': 1, 'per_page': 50},
      '/inventory/transfers' => {'data': [
          {'id': 't1', 'from_outlet_id': 'w1', 'to_outlet_id': 'w2', 'status': 'submitted', 'total_items': 1, 'total_quantity': 10, 'created_at': '2026-11-21T00:00:00Z'},
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
    'reports hub': () => const ReportsHubScreen(),
    'period report': () => const PeriodReportScreen(),
    'profit & loss report': () => const ProfitLossReportScreen(),
    'daily profit': () => const DailyProfitScreen(),
    'billwise profit': () => const BillwiseProfitScreen(),
    'stock report': () => const StockReportScreen(),
    'party balances': () => const PartyBalanceReportScreen(),
    'outstanding': () => const OutstandingScreen(),
    'top customers': () => const RankReportScreen(kind: RankKind.customers),
    'top products': () => const RankReportScreen(kind: RankKind.products),
    'categories report': () => const RankReportScreen(kind: RankKind.categories),
    'payments analytics': () => const PaymentsAnalyticsScreen(),
    'gst': () => const GstScreen(),
    'estimates': () => const EstimatesScreen(),
    'estimate detail': () => const EstimateDetailScreen(estimateId: 'q1'),
    'estimate form (new)': () => const EstimateFormScreen(partyId: 'p1'),
    'estimate form (edit)': () => const EstimateFormScreen(estimateId: 'q1'),
    'challans': () => const ChallansScreen(),
    'challan detail': () => const ChallanDetailScreen(challanId: 'c1'),
    'challan form': () => const ChallanFormScreen(partyId: 'p1'),
    'sales returns': () => const ReturnDocsScreen(kind: ReturnKind.salesReturn),
    'sales return detail': () => const ReturnDocDetailScreen(kind: ReturnKind.salesReturn, docId: 'sr1'),
    'sales return form': () => const ReturnDocFormScreen(kind: ReturnKind.salesReturn, sourceId: 'i1'),
    'credit notes': () => const ReturnDocsScreen(kind: ReturnKind.creditNote),
    'credit note detail': () => const ReturnDocDetailScreen(kind: ReturnKind.creditNote, docId: 'cn1'),
    'credit note form': () => const ReturnDocFormScreen(kind: ReturnKind.creditNote, sourceId: 'i1'),
    'debit notes': () => const ReturnDocsScreen(kind: ReturnKind.debitNote),
    'debit note detail': () => const ReturnDocDetailScreen(kind: ReturnKind.debitNote, docId: 'dn1'),
    'debit note form': () => const ReturnDocFormScreen(kind: ReturnKind.debitNote, sourceId: 'b1'),
    'discounts': () => const DiscountsScreen(),
    'inventory': () => const InventoryScreen(),
    'movements': () => const MovementsScreen(),
    'transfers': () => const TransfersScreen(),
    'transfer detail': () => const TransferDetailScreen(transferId: 't1'),
    'transfer form': () => const TransferFormScreen(),
    'warehouses': () => const WarehousesScreen(),
    'warehouse detail': () => const WarehouseDetailScreen(warehouseId: 'w1'),
    'warehouse form (new)': () => const WarehouseFormScreen(),
    'warehouse form (edit)': () => const WarehouseFormScreen(warehouseId: 'w1'),
    'categories': () => const CategoriesScreen(),
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
