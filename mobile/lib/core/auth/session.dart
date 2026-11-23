import '../api/json.dart';

class StoreInfo {
  const StoreInfo({
    required this.id,
    required this.name,
    this.code = '',
    this.city = '',
  });
  final String id;
  final String name;
  final String code;
  final String city;

  factory StoreInfo.fromJson(JsonMap j) => StoreInfo(
    id: asString(j['id']),
    name: asString(j['name'], 'Store'),
    code: asString(j['code']),
    city: asString(j['city']),
  );
}

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.phone = '',
    this.role = 'owner',
    this.storeId,
    this.mustChangePassword = false,
    this.twoFactorEnabled = false,
    this.businessName = '',
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String? storeId;
  final bool mustChangePassword;
  final bool twoFactorEnabled;
  final String businessName;

  /// Mirrors `frontend/lib/roles.ts`.
  bool get isSuperAdmin => role == 'super_admin' || role == 'owner';
  bool get canManageUsers => isSuperAdmin || role == 'admin';

  String get roleLabel => switch (role) {
    'owner' || 'super_admin' => 'Super Admin',
    'admin' => 'Admin',
    'staff' => 'Staff',
    'accountant' => 'Accountant',
    'manager' => 'Manager',
    _ => role,
  };

  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  factory AppUser.fromJson(JsonMap j) => AppUser(
    id: asString(j['id']),
    name: asString(j['name']),
    email: asString(j['email']),
    phone: asString(j['phone']),
    role: asString(j['role'], 'owner'),
    storeId:
        asStringOrNull(j['store_id']) ??
        asStringOrNull(pick(j, 'active_store.id')),
    mustChangePassword: asBool(j['must_change_password']),
    twoFactorEnabled: asBool(j['two_factor_enabled']),
    businessName: asString(pick(j, 'business.name')),
  );
}

class Session {
  const Session({
    required this.token,
    required this.user,
    this.stores = const [],
    this.activeStoreId,
  });

  final String token;
  final AppUser user;
  final List<StoreInfo> stores;
  final String? activeStoreId;

  /// Only super admins (owner / super_admin) may switch between stores.
  bool get canSwitchStores => user.isSuperAdmin && stores.length > 1;

  StoreInfo? get activeStore {
    for (final s in stores) {
      if (s.id == activeStoreId) return s;
    }
    return stores.isEmpty ? null : stores.first;
  }

  Session copyWith({
    AppUser? user,
    List<StoreInfo>? stores,
    String? activeStoreId,
  }) => Session(
    token: token,
    user: user ?? this.user,
    stores: stores ?? this.stores,
    activeStoreId: activeStoreId ?? this.activeStoreId,
  );
}

/// Thrown by login when the account has 2FA and no code was supplied.
class TwoFactorRequired implements Exception {
  const TwoFactorRequired(this.message);
  final String message;
}
