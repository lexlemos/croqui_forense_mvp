
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:sentry_dio/sentry_dio.dart';
import 'package:flutter/foundation.dart';
import 'package:croqui_forense_mvp/core/security/key_storage_interface.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';


final String _kBaseUrl = dotenv.env['API_BASE_URL'] ?? 'http://192.168.15.88:8000/api/v1/';
const Duration _kConnectTimeout = Duration(seconds: 8);
const Duration _kDataTimeout = Duration(seconds: 8);

class SessionExpiredException implements Exception {
  @override
  String toString() => 'Sessão expirada. Faça login novamente.';
}

class AuthInterceptor extends QueuedInterceptor {
  final KeyStorageInterface _keyStorage;
  final Dio _dio;
  final String? Function() _getTokenMemoria;
  final VoidCallback? _onSessionExpired;

  AuthInterceptor(
    this._keyStorage, 
    this._dio, 
    this._getTokenMemoria, 
    {VoidCallback? onSessionExpired}
  ) : _onSessionExpired = onSessionExpired;

  @override
  Future<void> onRequest( 
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = _getTokenMemoria() ?? await _keyStorage.read(key: 'access_token');
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode != 401 && err.response?.statusCode != 403) {
      return handler.next(err);
    }

    if (err.requestOptions.extra['isRetry'] == true) {
      await _forceLogout();
      return handler.reject(
        DioException(
          requestOptions: err.requestOptions,
          error: SessionExpiredException(),
          type: DioExceptionType.unknown,
        ),
      );
    }

    final path = err.requestOptions.path;
    if (path.contains('/auth/login') || path.contains('/auth/refresh') || path.contains('tipos-achados')) {
      return handler.next(err);
    }

    final refreshToken = await _keyStorage.read(key: 'refresh_token');
    if (refreshToken == null) {
      await _forceLogout();
      return handler.reject(
        DioException(
          requestOptions: err.requestOptions,
          error: SessionExpiredException(),
          type: DioExceptionType.unknown,
        ),
      );
    }

    try {
     final refreshDio = Dio(BaseOptions(baseUrl: err.requestOptions.baseUrl));
     final response = await refreshDio.post(
      'croqui/auth/refresh',
      data: {'refresh_token': refreshToken},
    );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final newAccessToken = data['access_token']?.toString();
        final newRefreshToken = data['refresh_token']?.toString();

        if (newAccessToken == null) {
          await _forceLogout();
          return handler.reject(
            DioException(
              requestOptions: err.requestOptions,
              error: SessionExpiredException(),
              type: DioExceptionType.unknown,
            ),
          );
        }

        await _keyStorage.save(key: 'access_token', value: newAccessToken);
        if (newRefreshToken != null) {
          await _keyStorage.save(key: 'refresh_token', value: newRefreshToken);
        }

        debugPrint('[AuthInterceptor] Token renovado com sucesso.');

        final opts = err.requestOptions;
        opts.headers['Authorization'] = 'Bearer $newAccessToken';
        opts.extra['isRetry'] = true;

        if (opts.data is FormData) {
          opts.data = (opts.data as FormData).clone();
        }

        final retryResponse = await _dio.fetch(opts);
        return handler.resolve(retryResponse);
      }
    } on DioException {
      await _forceLogout();
      return handler.reject(
        DioException(
          requestOptions: err.requestOptions,
          error: SessionExpiredException(),
          type: DioExceptionType.unknown,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('[AuthInterceptor] ❌ Erro inesperado durante o refresh: $e\n$stackTrace');
      await _forceLogout();
      return handler.reject(
        DioException(
          requestOptions: err.requestOptions,
          error: SessionExpiredException(),
          type: DioExceptionType.unknown,
        ),
      );
    }

    await _forceLogout();
    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        error: SessionExpiredException(),
        type: DioExceptionType.unknown,
      ),
    );
  }

  Future<void> _forceLogout() async {
    await _keyStorage.delete(key: 'access_token');
    await _keyStorage.delete(key: 'refresh_token');
    await _keyStorage.delete(key: 'user_id');
    _onSessionExpired?.call();
    debugPrint('[AuthInterceptor] Sessão expirada — storage limpo.');
  }
}

