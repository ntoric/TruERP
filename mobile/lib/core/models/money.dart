import '../api/json.dart';
import 'payment.dart';

// ── Cash & Bank ─────────────────────────────────────────────────────────

class CashTransaction {
  const CashTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    this.accountId,
    this.accountLabel,
    this.description = '',
    this.reference = '',
    this.isLinked = false,
  });

  final String id;
  final String type;
  final double amount;
  final DateTime? date;

  /// Null means cash in hand.
  final String? accountId;
  final String? accountLabel;
  final String description;
  final String reference;

  /// Created by an invoice, payment, expense… rather than entered by hand.
  final bool isLinked;

  /// Same rule as the backend's totals: only add / transfer_in are inflows.
  bool get isInflow => type == 'add' || type == 'transfer_in';
  String get where => accountLabel ?? 'Cash in hand';

  static const typeLabels = {
    'add': 'Money added',
    'reduce': 'Money reduced',
    'transfer_in': 'Transfer in',
    'transfer_out': 'Transfer out',
    'expense': 'Expense',
    'payroll': 'Payroll',
    'profit_distribution': 'Profit distribution',
    'invoice': 'Invoice',
    'payment': 'Payment',
    'credit_note': 'Credit note',
  };

  String get typeLabel => typeLabels[type] ?? type.replaceAll('_', ' ');

  factory CashTransaction.fromJson(JsonMap j) {
    final acc = asMap(j['account']);
    return CashTransaction(
      id: asString(j['id']),
      type: asString(j['transaction_type']),
      amount: asDouble(j['amount']),
      date: asDate(j['date']),
      accountId: asStringOrNull(j['account_id']),
      accountLabel: acc.isEmpty ? null : BankAccount.fromJson(acc).label,
      description: asString(j['description']),
      reference: asString(j['reference']),
      isLinked: asBool(j['is_linked']),
    );
  }
}

class CashBankSummary {
  const CashBankSummary({
    this.totalBalance = 0,
    this.cashInHand = 0,
    this.initialInvestment = 0,
    this.accounts = const [],
    this.unlinkedCount = 0,
    this.unlinkedAmount = 0,
  });

  final double totalBalance;
  final double cashInHand;
  final double initialInvestment;
  final List<BankAccount> accounts;
  final int unlinkedCount;
  final double unlinkedAmount;

  double get bankTotal => accounts.where((a) => a.isActive).fold(0, (s, a) => s + a.balance);

  factory CashBankSummary.fromJson(JsonMap j) => CashBankSummary(
        totalBalance: asDouble(j['total_balance']),
        cashInHand: asDouble(j['cash_in_hand']),
        initialInvestment: asDouble(j['initial_investment']),
        accounts: asMapList(j['bank_accounts']).map(BankAccount.fromJson).toList(),
        unlinkedCount: asInt(j['unlinked_count']),
        unlinkedAmount: asDouble(j['unlinked_amount']),
      );
}

/// Where money received by one payment mode is deposited.
class PaymentRouting {
  const PaymentRouting({required this.method, required this.label, this.bankAccountId});
  final String method;
  final String label;

  /// Null = cash in hand (or owner's equity for initial_investment).
  final String? bankAccountId;

  bool get isOwnerEquity => method == 'initial_investment';

  factory PaymentRouting.fromJson(JsonMap j) => PaymentRouting(
        method: asString(j['payment_method']),
        label: asString(j['label'], asString(j['payment_method'])),
        bankAccountId: asStringOrNull(j['bank_account_id']),
      );
}

// ── Profit distribution ─────────────────────────────────────────────────

class Partner {
  const Partner({
    required this.id,
    required this.name,
    this.phone = '',
    this.email = '',
    this.address = '',
    this.pan = '',
    this.notes = '',
    this.isActive = true,
  });

  final String id;
  final String name;
  final String phone;
  final String email;
  final String address;
  final String pan;
  final String notes;
  final bool isActive;

  factory Partner.fromJson(JsonMap j) => Partner(
        id: asString(j['id']),
        name: asString(j['name']),
        phone: asString(j['phone']),
        email: asString(j['email']),
        address: asString(j['address']),
        pan: asString(j['pan']),
        notes: asString(j['notes']),
        isActive: asBool(j['is_active'], true),
      );

