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
  }

  Future<void> _loginOnlineFallback(String matricula, String pin) async {
    late final Response response;

    try {
      response = await _apiClient.dio.post(
        _routeLogin,
        data: {
          'matricula': matricula,
          'senha': pin,
        },
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.unknown) {
        throw AuthException(
          'Dispositivo offline e usuário não cadastrado localmente. '
          'Conecte-se para o primeiro acesso.',
        );
      }
      final statusCode = e.response?.statusCode;
      if (statusCode == 401 || statusCode == 403) {
        throw AuthException('Credenciais inválidas.');
      }
      throw AuthException('Falha na comunicação com o servidor.');
    }

    if (response.statusCode != 200 || response.data == null) {
      throw AuthException('Resposta inesperada do servidor.');
    }

    final Map<String, dynamic> perfil = response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : throw AuthException('Formato de resposta inválido.');

    final credenciais = await compute(_gerarCredenciaisEmBackground, pin);

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
      deveAlterarPin: false,
      criadoEm: DateTime.now(),
      deviceId: perfil['device_id']?.toString(),
    );

    await _usuarioRepository.createUsuario(novoUsuario);
    _usuarioLogado = novoUsuario;
  }

  Future<void> logout() async {
    _usuarioLogado = null;
    await _keyStorage.delete(key: 'user_id');
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
