import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import 'api_exception.dart';
import 'json.dart';
import 'paged.dart';

/// Holds the in-memory auth token and lets the session layer react to 401s
/// without a circular provider dependency.
class AuthTokenHolder {
  String? token;
  void Function()? onUnauthorized;
}

final authTokenHolderProvider = Provider<AuthTokenHolder>(
  (_) => AuthTokenHolder(),
);

class ApiClient {
  ApiClient(this._config, this._tokens) {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 45),
        contentType: 'application/json',
        responseType: ResponseType.json,
      ),
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // Read the base URL per request so a server change applies immediately.
          options.baseUrl = _config.serverUrl;
          final token = _tokens.token;
          if (token != null) options.headers['Authorization'] = 'Bearer $token';
          final store = _config.storeId;
          if (store != null) options.headers['X-Store-ID'] = store;
          handler.next(options);
        },
        onError: (e, handler) {
          final path = e.requestOptions.path;
          if (e.response?.statusCode == 401 &&
              !path.startsWith('/auth/login')) {
            _tokens.onUnauthorized?.call();
          }
          handler.next(e);
        },
      ),
    );
  }

  final AppConfig _config;
  final AuthTokenHolder _tokens;
  late final Dio _dio;

  String get baseUrl => _config.serverUrl;

  Future<T> _run<T>(
    Future<Response<dynamic>> Function() call,
    T Function(dynamic) map,
  ) async {
    try {
      final res = await call();
      return map(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _run(() => _dio.get(path, queryParameters: _clean(query)), (d) => d);

  Future<JsonMap> getMap(String path, {Map<String, dynamic>? query}) =>
      _run(() => _dio.get(path, queryParameters: _clean(query)), asMap);

  Future<Paged<T>> getPaged<T>(
    String path,
    T Function(JsonMap) fromJson, {
    String? key,
    int page = 1,
    int perPage = 25,
    Map<String, dynamic>? query,
  }) => _run(
    () => _dio.get(
      path,
      queryParameters: _clean({...?query, 'page': page, 'per_page': perPage}),
    ),
    (d) => Paged.parse(d, fromJson, key: key, page: page, perPage: perPage),
  );

  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) => _run(
    () => _dio.post(
      path,
      data: body,
      queryParameters: _clean(query),
      options: Options(headers: headers),
    ),
    (d) => d,
  );

  Future<dynamic> put(String path, {Object? body}) =>
      _run(() => _dio.put(path, data: body), (d) => d);

  Future<dynamic> patch(String path, {Object? body}) =>
      _run(() => _dio.patch(path, data: body), (d) => d);

  Future<dynamic> delete(String path, {Object? body}) =>
      _run(() => _dio.delete(path, data: body), (d) => d);

  /// Downloads a binary (PDF/Excel) to [savePath] with auth headers applied.
  Future<void> download(
    String path,
    String savePath, {
    Map<String, dynamic>? query,
  }) => _run(
    () => _dio.download(path, savePath, queryParameters: _clean(query)),
    (_) {},
  );

  static Map<String, dynamic>? _clean(Map<String, dynamic>? q) {
    if (q == null) return null;
    final out = <String, dynamic>{};
    q.forEach((k, v) {
      if (v == null) return;
      if (v is String && v.trim().isEmpty) return;
      out[k] = v;
    });
    return out;
  }
}

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(
    ref.watch(appConfigProvider),
    ref.watch(authTokenHolderProvider),
  ),
);