  JsonMap toJson() => {
        'name': name.trim(),
        'phone': phone.trim(),
        'email': email.trim(),
        'address': address.trim(),
        'pan': pan.trim().toUpperCase(),
        'notes': notes.trim(),
        'is_active': isActive,
      };
}

class ProfitDistribution {
  const ProfitDistribution({
    required this.id,
    required this.number,
    required this.amount,
    required this.date,
    this.partner,
    this.accountLabel,
    this.description = '',
    this.reference = '',
    this.notes = '',
  });

  final String id;
  final String number;
  final double amount;
  final DateTime? date;
  final Partner? partner;

  /// Null = paid from cash in hand.
  final String? accountLabel;
  final String description;
  final String reference;
  final String notes;

  factory ProfitDistribution.fromJson(JsonMap j) {
    final p = asMap(j['partner']);
    final acc = asMap(j['account']);
    return ProfitDistribution(
      id: asString(j['id']),
      number: asString(j['distribution_number']),
      amount: asDouble(j['amount']),
      date: asDate(j['date']),
      partner: asString(p['id']).isEmpty ? null : Partner.fromJson(p),
      accountLabel: acc.isEmpty ? null : BankAccount.fromJson(acc).label,
      description: asString(j['description']),
      reference: asString(j['reference']),
      notes: asString(j['notes']),
    );
  }
}

// ── Accounting (read-only) ──────────────────────────────────────────────

class LedgerAccount {
  const LedgerAccount({
    required this.id,
    required this.code,
    required this.name,
    required this.type,
    this.subType = '',
    this.balance = 0,
    this.isDefault = false,
    this.isActive = true,
  });

  final String id;
  final String code;
  final String name;

  /// asset | liability | equity | income | expense
  final String type;
  final String subType;
  final double balance;
  final bool isDefault;
  final bool isActive;

  factory LedgerAccount.fromJson(JsonMap j) => LedgerAccount(
        id: asString(j['id'] ?? j['account_id']),
        code: asString(j['code'] ?? j['account_code']),
        name: asString(j['name'] ?? j['account_name']),
        type: asString(j['account_type']),
        subType: asString(j['sub_type']),
        balance: asDouble(j['balance']),
        isDefault: asBool(j['is_default']),
        isActive: asBool(j['is_active'], true),
      );

  static const typeOrder = ['asset', 'liability', 'equity', 'income', 'expense'];
  static const typeLabels = {
    'asset': 'Assets',
    'liability': 'Liabilities',
    'equity': 'Equity',
    'income': 'Income',
    'expense': 'Expenses',
  };
}

class JournalLine {
  const JournalLine({required this.accountName, required this.debit, required this.credit, this.description = ''});
  final String accountName;
  final double debit;
  final double credit;
  final String description;

  factory JournalLine.fromJson(JsonMap j) {
    final acc = asMap(j['account']);
    final code = asString(acc['code']);
    return JournalLine(
      accountName: [if (code.isNotEmpty) code, asString(acc['name'], 'Account')].join(' · '),
      debit: asDouble(j['debit']),
      credit: asDouble(j['credit']),
      description: asString(j['description']),
    );
  }
}

class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.number,
    required this.date,
    required this.description,
    required this.totalDebit,
    required this.totalCredit,
    required this.status,
    this.lines = const [],
  });

  final String id;
  final String number;
  final DateTime? date;
  final String description;
  final double totalDebit;
  final double totalCredit;
  final String status;
  final List<JournalLine> lines;

  factory JournalEntry.fromJson(JsonMap j) => JournalEntry(
        id: asString(j['id']),
        number: asString(j['entry_number']),
        date: asDate(j['entry_date']),
        description: asString(j['description']),
        totalDebit: asDouble(j['total_debit']),
        totalCredit: asDouble(j['total_credit']),
        status: asString(j['status'], 'draft'),
        lines: asMapList(j['lines']).map(JournalLine.fromJson).toList(),
      );
}

/// One row of a trial balance, P&L or balance sheet.
class ReportRow {
  const ReportRow({required this.accountId, required this.code, required this.name, this.debit = 0, this.credit = 0, this.amount = 0});
  final String accountId;
  final String code;
  final String name;
  final double debit;
  final double credit;
  final double amount;

  factory ReportRow.fromJson(JsonMap j) => ReportRow(
        accountId: asString(j['account_id']),
        code: asString(j['account_code']),
        name: asString(j['account_name']),
        debit: asDouble(j['debit']),
        credit: asDouble(j['credit']),
        amount: asDouble(j['amount']),
      );
}

