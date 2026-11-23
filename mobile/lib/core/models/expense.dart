import '../api/json.dart';
import 'payment.dart';

class ExpenseItem {
  ExpenseItem({required this.description, this.quantity = 1, this.unitPrice = 0, this.total = 0});

  String description;
  double quantity;
  double unitPrice;

  /// Server-computed (includes GST when the expense is "with GST").
  final double total;

  double get amount => quantity * unitPrice;

  factory ExpenseItem.fromJson(JsonMap j) => ExpenseItem(
        description: asString(j['description']),
        quantity: asDouble(j['quantity'], 1),
        unitPrice: asDouble(j['unit_price']),
        total: asDouble(j['total']),
      );

  JsonMap toJson() => {'description': description.trim(), 'quantity': quantity, 'unit_price': unitPrice};
}

class Expense {
  const Expense({
    required this.id,
    required this.number,
    required this.category,
    required this.amount,
    required this.date,
    this.description = '',
    this.subTotal = 0,
    this.taxTotal = 0,
    this.withGst = false,
    this.taxRate = 0,
    this.vendor = '',
    this.originalInvoiceNum = '',
    this.paymentMode = '',
    this.bankAccountId,
    this.bankAccountLabel,
    this.notes = '',
    this.status = 'active',
    this.cancelReason = '',
    this.items = const [],
  });

  final String id;
  final String number;
  final String category;
  final String description;
  final double amount;
  final double subTotal;
  final double taxTotal;
  final bool withGst;
  final double taxRate;
  final DateTime? date;
  final String vendor;
  final String originalInvoiceNum;
  final String paymentMode;
  final String? bankAccountId;
  final String? bankAccountLabel;
  final String notes;
  final String status;
  final String cancelReason;
  final List<ExpenseItem> items;

  bool get isCancelled => status == 'cancelled';

  /// Best one-line description for lists.
  String get title {
    if (description.trim().isNotEmpty) return description.trim();
    if (items.isNotEmpty && items.first.description.isNotEmpty) {
      return items.length == 1 ? items.first.description : '${items.first.description} +${items.length - 1}';
    }
    return category.isEmpty ? 'Expense' : category;
  }

  factory Expense.fromJson(JsonMap j) {
    final bank = asMap(j['bank_account']);
    return Expense(
      id: asString(j['id']),
      number: asString(j['expense_number']),
      category: asString(j['category']),
      description: asString(j['description']),
      amount: asDouble(j['amount']),
      subTotal: asDouble(j['sub_total']),
      taxTotal: asDouble(j['tax_total']),
      withGst: asBool(j['with_gst']),
      taxRate: asDouble(j['tax_rate']),
      date: asDate(j['date']),
      vendor: asString(j['vendor']),
      originalInvoiceNum: asString(j['original_invoice_num']),
      paymentMode: asString(j['payment_mode']),
      bankAccountId: asStringOrNull(j['bank_account_id']),
      bankAccountLabel: bank.isEmpty ? null : BankAccount.fromJson(bank).label,
      notes: asString(j['notes']),
      status: asString(j['status'], 'active'),
      cancelReason: asString(j['cancel_reason']),
      items: asMapList(j['items']).map(ExpenseItem.fromJson).toList(),
    );
  }
}

class ExpenseCategory {
  const ExpenseCategory({required this.id, required this.name, this.description = '', this.isActive = true});
  final String id;
  final String name;
  final String description;
  final bool isActive;

  factory ExpenseCategory.fromJson(JsonMap j) => ExpenseCategory(
        id: asString(j['id']),
        name: asString(j['name']),
        description: asString(j['description']),
        isActive: asBool(j['is_active'], true),
      );
}