class _ForensicSafeLogInterceptor extends Interceptor {
  static const _sensitiveRouteSegments = <String>[
    '/casos',
    '/evidencias',
    '/achados',
  ];

  bool _isSensitiveRoute(String path) =>
      _sensitiveRouteSegments.any(path.contains);

  int _payloadSizeInBytes(Object? payload) {
    if (payload == null) return 0;
    if (payload is List<int>) return payload.length;
    if (payload is FormData) {
      final fieldsSize = payload.fields.fold<int>(
        0,
        (total, field) => total + utf8.encode('${field.key}=${field.value}').length,
      );
      final filesSize = payload.files.fold<int>(
        0,
        (total, file) => total + utf8.encode(file.key).length + file.value.length,
      );
      return fieldsSize + filesSize;
    }

    try {
      return utf8.encode(jsonEncode(payload)).length;
    } catch (_) {
      return utf8.encode(payload.toString()).length;
    }
  }

  String _loggedPayload(String path, Object? payload) {
    final size = _payloadSizeInBytes(payload);
    if (_isSensitiveRoute(path)) {
      return '[PAYLOAD FORENSE OMITIDO - TAMANHO: $size bytes]';
    }

    final payloadText = payload?.toString() ?? 'null';
    final payloadTextLower = payloadText.toLowerCase();
    if (payloadTextLower.contains('senha') ||
        payloadTextLower.contains('password') ||
        payloadTextLower.contains('access_token') ||
        payloadTextLower.contains('refresh_token') ||
        payloadTextLower.contains('hash_pin_offline')) {
      return '[PAYLOAD SENSÍVEL OMITIDO]';
    }

    if (size > 5000) {
      return '[PAYLOAD OMITIDO - TAMANHO: $size bytes]';
    }

    return payloadText;
  }

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    final path = options.uri.path;
    debugPrint('[Dio] --> ${options.method} ${options.uri}');
    debugPrint('[Dio] Request headers: ${options.headers}');
    debugPrint('[Dio] Request body: ${_loggedPayload(path, options.data)}');
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final path = response.requestOptions.uri.path;
    debugPrint('[Dio] <-- ${response.statusCode} ${response.requestOptions.uri}');
    debugPrint('[Dio] Response headers: ${response.headers}');
    debugPrint('[Dio] Response body: ${_loggedPayload(path, response.data)}');
    handler.next(response);
  }

  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) {
    final path = err.requestOptions.uri.path;
    debugPrint(
      '[Dio] xxx ${err.response?.statusCode ?? 'NETWORK'} ${err.requestOptions.uri}',
    );
    debugPrint('[Dio] Error request headers: ${err.requestOptions.headers}');
    if (err.response != null) {
      debugPrint('[Dio] Error response headers: ${err.response!.headers}');
      debugPrint(
        '[Dio] Error response body: ${_loggedPayload(path, err.response!.data)}',
      );
    }
    handler.next(err);
  }
}

class ApiClient {
  late final Dio dio;
  final KeyStorageInterface _keyStorage;
  String? _bearerTokenMemoria;

  VoidCallback? onSessionExpired;

  ApiClient(this._keyStorage, {String? baseUrl}) {
    final baseOptions = BaseOptions(
      baseUrl: baseUrl ?? _kBaseUrl,
      connectTimeout: _kConnectTimeout,
      receiveTimeout: _kDataTimeout,
      sendTimeout: _kDataTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );

    dio = Dio(baseOptions);
    dio.transformer = BackgroundTransformer();
    _configureInterceptors();
  }

  void setBearerToken(String token) {
    _bearerTokenMemoria = token;
    dio.options.headers['Authorization'] = 'Bearer $token';
  }

  void _configureInterceptors() {
    dio.interceptors.addAll([
      AuthInterceptor(
        _keyStorage,
        dio,
        () => _bearerTokenMemoria,
        onSessionExpired: () => onSessionExpired?.call(),
      ),
      if (kDebugMode)
        _ForensicSafeLogInterceptor(),
    ]);
    dio.addSentry();
  }
}
