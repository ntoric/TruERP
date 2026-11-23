import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Overridden in `main()` once SharedPreferences has loaded.
final sharedPrefsProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError(),
);

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (_) => const FlutterSecureStorage(),
);

/// Persistent, non-secret app settings.
class AppConfig {
  AppConfig(this._prefs);
  final SharedPreferences _prefs;

  static const _kServer = 'server_url';
  static const _kStore = 'active_store_id';
  static const _kTheme = 'theme_mode';

  /// Production TruERP backend.
  static const productionServerUrl = 'https://backend.truerp.co.in/api/v1';

  /// Production unless overridden at build time, e.g. for local development:
  /// `--dart-define=API_URL=http://10.0.2.2:8088/api/v1`.
  static String get defaultServerUrl {
    const fromEnv = String.fromEnvironment('API_URL');
    return fromEnv.isNotEmpty
        ? normalizeServerUrl(fromEnv)
        : productionServerUrl;
  }

  static final _localHost = RegExp(
    r'^(localhost|127\.|10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.)',
  );

  String get serverUrl => _prefs.getString(_kServer) ?? defaultServerUrl;
  Future<void> setServerUrl(String url) =>
      _prefs.setString(_kServer, normalizeServerUrl(url));

  String? get storeId => _prefs.getString(_kStore);
  Future<void> setStoreId(String? id) => id == null || id.isEmpty
      ? _prefs.remove(_kStore)
      : _prefs.setString(_kStore, id);

  ThemeMode get themeMode => ThemeMode.values.firstWhere(
    (m) => m.name == _prefs.getString(_kTheme),
    orElse: () => ThemeMode.system,
  );
  Future<void> setThemeMode(ThemeMode m) => _prefs.setString(_kTheme, m.name);

  /// Accepts `host`, `host:port`, `https://host`, or a full `/api/v1` URL.
  /// Bare hosts get `https://`, except local/LAN addresses which get `http://`.
  static String normalizeServerUrl(String input) {
    var url = input.trim().replaceAll(RegExp(r'/+$'), '');
    if (url.isEmpty) return productionServerUrl;
    if (!url.startsWith(RegExp(r'https?://'))) {
      url = '${_localHost.hasMatch(url) ? 'http' : 'https'}://$url';
    }
    if (!url.endsWith('/api/v1')) url = '$url/api/v1';
    return url;
  }
}

final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig(ref.watch(sharedPrefsProvider)),
);

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.read(appConfigProvider).themeMode;

  void set(ThemeMode mode) {
    state = mode;
    ref.read(appConfigProvider).setThemeMode(mode);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);
