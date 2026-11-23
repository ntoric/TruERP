import 'package:dio/dio.dart';

import 'json.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.fields = const {}, this.data});

  final String message;
  final int? statusCode;

  /// Field-level validation errors (`{"fields": {"email": "..."}}`).
  final Map<String, String> fields;
  final JsonMap? data;

  bool get isUnauthorized => statusCode == 401;
  bool get isNetwork => statusCode == null;

  factory ApiException.fromDio(DioException e) {
    final res = e.response;
    if (res == null) {
      final msg = switch (e.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.sendTimeout =>
          'The server took too long to respond. Check your connection and try again.',
        DioExceptionType.cancel => 'Request cancelled.',
        _ => 'Unable to reach the server. Check your connection or server address.',
      };
      return ApiException(msg);
    }
    final body = res.data is Map ? asMap(res.data) : <String, dynamic>{};
    final fields = asMap(body['fields']).map((k, v) => MapEntry(k, asString(v)));
    var msg = asStringOrNull(body['error']) ?? asStringOrNull(body['message']);
    msg ??= switch (res.statusCode) {
      401 => 'Your session has expired. Please sign in again.',
      403 => 'You don\'t have permission to do that.',
      404 => 'Not found.',
      _ => 'Something went wrong (${res.statusCode}).',
    };
    return ApiException(msg, statusCode: res.statusCode, fields: fields, data: body);
  }

  @override
  String toString() => message;
}

/// Human-readable message for any error thrown in the app.
String errorMessage(Object error) {
  if (error is ApiException) return error.message;
  if (error is DioException) return ApiException.fromDio(error).message;
  return 'Something went wrong. Please try again.';
}
