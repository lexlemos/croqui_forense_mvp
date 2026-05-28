import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:croqui_forense_mvp/core/network/api_client.dart';
import 'package:croqui_forense_mvp/core/security/key_storage_interface.dart';
import 'package:croqui_forense_mvp/core/security/security_helper.dart';
import 'package:croqui_forense_mvp/data/models/usuario_model.dart';
import 'package:croqui_forense_mvp/data/repositories/usuario_repository.dart';
import 'package:croqui_forense_mvp/core/exceptions/auth_exception.dart';

bool _verificarPinEmBackground(Map<String, String> dados) {
  final pin = dados['pin']!;
  final hash = dados['hash']!;
  final salt = dados['salt']!;
  return SecurityHelper.verifyPin(pin, hash, salt);
}

Map<String, String> _gerarCredenciaisEmBackground(String pin) {
  final salt = SecurityHelper.generateSalt();
  final hash = SecurityHelper.hashPin(pin, salt);
  return {'hash': hash, 'salt': salt};
}

class AuthService {
  final UsuarioRepository _usuarioRepository;
  final KeyStorageInterface _keyStorage;
  final ApiClient _apiClient;

  static const String _routeLogin = '/croqui/auth/login';

  Usuario? _usuarioLogado;

  AuthService(this._usuarioRepository, this._keyStorage, this._apiClient);

  Usuario? get usuario => _usuarioLogado;
  bool get isLogged => _usuarioLogado != null;

  Future<void> login(String matricula, String pin) async {
    final usuario = await _usuarioRepository.getUsuarioByMatricula(matricula);

    if (usuario != null) {
      await _loginOffline(usuario, pin);
      return;
    }

    await _loginOnlineFallback(matricula, pin);
  }

  Future<void> _loginOffline(Usuario usuario, String pin) async {
    if (usuario.ativo == false) throw AuthException('Usuário desativado.');

    if (usuario.hashPinOffline == null || usuario.salt == null) {
      throw AuthException('Erro de integridade nas credenciais');
    }

    final bool isPinValido = await compute(_verificarPinEmBackground, {
      'pin': pin,
      'hash': usuario.hashPinOffline!,
      'salt': usuario.salt!,
    });
    if (!isPinValido) throw AuthException('PIN incorreto');

    _usuarioLogado = usuario;

    // Tenta renovar tokens silenciosamente se não houver access_token válido.
    // Falha silenciosa: se offline, o app funciona normalmente — a sync
    // reportará o erro de autenticação quando tentar rodar.
    await _tentarRenovarTokens(usuario.matriculaFuncional, pin);
  }

  Future<void> _tentarRenovarTokens(String matricula, String pin) async {
    final existingToken = await _keyStorage.read(key: 'access_token');
    if (existingToken != null) return;

    try {
      final response = await _apiClient.dio.post(
        _routeLogin,
        data: {'matricula': matricula, 'senha': pin},
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final token = data['token']?.toString();
        final refreshToken = data['refresh_token']?.toString();

        if (token != null) {
          await _keyStorage.save(key: 'access_token', value: token);
        }
        if (refreshToken != null) {
          await _keyStorage.save(key: 'refresh_token', value: refreshToken);
        }
        await _keyStorage.save(
          key: 'user_id',
          value: _usuarioLogado?.id ?? '',
        );
      }
    } catch (_) {
      // Silencia erros de rede — app offline-first continua funcional
    }
  }

  Future<void> _loginOnlineFallback(String matricula, String pin) async {
    late final Response response;

    try {
      response = await _apiClient.dio.post(
        _routeLogin,
        data: {'matricula': matricula, 'senha': pin},
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.unknown) {
        throw AuthException('Dispositivo offline. Conecte-se para o primeiro acesso.');
      }
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        throw AuthException('Credenciais inválidas.');
      }
      throw AuthException('Falha na comunicação com o servidor.');
    }

    if (response.statusCode != 200 || response.data == null) {
      throw AuthException('Resposta inesperada do servidor.');
    }

    try {
      // 1. Parsing Direto (O Dio já devolve um Map)
      final responseData = response.data as Map<String, dynamic>;
      final perfil = responseData['usuario'] as Map<String, dynamic>;
      final token = responseData['token']?.toString();
      final refreshToken = responseData['refresh_token']?.toString();

      if (token == null) throw AuthException('Token ausente na resposta.');

      await _keyStorage.save(key: 'access_token', value: token);
      if (refreshToken != null) {
        await _keyStorage.save(key: 'refresh_token', value: refreshToken);
      }
      await _keyStorage.save(key: 'user_id', value: perfil['id']?.toString() ?? '');

      final credenciais = _gerarCredenciaisEmBackground(pin);

      final novoUsuario = Usuario(
        id: perfil['id']?.toString() ?? '',
        matriculaFuncional: matricula,
        nomeCompleto: perfil['nome_completo']?.toString() ?? '',
        crm: perfil['crm']?.toString() ?? '',
        classe: perfil['classe']?.toString() ?? '',
        papelId: perfil['papel_id']?.toString() ?? 'perito',
        ativo: true,
        hashPinOffline: credenciais['hash']!,
        salt: credenciais['salt']!,
        deveAlterarPin: perfil['deve_alterar_pin'] == true || perfil['deve_alterar_pin'] == 1,
        criadoEm: DateTime.now(),
        deviceId: perfil['device_id']?.toString(),
      );

      await _usuarioRepository.createUsuario(novoUsuario);
      _usuarioLogado = novoUsuario;

    } catch (e) {
      throw AuthException('Erro interno ao processar login: $e');
    }
  }

  Future<void> logout() async {
    _usuarioLogado = null;
    await _keyStorage.delete(key: 'access_token');
    await _keyStorage.delete(key: 'refresh_token');
    await _keyStorage.delete(key: 'user_id');
  }

  /// Chamado pelo interceptor HTTP quando o refresh token falha.
  /// Limpa a sessão em memória para que o AuthProvider reflita o estado.
  void forceExpireSession() {
    _usuarioLogado = null;
  }

  Future<Usuario?> checkSession() async {
    final String? id = await _keyStorage.read(key: 'user_id');

    if (id != null) {
      await _loadUsuario(id);
    }
    return _usuarioLogado;
  }

  Future<void> _loadUsuario(String id) async {
    try {
      final usuario = await _usuarioRepository.getUsuarioById(id);
      if (usuario != null && usuario.ativo) {
        _usuarioLogado = usuario;
      } else {
        await logout();
      }
    } catch (e) {
      await logout();
    }
  }

  Future<void> trocarPinObrigatorio(Usuario usuario, String novoPin) async {
    try {
      await _apiClient.dio.put(
        '/croqui/auth/${usuario.id}/senha',
        data: {'nova_senha': novoPin},
      );
    } on DioException catch (e) {
      throw AuthException(
        'Não foi possível alterar a senha no servidor. '
        'Verifique sua conexão e tente novamente. (${e.type.name})',
      );
    }

    final resultado = await compute(_gerarCredenciaisEmBackground, novoPin);

    await _usuarioRepository.updatePin(
      usuario.id,
      resultado['hash']!,
      resultado['salt']!,
    );

    if (_usuarioLogado != null && _usuarioLogado!.id == usuario.id) {
      _usuarioLogado = _usuarioLogado!.copyWith(deveAlterarPin: false);
    }
  }
}
