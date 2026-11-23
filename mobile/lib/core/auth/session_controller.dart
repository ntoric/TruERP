import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../api/json.dart';
import '../config/app_config.dart';
import 'session.dart';

const _kTokenKey = 'auth_token';

class SessionController extends AsyncNotifier<Session?> {
  ApiClient get _api => ref.read(apiClientProvider);
  AppConfig get _config => ref.read(appConfigProvider);

  @override
  Future<Session?> build() async {
    final holder = ref.read(authTokenHolderProvider);
    holder.onUnauthorized = _handleUnauthorized;
    final token = await ref.read(secureStorageProvider).read(key: _kTokenKey);
    if (token == null || token.isEmpty) return null;
    holder.token = token;
    try {
      return await _loadSession(token);
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        await _clearCredentials();
        return null;
      }
      rethrow;
    }
  }

  Future<Session> _loadSession(String token, {JsonMap? loginStore}) async {
    final profile = await _api.getMap('/auth/profile');
    final user = AppUser.fromJson(profile);
    var stores = asMapList(profile['stores']).map(StoreInfo.fromJson).toList();
    if (stores.isEmpty) {
      try {
        final mine = await _api.getMap('/auth/my-stores');
        stores = asMapList(mine['stores']).map(StoreInfo.fromJson).toList();
      } on ApiException {
        // Older backends don't expose my-stores; a single-store session is fine.
      }
    }
    final active = asMap(profile['active_store']);
    if (active.isNotEmpty && stores.every((s) => s.id != active['id'])) {
      stores = [StoreInfo.fromJson(active), ...stores];
    }
    final assignedId = asStringOrNull(active['id']) ??
        asStringOrNull(loginStore?['id']) ??
        user.storeId ??
        (stores.isEmpty ? null : stores.first.id);
    String? activeId;
    if (user.isSuperAdmin) {
      // Super admins keep their last selection while it still exists.
      activeId = _config.storeId;
      if (activeId == null || stores.isNotEmpty && stores.every((s) => s.id != activeId)) {
        activeId = assignedId;
      }
    } else {
      // Everyone else is pinned to their assigned store; ignore any saved selection.
      activeId = assignedId;
      stores = stores.where((s) => s.id == activeId).toList();
    }
    if (activeId != _config.storeId) await _config.setStoreId(activeId);
    return Session(token: token, user: user, stores: stores, activeStoreId: activeId);
  }

  Future<void> login(String email, String password, {String? totpCode}) async {
    JsonMap data;
    try {
      data = asMap(await _api.post('/auth/login', body: {
        'email': email.trim(),
        'password': password,
        'totp_code': totpCode ?? '',
      }));
    } on ApiException catch (e) {
      if (asBool(e.data?['requires_2fa'])) throw TwoFactorRequired(e.message);
      rethrow;
    }
    if (asBool(data['requires_2fa']) && asStringOrNull(data['token']) == null) {
      throw const TwoFactorRequired('Enter the 6-digit code from your authenticator app.');
    }
    await _acceptToken(data);
  }

  Future<void> register({required String name, required String email, required String password, String? phone}) async {
    final data = asMap(await _api.post('/auth/register', body: {
      'name': name.trim(),
      'email': email.trim(),
      'password': password,
      'phone': phone?.trim() ?? '',
    }));
    await _acceptToken(data);
  }

  Future<void> _acceptToken(JsonMap data) async {
    final token = asStringOrNull(data['token']);
    if (token == null) throw ApiException('Invalid server response.');
    ref.read(authTokenHolderProvider).token = token;
    await ref.read(secureStorageProvider).write(key: _kTokenKey, value: token);
    final loginStore = asMap(data['store']);
    if (loginStore.isNotEmpty) await _config.setStoreId(asString(loginStore['id']));
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _loadSession(token, loginStore: loginStore));
  }

  Future<void> refreshProfile() async {
    final current = state.asData?.value;
    if (current == null) return;
    state = await AsyncValue.guard(() => _loadSession(current.token));
  }

  Future<void> setPassword(String newPassword) async {
    await _api.post('/auth/set-password', body: {'new_password': newPassword});
    await refreshProfile();
  }

  Future<void> switchStore(String storeId) async {
    final current = state.asData?.value;
    if (current == null || current.activeStoreId == storeId || !current.canSwitchStores) return;
    await _config.setStoreId(storeId);
    state = AsyncData(current.copyWith(activeStoreId: storeId));
  }

  Future<void> logout() async {
    await _clearCredentials();
    state = const AsyncData(null);
  }

  Future<void> _clearCredentials() async {
    ref.read(authTokenHolderProvider).token = null;
    await ref.read(secureStorageProvider).delete(key: _kTokenKey);
    await _config.setStoreId(null);
  }

  void _handleUnauthorized() {
    if (state.asData?.value != null) logout();
  }
}

final sessionProvider = AsyncNotifierProvider<SessionController, Session?>(SessionController.new);

/// The active store. Data providers watch this so a store switch refetches
/// every store-scoped screen.
final activeStoreIdProvider = Provider<String?>(
  (ref) => ref.watch(sessionProvider.select((s) => s.asData?.value?.activeStoreId)),
);

final currentUserProvider = Provider<AppUser?>(
  (ref) => ref.watch(sessionProvider.select((s) => s.asData?.value?.user)),
);
