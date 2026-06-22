import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../session/session_manager.dart';
import 'api_exception.dart';

/// A successful, unwrapped API response.
///
/// The backend wraps every payload as `{ success, message, data, meta? }`.
/// [ApiResponse] exposes the inner `data` plus optional pagination `meta`.
class ApiResponse<T> {
  final T data;
  final String message;
  final Map<String, dynamic>? meta;

  const ApiResponse({required this.data, this.message = '', this.meta});
}

/// Single Dio instance for the whole app, with:
///  - automatic `Authorization: Bearer` injection,
///  - transparent 401 → refresh → retry (serialized across concurrent calls),
///  - response-envelope unwrapping,
///  - normalized [ApiException] errors.
class ApiClient {
  ApiClient._() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        contentType: 'application/json',
        // We treat non-2xx as errors and map them ourselves.
        validateStatus: (s) => s != null && s >= 200 && s < 300,
      ),
    );

    // Bare Dio used only for the refresh call, so it never re-enters the
    // auth interceptor (which would cause infinite recursion).
    _refreshDio = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        contentType: 'application/json',
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _session.accessToken;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: _onError,
      ),
    );

    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(requestBody: true, responseBody: false, request: false),
      );
    }
  }

  static final ApiClient instance = ApiClient._();

  late final Dio _dio;
  late final Dio _refreshDio;
  final SessionManager _session = SessionManager.instance;

  /// Serializes concurrent refreshes: the first 401 starts the refresh, the
  /// rest await the same future.
  Completer<bool>? _refreshLock;

  // ---- Public verbs --------------------------------------------------

  Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    return _wrap<T>(() => _dio.get(path, queryParameters: query));
  }

  Future<ApiResponse<T>> post<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) async {
    return _wrap<T>(() => _dio.post(path, data: body, queryParameters: query));
  }

  Future<ApiResponse<T>> patch<T>(String path, {Object? body}) async {
    return _wrap<T>(() => _dio.patch(path, data: body));
  }

  Future<ApiResponse<T>> put<T>(String path, {Object? body}) async {
    return _wrap<T>(() => _dio.put(path, data: body));
  }

  Future<ApiResponse<T>> delete<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) async {
    return _wrap<T>(() => _dio.delete(path, data: body, queryParameters: query));
  }

  // ---- Internals -----------------------------------------------------

  Future<ApiResponse<T>> _wrap<T>(Future<Response> Function() call) async {
    try {
      final res = await call();
      return _unwrap<T>(res.data);
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  ApiResponse<T> _unwrap<T>(dynamic body) {
    if (body is Map<String, dynamic>) {
      final data = body.containsKey('data') ? body['data'] : body;
      return ApiResponse<T>(
        data: data as T,
        message: (body['message'] ?? '') as String,
        meta: body['meta'] is Map<String, dynamic>
            ? body['meta'] as Map<String, dynamic>
            : null,
      );
    }
    // Non-enveloped (rare) — pass through as-is.
    return ApiResponse<T>(data: body as T);
  }

  Future<void> _onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final status = err.response?.statusCode;
    final path = err.requestOptions.path;
    final isAuthRoute =
        path.contains('/auth/refresh') || path.contains('/auth/otp') || path.contains('/auth/staff/login');

    // Only attempt refresh for a genuine 401 on a non-auth route when we hold
    // a refresh token and haven't already retried this request.
    final alreadyRetried = err.requestOptions.extra['__retried'] == true;
    if (status == 401 &&
        !isAuthRoute &&
        !alreadyRetried &&
        _session.refreshToken != null) {
      final refreshed = await _ensureRefreshed();
      if (refreshed) {
        try {
          final opts = err.requestOptions;
          opts.extra['__retried'] = true;
          opts.headers['Authorization'] = 'Bearer ${_session.accessToken}';
          final retried = await _dio.fetch(opts);
          return handler.resolve(retried);
        } on DioException catch (e) {
          return handler.next(e);
        }
      } else {
        // Refresh failed — session is dead.
        await _session.clear();
      }
    }
    handler.next(err);
  }

  /// Runs (or joins) a single refresh attempt. Returns whether we now hold a
  /// valid access token.
  Future<bool> _ensureRefreshed() async {
    if (_refreshLock != null) return _refreshLock!.future;
    final lock = Completer<bool>();
    _refreshLock = lock;
    try {
      final res = await _refreshDio.post(
        '/auth/refresh',
        data: {'refreshToken': _session.refreshToken},
      );
      final body = res.data as Map<String, dynamic>;
      final data = (body['data'] ?? body) as Map<String, dynamic>;
      await _session.saveTokens(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
      );
      lock.complete(true);
    } catch (_) {
      lock.complete(false);
    } finally {
      _refreshLock = null;
    }
    return lock.future;
  }

  ApiException _toApiException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException(
          'The connection timed out. Please try again.',
          isNetwork: true,
        );
      case DioExceptionType.connectionError:
        return const ApiException(
          'No internet connection. Check your network and retry.',
          isNetwork: true,
        );
      default:
        break;
    }

    final status = e.response?.statusCode;
    final data = e.response?.data;
    String message = 'Something went wrong. Please try again.';
    List<String> details = const [];

    if (data is Map<String, dynamic>) {
      final m = data['message'];
      if (m is String && m.isNotEmpty) {
        message = m;
      } else if (m is List) {
        details = m.map((e) => e.toString()).toList();
        if (details.isNotEmpty) message = details.first;
      }
    }

    if (status == 401) message = 'Your session has expired. Please log in again.';
    return ApiException(message, statusCode: status, details: details);
  }
}
