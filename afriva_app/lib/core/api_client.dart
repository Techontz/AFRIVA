import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'config.dart';

/// Error raised for any failed API call, mapped from the SPEC §6 error
/// envelope `{ "message", "code", "errors"? }`.
class ApiException implements Exception {
  ApiException({
    required this.message,
    this.code = 'unknown',
    this.statusCode,
    this.errors = const {},
    this.body = const {},
  });

  final String message;
  final String code;
  final int? statusCode;
  final Map<String, dynamic> errors;
  final Map<String, dynamic> body;

  bool get isNetwork => code == 'network_error' || code == 'timeout';
  bool get isUnauthorized => statusCode == 401;
  bool get isEpisodeLocked => statusCode == 402 || code == 'episode_locked';
  bool get isValidation => statusCode == 422;

  /// First validation error for [field] (Laravel style `errors: {field: [msg]}`).
  String? fieldError(String field) {
    final v = errors[field];
    if (v is List && v.isNotEmpty) return v.first.toString();
    if (v is String) return v;
    return null;
  }

  @override
  String toString() => 'ApiException($statusCode, $code): $message';
}

typedef UnauthorizedCallback = void Function();

/// Thin Dio wrapper: base URL, bearer token interceptor, envelope unwrapping
/// and error mapping.
class ApiClient {
  ApiClient({Dio? dio, String? baseUrl})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl ?? AppConfig.apiUrl,
              connectTimeout: AppConfig.connectTimeout,
              receiveTimeout: AppConfig.receiveTimeout,
              headers: const {
                'Accept': 'application/json',
                'Content-Type': 'application/json',
              },
            )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final t = token;
        if (t != null && t.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $t';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401 && token != null) {
          onUnauthorized?.call();
        }
        handler.next(error);
      },
    ));
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: false,
        responseBody: false,
        logPrint: (o) => debugPrint('[api] $o'),
      ));
    }
  }

  final Dio _dio;
  /// Sanctum bearer token for the current session (null when signed out).
  String? token;
  UnauthorizedCallback? onUnauthorized;

  bool get hasToken => token != null && token!.isNotEmpty;

  /// Returns the full decoded JSON body (envelope included).
  Future<Map<String, dynamic>> getJson(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get(path, queryParameters: _clean(query)));

  Future<Map<String, dynamic>> postJson(String path, {Object? body}) =>
      _send(() => _dio.post(path, data: body ?? const {}));

  Future<Map<String, dynamic>> putJson(String path, {Object? body}) =>
      _send(() => _dio.put(path, data: body ?? const {}));

  Future<Map<String, dynamic>> deleteJson(String path) => _send(() => _dio.delete(path));

  /// Convenience: returns `body["data"]`.
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async =>
      (await getJson(path, query: query))['data'];

  Future<dynamic> post(String path, {Object? body}) async =>
      (await postJson(path, body: body))['data'];

  Map<String, dynamic>? _clean(Map<String, dynamic>? q) {
    if (q == null) return null;
    final out = <String, dynamic>{};
    q.forEach((k, v) {
      if (v == null) return;
      if (v is String && v.isEmpty) return;
      out[k] = v;
    });
    return out;
  }

  Future<Map<String, dynamic>> _send(Future<Response<dynamic>> Function() call) async {
    try {
      final res = await call();
      final data = res.data;
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
      if (data == null || (data is String && data.isEmpty)) return <String, dynamic>{};
      return <String, dynamic>{'data': data};
    } on DioException catch (e) {
      throw mapError(e);
    }
  }

  static ApiException mapError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(
          message: 'Afriva is taking too long to respond. Please try again.',
          code: 'timeout',
        );
      case DioExceptionType.connectionError:
        return ApiException(
          message: "Can't reach Afriva right now. Check your connection and try again.",
          code: 'network_error',
        );
      case DioExceptionType.cancel:
        return ApiException(message: 'Request cancelled', code: 'cancelled');
      default:
        break;
    }

    final res = e.response;
    final status = res?.statusCode;
    Map<String, dynamic> body = const {};
    final raw = res?.data;
    if (raw is Map) body = Map<String, dynamic>.from(raw);

    final code = (body['code'] as String?) ??
        switch (status) {
          401 => 'unauthenticated',
          402 => 'episode_locked',
          403 => 'forbidden',
          404 => 'not_found',
          422 => 'validation_error',
          429 => 'too_many_requests',
          _ => status != null && status >= 500 ? 'server_error' : 'unknown',
        };

    final message = (body['message'] as String?)?.trim().isNotEmpty == true
        ? body['message'] as String
        : switch (status) {
            401 => 'Please log in to continue.',
            402 => 'This episode is locked.',
            403 => "You don't have access to this.",
            404 => "We couldn't find that.",
            422 => 'Please check the highlighted fields.',
            429 => 'Too many attempts. Please wait a moment.',
            _ => 'Something went wrong. Please try again.',
          };

    final errors = body['errors'] is Map
        ? Map<String, dynamic>.from(body['errors'] as Map)
        : const <String, dynamic>{};

    return ApiException(
      message: message,
      code: code,
      statusCode: status,
      errors: errors,
      body: body,
    );
  }
}

/// Human readable message for any error thrown in the app.
String errorMessage(Object error) {
  if (error is ApiException) return error.message;
  return 'Something went wrong. Please try again.';
}
