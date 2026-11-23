import 'package:intl/intl.dart';

final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
final _inr0 = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
final _num = NumberFormat.decimalPattern('en_IN');
final _dMy = DateFormat('dd MMM yyyy');
final _dM = DateFormat('dd MMM');
final _dMyHm = DateFormat('dd MMM yyyy, hh:mm a');

/// ₹1,23,456.00
String money(num? v) => _inr.format(v ?? 0);

/// ₹1,23,456 — for tiles where paise add noise.
String moneyShort(num? v) => _inr0.format(v ?? 0);

/// ₹1.2L / ₹3.4Cr / ₹12.5K for compact chart labels.
String moneyCompact(num? v) {
  final n = (v ?? 0).toDouble();
  final a = n.abs();
  String s;
  if (a >= 1e7) {
    s = '${(a / 1e7).toStringAsFixed(a >= 1e8 ? 0 : 1)}Cr';
  } else if (a >= 1e5) {
    s = '${(a / 1e5).toStringAsFixed(a >= 1e6 ? 0 : 1)}L';
  } else if (a >= 1e3) {
    s = '${(a / 1e3).toStringAsFixed(a >= 1e4 ? 0 : 1)}K';
  } else {
    s = a.toStringAsFixed(0);
  }
  return '${n < 0 ? '-' : ''}₹$s';
}

/// Quantity without trailing zeros: 2, 2.5, 0.125.
String qty(num? v) {
  final n = (v ?? 0).toDouble();
  if (n == n.roundToDouble()) return _num.format(n.round());
  return n.toStringAsFixed(3).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
}

String number(num? v) => _num.format(v ?? 0);

String dateText(DateTime? d) => d == null ? '—' : _dMy.format(d);
String dateShort(DateTime? d) => d == null ? '—' : _dM.format(d);
String dateTimeText(DateTime? d) => d == null ? '—' : _dMyHm.format(d);

/// "Today", "Yesterday", or a date — for list grouping and subtitles.
String relativeDay(DateTime? d) {
  if (d == null) return '—';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return _dMy.format(d);
}

/// snake_case / lower → Title Case ("bank_transfer" → "Bank Transfer").
String titleCase(String s) => s
    .replaceAll('_', ' ')
    .split(' ')
    .where((w) => w.isNotEmpty)
    .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
    .join(' ');
