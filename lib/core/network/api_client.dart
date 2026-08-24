
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
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          requestHeader: true,
          responseHeader: false,
          logPrint: (object) {
            final logStr = object.toString();

            if (logStr.length > 5000) {
              debugPrint('[Dio] ⚠️ Payload gigante detectado (${logStr.length} chars). Omitido para evitar lag na UI.');
              debugPrint('[Dio] Preview: ${logStr.substring(0, 250)}...');
              return;
            }

            final logStrLower = logStr.toLowerCase();
            if (logStrLower.contains('senha') ||
                logStrLower.contains('password') ||
                logStrLower.contains('authorization') ||
                logStrLower.contains('access_token') ||
                logStrLower.contains('refresh_token') ||
                logStrLower.contains('hash_pin_offline')) {
              debugPrint('[Dio] 🔒 Payload contendo dados sensíveis ocultado.');
            } else {
              debugPrint('[Dio] $logStr');
            }
          },
        ),
    ]);
    dio.addSentry();
  }
}