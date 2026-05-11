// lib/core/network/api_client.dart

import 'package:dio/dio.dart';

// ===========================================================================
// CONSTANTES DE CONFIGURAÇÃO
// ===========================================================================

/// URL base provisória apontando para o localhost do emulador Android.
///
/// O emulador Android mapeia `10.0.2.2` para o `localhost` da máquina host.
/// Substitua pelo endereço real do servidor antes de qualquer deploy.
const String _kBaseUrl = 'http://192.168.15.88:8000/api/v1';

/// Timeout para estabelecer conexão TCP com o servidor.
/// Valor agressivo para falhar rápido quando o backend está indisponível.
const Duration _kConnectTimeout = Duration(seconds: 5);

/// Timeout para envio e recebimento de dados em requisições padrão.
/// O SyncService pode sobrescrever via Options para uploads pesados.
const Duration _kDataTimeout = Duration(seconds: 8);

// ===========================================================================
// MOCK AUTH INTERCEPTOR
// ===========================================================================

/// Interceptor de autenticação temporário para a fase de desenvolvimento.
///
/// Injeta um JWT estático em todos os requests enquanto a camada de
/// autenticação real não está implementada. **Não deve ir para produção.**
///
/// ### Roadmap de evolução obrigatório:
/// 1. Transformar em interceptor assíncrono lendo o token do `flutter_secure_storage`.
/// 2. Implementar lógica de refresh de token no [onError] (status 401).
class MockAuthInterceptor extends Interceptor {
  // =========================================================================
  // TODO: [AUTH REAL] ⚠️  ATENÇÃO — SUBSTITUIR ANTES DO DEPLOY EM PRODUÇÃO ⚠️
  // =========================================================================
  //
  // Este interceptor DEVE ser refatorado para:
  //
  // 1. LEITURA ASSÍNCRONA DO TOKEN:
  //    Tornar o método `onRequest` assíncrono e ler o `access_token` real
  //    a partir do `flutter_secure_storage`:
  //
  //    ```dart
  //    @override
  //    Future<void> onRequest(
  //      RequestOptions options,
  //      RequestInterceptorHandler handler,
  //    ) async {
  //      final storage = FlutterSecureStorage();
  //      final token = await storage.read(key: 'access_token');
  //      if (token != null) {
  //        options.headers['Authorization'] = 'Bearer $token';
  //      }
  //      handler.next(options);
  //    }
  //    ```
  //
  // 2. TRATAMENTO DO ERRO 401 (Refresh Token):
  //    Implementar o método `onError` para interceptar respostas HTTP 401
  //    (Unauthorized) e acionar o fluxo de refresh token:
  //
  //    ```dart
  //    @override
  //    Future<void> onError(
  //      DioException err,
  //      ErrorInterceptorHandler handler,
  //    ) async {
  //      if (err.response?.statusCode == 401) {
  //        // 1. Ler o refresh_token do flutter_secure_storage.
  //        // 2. Chamar o endpoint /auth/refresh.
  //        // 3. Persistir o novo access_token no secure storage.
  //        // 4. Re-tentar a requisição original com o novo token.
  //        // 5. Se o refresh falhar, deslogar o usuário (navegação para Login).
  //      }
  //      handler.next(err);
  //    }
  //    ```
  //
  // Referências:
  //   - flutter_secure_storage: https://pub.dev/packages/flutter_secure_storage
  //   - Dio Interceptors: https://pub.dev/packages/dio#interceptors
  // =========================================================================

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Injeta o token de autenticação mock em todos os requests de saída.
    options.headers['Authorization'] = 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJlZWMzMWNhNC01NjYwLTRlZTktOWY3YS04N2E4OWE2N2NiMTciLCJyb2xlcyI6W10sImV4cCI6MTc3NzEzNjcyOCwiaWF0IjoxNzc3MTMzMTI4LCJhdWQiOiJhcHBfY29yZSJ9.NBa1HWkIoYub1MwucJPynULBtPcjRR3EVpA5JL7c_a0';

    // Passa a requisição adiante na cadeia de interceptors.
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // Sem tratamento especial de resposta nesta fase. Passa adiante.
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Sem tratamento de erro nesta fase. Passa adiante.
    // TODO: [AUTH REAL] Interceptar 401 aqui para o fluxo de refresh token.
    handler.next(err);
  }
}

// ===========================================================================
// API CLIENT
// ===========================================================================

/// Cliente HTTP centralizado da aplicação "Croqui Forense".
///
/// Encapsula a instância do [Dio] com configurações otimizadas para o
/// cenário forense de campo: uploads de arquivos pesados em redes instáveis.
///
/// ### Uso
/// ```dart
/// // Instância com URL padrão (emulador Android):
/// final client = ApiClient();
///
/// // Instância com URL customizada (ex: ambiente de staging):
/// final client = ApiClient(baseUrl: 'https://api.staging.croquiforense.gov.br/api/v1');
///
/// // Acessando o Dio para fazer requisições:
/// final response = await client.dio.get('/evidencias');
/// ```
class ApiClient {
  /// A instância configurada do [Dio], pronta para uso nos repositórios.
  late final Dio dio;

  /// Cria e configura uma instância do [ApiClient].
  ///
  /// - [baseUrl]: URL base da API. Padrão aponta para o localhost do
  ///   emulador Android (`http://10.0.2.2:8000/api/v1`).
  ApiClient({String baseUrl = _kBaseUrl}) {
    final baseOptions = BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: _kConnectTimeout,
      receiveTimeout: _kDataTimeout,
      sendTimeout: _kDataTimeout,

      // Cabeçalhos padrão para todas as requisições.
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );

    dio = Dio(baseOptions);

    _configureInterceptors();
  }

  /// Registra os interceptors na instância do [Dio] na ordem correta.
  ///
  /// A ordem dos interceptors importa: o [MockAuthInterceptor] deve ser
  /// adicionado antes de qualquer interceptor de log para que o token
  /// apareça nos registros de debug.
  void _configureInterceptors() {
    dio.interceptors.addAll([
      // 1. Auth: injeta o token em todos os requests de saída.
      MockAuthInterceptor(),

      // 2. Log: exibe detalhes de request/response no console de debug.
      //    Ativado apenas em modo debug para não vazar dados em produção.
      if (const bool.fromEnvironment('dart.vm.product') == false)
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          requestHeader: true,
          responseHeader: false,
          // Usa o print padrão do Dart para compatibilidade máxima.
          logPrint: (object) => print('[ApiClient] $object'), // ignore: avoid_print
        ),
    ]);
  }
}
