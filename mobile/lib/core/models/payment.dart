import '../api/json.dart';
import 'party.dart';

/// Payment modes, mirroring `frontend/lib/paymentSplits.ts`.
class PaymentMode {
  const PaymentMode(this.value, this.label);
  final String value;
  final String label;

  static const cash = PaymentMode('cash', 'Cash');
  static const upi = PaymentMode('upi', 'UPI');
  static const card = PaymentMode('card', 'Card');
  static const bank = PaymentMode('bank_transfer', 'Bank Transfer');
  static const cheque = PaymentMode('cheque', 'Cheque');

  /// Modes accepted when money is actually received.
  static const receipt = [cash, upi, card, bank, cheque];

  static String labelOf(String? value) {
    final v = (value ?? '').trim().toLowerCase();
    if (v.isEmpty) return '—';
    if (v == 'unpaid') return 'Unpaid';
    if (v == 'initial_investment') return 'Initial Investment';
    for (final m in receipt) {
      if (m.value == v) return m.label;
    }
    return v.replaceAll('_', ' ');
  }
}

class BankAccount {
  const BankAccount({
    required this.id,
    required this.accountName,
    this.bankName = '',
    this.accountNumber = '',
    this.balance = 0,
    this.isPrimary = false,
    this.isActive = true,
  });

  final String id;
  final String accountName;
  final String bankName;
  final String accountNumber;
  final double balance;
  final bool isPrimary;
  final bool isActive;

  String get label {
    final tail = accountNumber.length > 4 ? ' ••${accountNumber.substring(accountNumber.length - 4)}' : '';
    return '${accountName.isNotEmpty ? accountName : bankName}$tail';
  }

  factory BankAccount.fromJson(JsonMap j) => BankAccount(
        id: asString(j['id']),
        accountName: asString(j['account_name']),
        bankName: asString(j['bank_name']),
        accountNumber: asString(j['account_number']),
        balance: asDouble(j['balance']),
        isPrimary: asBool(j['is_primary']),
        isActive: asBool(j['is_active'], true),
      );
}

/// Payment In (receipt from a customer).
class PaymentIn {
  const PaymentIn({
    required this.id,
    required this.number,
    required this.amount,
    required this.mode,
    required this.date,
    required this.party,
    this.discount = 0,
    this.invoiceId,
    this.invoiceNumber,
    this.reference = '',
    this.notes = '',
    this.status = 'active',
    this.cancelReason = '',
    this.bankAccountLabel,
  });

  final String id;
  final String number;
  final double amount;
  final double discount;
  final String mode;
  final DateTime? date;
  final Party? party;
  final String? invoiceId;
  final String? invoiceNumber;
  final String reference;
  final String notes;
  final String status;
  final String cancelReason;
  final String? bankAccountLabel;

  bool get isCancelled => status == 'cancelled';

  factory PaymentIn.fromJson(JsonMap j) {
    final party = asMap(j['party']);
    final bank = asMap(j['bank_account']);
    return PaymentIn(
      id: asString(j['id']),
      number: asString(j['payment_in_number']),
      amount: asDouble(j['amount_received']),
      discount: asDouble(j['payment_in_discount']),
      mode: asString(j['mode']),
      date: asDate(j['date']),
      party: asString(party['id']).isEmpty ? null : Party.fromJson(party),
      invoiceId: asStringOrNull(j['invoice_id']),
      invoiceNumber: asStringOrNull(pick(j, 'invoice.invoice_number')),
      reference: asString(j['reference']),
      notes: asString(j['notes']),
      status: asString(j['status'], 'active'),
      cancelReason: asString(j['cancel_reason']),
      bankAccountLabel: bank.isEmpty ? null : BankAccount.fromJson(bank).label,
    );
  }
}