class TrialBalance {
  const TrialBalance({required this.rows, required this.totalDebit, required this.totalCredit, required this.isBalanced});
  final List<ReportRow> rows;
  final double totalDebit;
  final double totalCredit;
  final bool isBalanced;

  factory TrialBalance.fromJson(JsonMap j) => TrialBalance(
        rows: asMapList(j['items']).map(ReportRow.fromJson).toList(),
        totalDebit: asDouble(j['total_debit']),
        totalCredit: asDouble(j['total_credit']),
        isBalanced: asBool(j['is_balanced'], (asDouble(j['total_debit']) - asDouble(j['total_credit'])).abs() < 0.01),
      );
}

class ProfitLossStatement {
  const ProfitLossStatement({required this.income, required this.expenses, required this.totalIncome, required this.totalExpense, required this.netProfit});
  final List<ReportRow> income;
  final List<ReportRow> expenses;
  final double totalIncome;
  final double totalExpense;
  final double netProfit;

  factory ProfitLossStatement.fromJson(JsonMap j) => ProfitLossStatement(
        income: asMapList(j['income']).map(ReportRow.fromJson).toList(),
        expenses: asMapList(j['expenses']).map(ReportRow.fromJson).toList(),
        totalIncome: asDouble(j['total_income']),
        totalExpense: asDouble(j['total_expense']),
        netProfit: asDouble(j['net_profit']),
      );
}

class BalanceSheet {
  const BalanceSheet({
    required this.assets,
    required this.liabilities,
    required this.equity,
    required this.totalAssets,
    required this.totalLiabilities,
    required this.totalEquity,
    required this.isBalanced,
  });

  final List<ReportRow> assets;
  final List<ReportRow> liabilities;
  final List<ReportRow> equity;
  final double totalAssets;
  final double totalLiabilities;
  final double totalEquity;
  final bool isBalanced;

  factory BalanceSheet.fromJson(JsonMap j) => BalanceSheet(
        assets: asMapList(j['assets']).map(ReportRow.fromJson).toList(),
        liabilities: asMapList(j['liabilities']).map(ReportRow.fromJson).toList(),
        equity: asMapList(j['equity']).map(ReportRow.fromJson).toList(),
        totalAssets: asDouble(j['total_assets']),
        totalLiabilities: asDouble(j['total_liabilities']),
        totalEquity: asDouble(j['total_equity']),
        isBalanced: asBool(j['is_balanced']),
      );
}

class LedgerLine {
  const LedgerLine({
    required this.date,
    required this.type,
    required this.reference,
    required this.description,
    required this.debit,
    required this.credit,
    required this.balance,
  });

  final DateTime? date;
  final String type;
  final String reference;
  final String description;
  final double debit;
  final double credit;
  final double balance;

  factory LedgerLine.fromJson(JsonMap j) => LedgerLine(
        date: asDate(j['transaction_date']),
        type: asString(j['transaction_type']),
        reference: asString(j['reference_number']),
        description: asString(j['description']),
        debit: asDouble(j['debit']),
        credit: asDouble(j['credit']),
        balance: asDouble(j['balance']),
      );
}

class GeneralLedger {
  const GeneralLedger({required this.account, required this.lines, required this.opening, required this.closing});
  final LedgerAccount account;
  final List<LedgerLine> lines;
  final double opening;
  final double closing;

  factory GeneralLedger.fromJson(JsonMap j) => GeneralLedger(
        account: LedgerAccount.fromJson(asMap(j['account'])),
        lines: asMapList(j['entries']).map(LedgerLine.fromJson).toList(),
        opening: asDouble(j['opening_balance']),
        closing: asDouble(j['closing_balance']),
      );
}

class AccountingStats {
  const AccountingStats({
    this.assets = 0,
    this.liabilities = 0,
    this.equity = 0,
    this.income = 0,
    this.expense = 0,
    this.netProfit = 0,
  });

  final double assets;
  final double liabilities;
  final double equity;
  final double income;
  final double expense;
  final double netProfit;

  factory AccountingStats.fromJson(JsonMap j) => AccountingStats(
        assets: asDouble(j['total_assets']),
        liabilities: asDouble(j['total_liabilities']),
        equity: asDouble(j['total_equity']),
        income: asDouble(j['total_income']),
        expense: asDouble(j['total_expense']),
        netProfit: asDouble(j['net_profit']),
      );
}
