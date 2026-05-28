// lib/core/network/api_client.dart

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:croqui_forense_mvp/core/security/key_storage_interface.dart';

// ===========================================================================
// CONSTANTES DE CONFIGURAÇÃO
// ===========================================================================

const String _kBaseUrl = 'http://192.168.15.88:8000/api/v1';
const Duration _kConnectTimeout = Duration(seconds: 5);
const Duration _kDataTimeout = Duration(seconds: 8);

// ===========================================================================
// EXCEÇÃO DE SESSÃO EXPIRADA
// ===========================================================================

/// Lançada quando o refresh token falha e o usuário deve re-autenticar.
class SessionExpiredException implements Exception {
  @override
  String toString() => 'Sessão expirada. Faça login novamente.';
}

// ===========================================================================
// AUTH INTERCEPTOR COM REFRESH AUTOMÁTICO
// ===========================================================================

class AuthInterceptor extends QueuedInterceptor {
  final KeyStorageInterface _keyStorage;
  final Dio _dio;
  final VoidCallback? _onSessionExpired;

  AuthInterceptor(this._keyStorage, this._dio, {VoidCallback? onSessionExpired})
      : _onSessionExpired = onSessionExpired;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _keyStorage.read(key: 'access_token');
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
    if (err.response?.statusCode != 401) {
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
    if (path.contains('/auth/login') || path.contains('/auth/refresh')) {
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

    // Tenta refresh silencioso
    try {
     final refreshDio = Dio(BaseOptions(baseUrl: err.requestOptions.baseUrl));
     final response = await refreshDio.post(
      '/croqui/auth/refresh',
      data: {'refresh_token': refreshToken},
    );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final newAccessToken = data['token']?.toString();
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

// ===========================================================================
// API CLIENT
// ===========================================================================

/// Cliente HTTP centralizado da aplicação "Croqui Forense".
class ApiClient {
  late final Dio dio;
  final KeyStorageInterface _keyStorage;

  /// Callback invocado quando a sessão expira irrecuperavelmente.
  /// A UI deve observar e redirecionar para o login.
  VoidCallback? onSessionExpired;

  ApiClient(this._keyStorage, {String baseUrl = _kBaseUrl}) {
    final baseOptions = BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: _kConnectTimeout,
      receiveTimeout: _kDataTimeout,
      sendTimeout: _kDataTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );

    dio = Dio(baseOptions);
    _configureInterceptors();
  }

  void _configureInterceptors() {
    dio.interceptors.addAll([
      AuthInterceptor(
        _keyStorage,
        dio,
        onSessionExpired: () => onSessionExpired?.call(),
      ),
      if (const bool.fromEnvironment('dart.vm.product') == false)
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          requestHeader: true,
          responseHeader: false,
          logPrint: (object) => debugPrint('[Dio] $object'),
        ),
    ]);
  }
}
