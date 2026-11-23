import '../api/json.dart';

/// Customer or vendor. Balance sign follows the backend:
/// positive = they owe us (to collect), negative = we owe them (to pay).
class Party {
  const Party({
    required this.id,
    required this.name,
    this.partyType = 'customer',
    this.phone = '',
    this.email = '',
    this.gstin = '',
    this.pan = '',
    this.tan = '',
    this.address = '',
    this.city = '',
    this.state = '',
    this.stateCode = '',
    this.pincode = '',
    this.category = '',
    this.openingBalance = 0,
    this.balance = 0,
    this.creditLimit = 0,
    this.notes = '',
    this.isActive = true,
    this.loyaltyPoints = 0,
  });

  final String id;
  final String name;
  final String partyType;
  final String phone;
  final String email;
  final String gstin;
  final String pan;

  /// Not edited on mobile, but the backend overwrites it on update, so round-trip it.
  final String tan;
  final String address;
  final String city;
  final String state;
  final String stateCode;
  final String pincode;
  final String category;
  final double openingBalance;
  final double balance;
  final double creditLimit;
  final String notes;
  final bool isActive;
  final int loyaltyPoints;

  bool get isVendor => partyType == 'vendor';
  bool get toCollect => balance > 0.005;
  bool get toPay => balance < -0.005;

  String get fullAddress => [
    address,
    city,
    [state, pincode].where((e) => e.isNotEmpty).join(' '),
  ].where((e) => e.trim().isNotEmpty).join(', ');

  factory Party.fromJson(JsonMap j) => Party(
    id: asString(j['id']),
    name: asString(j['name']),
    partyType: asString(j['party_type'], 'customer'),
    phone: asString(j['phone']),
    email: asString(j['email']),
    gstin: asString(j['gstin']),
    pan: asString(j['pan']),
    tan: asString(j['tan']),
    address: asString(j['address']),
    city: asString(j['city']),
    state: asString(j['state']),
    stateCode: asString(j['state_code']),
    pincode: asString(j['pincode']),
    category: asString(j['category']),
    openingBalance: asDouble(j['opening_balance']),
    balance: asDouble(j['balance']),
    creditLimit: asDouble(j['credit_limit']),
    notes: asString(j['notes']),
    isActive: asBool(j['is_active'], true),
    loyaltyPoints: asInt(j['loyalty_points']),
  );

  JsonMap toJson() => {
    'name': name.trim(),
    'party_type': partyType,
    'phone': phone.trim(),
    'email': email.trim(),
    'gstin': gstin.trim().toUpperCase(),
    'pan': pan.trim().toUpperCase(),
    'tan': tan.trim().toUpperCase(),
    'address': address.trim(),
    'city': city.trim(),
    'state': state.trim(),
    'state_code': stateCode.trim(),
    'pincode': pincode.trim(),
    'category': category.trim(),
    'opening_balance': openingBalance,
    'credit_limit': creditLimit,
    'notes': notes.trim(),
    'is_active': isActive,
  };
}

class PartyStats {
  const PartyStats({this.total = 0, this.toCollect = 0, this.toPay = 0});
  final int total;
  final double toCollect;
  final double toPay;

  factory PartyStats.fromJson(JsonMap j) => PartyStats(
    total: asInt(j['total_parties']),
    toCollect: asDouble(j['to_collect']),
    // The backend sums negative balances; show the magnitude.
    toPay: asDouble(j['to_pay']).abs(),
  );
}

class LedgerEntry {
  const LedgerEntry({
    required this.type,
    required this.voucher,
    required this.refNumber,
    required this.date,
    required this.debit,
    required this.credit,
    required this.balance,
    this.refId,
    this.paymentMode = '',
  });

  final String type;
  final String voucher;
  final String refNumber;
  final String? refId;
  final DateTime? date;
  final double debit;
  final double credit;
  final double balance;
  final String paymentMode;

  factory LedgerEntry.fromJson(JsonMap j) => LedgerEntry(
    type: asString(j['type']),
    voucher: asString(j['voucher']),
    refNumber: asString(j['ref_number']),
    refId: asStringOrNull(j['ref_id']),
    date: asDate(j['date']),
    debit: asDouble(j['debit']),
    credit: asDouble(j['credit']),
    balance: asDouble(j['balance']),
    paymentMode: asString(j['payment_mode']),
  );
}

class PartyLedger {
  const PartyLedger({
    required this.entries,
    this.openingBalance = 0,
    this.closingBalance = 0,
    this.totalDebit = 0,
    this.totalCredit = 0,
  });

  final List<LedgerEntry> entries;
  final double openingBalance;
  final double closingBalance;
  final double totalDebit;
  final double totalCredit;

  factory PartyLedger.fromJson(JsonMap j) => PartyLedger(
    entries: asMapList(j['entries']).map(LedgerEntry.fromJson).toList(),
    openingBalance: asDouble(j['opening_balance']),
    closingBalance: asDouble(j['closing_balance']),
    totalDebit: asDouble(j['total_debit']),
    totalCredit: asDouble(j['total_credit']),
  );
}
