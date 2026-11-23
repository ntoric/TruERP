abstract final class Validators {
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _gstin = RegExp(
    r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$',
  );
  static final _phone = RegExp(r'^[+]?[0-9]{10,13}$');

  static String? required(String? v, [String field = 'This field']) =>
      (v ?? '').trim().isEmpty ? '$field is required' : null;

  static String? email(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Email is required';
    return _email.hasMatch(s) ? null : 'Enter a valid email';
  }

  static String? optionalEmail(String? v) =>
      (v ?? '').trim().isEmpty ? null : email(v);

  static String? password(String? v) {
    if ((v ?? '').isEmpty) return 'Password is required';
    return v!.length < 6 ? 'Use at least 6 characters' : null;
  }

  static String? optionalPhone(String? v) {
    final s = (v ?? '').replaceAll(RegExp(r'[\s-]'), '');
    if (s.isEmpty) return null;
    return _phone.hasMatch(s) ? null : 'Enter a valid phone number';
  }

  static String? optionalGstin(String? v) {
    final s = (v ?? '').trim().toUpperCase();
    if (s.isEmpty) return null;
    return _gstin.hasMatch(s) ? null : 'Enter a valid 15-character GSTIN';
  }

  static String? number(
    String? v, {
    bool required = false,
    bool allowZero = true,
    String field = 'Value',
  }) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return required ? '$field is required' : null;
    final n = double.tryParse(s);
    if (n == null) return 'Enter a number';
    if (n < 0) return '$field can\'t be negative';
    if (!allowZero && n == 0) return '$field must be more than 0';
    return null;
  }
}
