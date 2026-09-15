import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:croqui_forense_mvp/core/security/key_storage_interface.dart';
import 'package:croqui_forense_mvp/core/security/security_helper.dart';
import 'package:croqui_forense_mvp/data/models/usuario_model.dart';
import 'package:croqui_forense_mvp/data/repositories/usuario_repository.dart';
import 'package:croqui_forense_mvp/core/exceptions/auth_exception.dart';
import 'package:croqui_forense_mvp/domain/repositories/remote_data_source.dart';

/// Função em nível superior para verificação assíncrona do PIN pericial em segundo plano via [compute],
/// garantindo que a execução dos cálculos criptográficos não cause travamentos na interface do usuário.
bool _verificarPinEmBackground(Map<String, String> dados) {
  final String pin = dados['pin'] ?? '';
  final String hash = dados['hash'] ?? '';
  final String salt = dados['salt'] ?? '';
  return SecurityHelper.verifyPin(pin, hash, salt);
}

/// Função em nível superior para derivação de chaves e salt criptográfico em segundo plano via [compute],
/// empregada durante o provisionamento de credenciais locais para autenticação offline do perito.
Map<String, String> _gerarCredenciaisEmBackground(String pin) {
  final String salt = SecurityHelper.generateSalt();
  final String hash = SecurityHelper.hashPin(pin, salt);
  return <String, String>{'hash': hash, 'salt': salt};
}

/// Serviço de domínio encarregado do controle de autenticação, ciclo de vida da sessão
/// e aplicação de políticas de autorização baseadas em funções (RBAC) no aplicativo pericial.
///
/// Implementa a estratégia arquitetural "Network-First com Fallback Offline Local",
/// permitindo a operação ininterrupta do perito criminal tanto em ambiente conectado
/// quanto em zonas remotas ou contingências operacionais desprovidas de sinal de rede.
class AuthService {
  /// Conjunto imutável de perfis institucionais estritamente autorizados a operar o
  /// aplicativo pericial de Necrópsia Digital conforme as diretrizes de governança RBAC.
  static const Set<String> _perfisAutorizados = <String>{
    'PERITO',
    'MEDICO_LEGISTA',
    'ADMIN',
  };

  final UsuarioRepository _usuarioRepository;
  final KeyStorageInterface _keyStorage;
  final IRemoteDataSource _remoteDataSource;

  Usuario? _usuarioLogado;

  /// Inicializa o serviço de autenticação injetando os repositórios de dados locais,
  /// o provedor de armazenamento seguro de chaves e a fonte de dados remota.
  AuthService(this._usuarioRepository, this._keyStorage, this._remoteDataSource);

  /// Retorna o [Usuario] pericial autenticado na sessão ativa do dispositivo,
  /// ou `null` caso nenhuma sessão válida esteja inicializada.
  Usuario? get usuario => _usuarioLogado;

  /// Indica se existe uma sessão ativa de usuário autenticado no dispositivo.
  bool get isLogged => _usuarioLogado != null;

  /// Analisa se uma exceção capturada corresponde a uma falha de conectividade ou transporte de rede,
  /// habilitando a transição resiliente para a rotina de validação offline local.
  bool _isConnectivityError(Object e) {
    if (e is DioException) {
      return e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.connectionError ||
          e.error is SocketException;
    }
    if (e is AuthException) {
      final String msg = e.message;
      return msg.contains('Dispositivo offline') ||
          msg.contains('Falha na comunicação');
    }
    final String errStr = e.toString();
    return errStr.contains('SocketException') ||
        errStr.contains('Network') ||
        errStr.contains('timeout') ||
        errStr.contains('Failed host lookup');
  }

  /// Realiza a autenticação institucional do usuário por meio de credenciais funcionais (matrícula/e-mail e PIN/senha).
  ///
  /// Aplica a estratégia "Network-First com Fallback Offline Local":
  /// 1. Tenta autenticação remota junto à API central do IML.
  /// 2. Valida a presença do token e extrai as permissões (roles).
  /// 3. Aplica a trava estrita de segurança RBAC: apenas perfis 'PERITO', 'MEDICO_LEGISTA' ou 'ADMIN'
  ///    podem prosseguir. Se o usuário não possuir pelo menos um desses perfis, uma [AuthException]
  ///    é imediatamente disparada e NENHUM token é persistido no Secure Storage.
  /// 4. Somente após a validação bem-sucedida das roles, os tokens e identificadores são gravados
  ///    no chaveiro seguro e o perfil é persistido no banco local.
  /// 5. Em caso de falha de conectividade (rede/timeout), recorre ao cache local criptografado para
  ///    validar as credenciais offline do último usuário autenticado no dispositivo.
  Future<void> login(String login, String senha) async {
    try {
      final Map<String, dynamic> rawResponse = await _remoteDataSource.login(login, senha);
      final Map<String, Object?> responseData = Map<String, Object?>.from(rawResponse);

      final Object? rawPerfil = responseData['user'] ?? responseData['usuario'];
      final Map<String, Object?> perfil = rawPerfil is Map
          ? (rawPerfil is Map<String, Object?>
              ? rawPerfil
              : Map<String, Object?>.from(rawPerfil))
          : responseData;

      final String? accessToken = responseData['access_token']?.toString() ??
          responseData['token']?.toString();
      final String? refreshToken = responseData['refresh_token']?.toString();

      if (accessToken == null || accessToken.trim().isEmpty) {
        throw const AuthException('Token de autenticação ausente na resposta do servidor.');
      }

      final String userId = perfil['usuario_id']?.toString() ??
          perfil['id']?.toString() ??
          responseData['usuario_id']?.toString() ??
          responseData['id']?.toString() ??
          '';

      final String nomeCompleto = perfil['usuario_nome']?.toString() ??
          perfil['nome_completo']?.toString() ??
          perfil['nome']?.toString() ??
          responseData['usuario_nome']?.toString() ??
          '';

      final String matriculaFuncional = perfil['matricula_funcional']?.toString() ??
          perfil['matricula']?.toString() ??
          login;

      if (userId.trim().isEmpty) {
        throw const AuthException('Identificador de usuário não fornecido pela API.');
      }

      final Object? rawRoles = perfil['roles'] ?? perfil['role'] ?? responseData['roles'];
      final List<String> roles = <String>[];
      if (rawRoles is List) {
        for (final Object? item in rawRoles) {
          if (item != null) {
            final String roleStr = item.toString().trim();
            if (roleStr.isNotEmpty) {
              roles.add(roleStr);
            }
          }
        }
      } else if (rawRoles is String && rawRoles.trim().isNotEmpty) {
        final String trimmed = rawRoles.trim();
        if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
          try {
            final Object? decoded = jsonDecode(trimmed);
            if (decoded is List) {
              for (final Object? item in decoded) {
                if (item != null) {
                  final String roleStr = item.toString().trim();
                  if (roleStr.isNotEmpty) {
                    roles.add(roleStr);
                  }
                }
              }
            }
          } on Object catch (_) {
            roles.add(trimmed);
          }
        } else {
          roles.add(trimmed);
        }
      }

      final bool isAutorizado = roles.any(
        (String role) => _perfisAutorizados.contains(role.trim().toUpperCase()),
      );

      if (!isAutorizado) {
        throw const AuthException(
          'Acesso restrito: seu perfil funcional não possui autorização para operar o aplicativo. '
          'Acesso permitido exclusivamente para Perito, Médico Legista ou Administrador.',
        );
      }

      await _keyStorage.save(key: 'access_token', value: accessToken);
      _remoteDataSource.setBearerToken(accessToken);

      if (refreshToken != null && refreshToken.trim().isNotEmpty) {
        await _keyStorage.save(key: 'refresh_token', value: refreshToken);
      }
      await _keyStorage.save(key: 'user_id', value: userId);
      await _keyStorage.save(key: 'last_user_id', value: userId);

      final Map<String, String> credenciais = _gerarCredenciaisEmBackground(senha);

      final Usuario novoUsuario = Usuario(
        id: userId,
        matriculaFuncional: matriculaFuncional,
        nomeCompleto: nomeCompleto,
        roles: roles,
        ativo: true,
        hashPinOffline: credenciais['hash'] ?? '',
        salt: credenciais['salt'] ?? '',
        criadoEm: DateTime.now(),
        deviceId: perfil['device_id']?.toString(),
      );

      await _usuarioRepository.createUsuario(novoUsuario);
      _usuarioLogado = novoUsuario;

      developer.log(
        '[AUTH] Login online e validação RBAC concluídos com sucesso (ID: $userId)',
        name: 'AuthService',
      );
    } on Object catch (e) {
      if (_isConnectivityError(e)) {
        final Usuario? localUsuario = await _usuarioRepository.getUsuarioByMatricula(login);
        if (localUsuario == null) {
          throw const AuthException('Dispositivo offline e sem dados locais armazenados para este usuário.');
        }

        final String? lastUserId = await _keyStorage.read(key: 'last_user_id');
        if (lastUserId == null || localUsuario.id != lastUserId) {
          throw const AuthException('O login offline só é permitido para o último usuário autenticado neste dispositivo.');
        }

        if (localUsuario.ativo == false) {
          throw const AuthException('Usuário desativado.');
        }

        final bool hasOfflineRole = localUsuario.roles.any(
          (String role) => _perfisAutorizados.contains(role.trim().toUpperCase()),
        );
        if (!hasOfflineRole) {
          throw const AuthException(
            'Acesso restrito: usuário local sem autorização de Perito, Médico Legista ou Administrador.',
          );
        }

        if (localUsuario.hashPinOffline == null || localUsuario.salt == null) {
          throw const AuthException('Erro de integridade nas credenciais locais.');
        }

        final bool isPinValido = await compute(_verificarPinEmBackground, <String, String>{
          'pin': senha,
          'hash': localUsuario.hashPinOffline ?? '',
          'salt': localUsuario.salt ?? '',
        });

        if (!isPinValido) {
          throw const AuthException('Senha ou PIN incorreto');
        }

        _usuarioLogado = localUsuario;
        await _keyStorage.save(key: 'user_id', value: localUsuario.id);

        developer.log('[AUTH] Sem internet: Login via cache local autorizado', name: 'AuthService');
        return;
      }

      if (e is AuthException) {
        rethrow;
      }
      throw AuthException('Erro de autenticação: $e');
    }
  }

  /// Encerra a sessão ativa do perito corrente no dispositivo.
  ///
  /// Limpa a referência em memória do usuário e remove de forma segura e definitiva
  /// as chaves de acesso (tokens temporários de API e identificadores) do armazenamento
  /// criptografado local para prevenir o acesso indevido aos laudos periciais.
  Future<void> logout() async {
    _usuarioLogado = null;
    await _keyStorage.delete(key: 'access_token');
    await _keyStorage.delete(key: 'refresh_token');
    await _keyStorage.delete(key: 'user_id');
  }

  /// Expira a sessão em memória do usuário ativo no momento de forma silenciosa.
  ///
  /// Utilizado internamente pelo interceptor de rede quando os tokens de atualização
  /// (refresh tokens) falham no servidor central, forçando o perito a se autenticar novamente.
  void forceExpireSession() {
    _usuarioLogado = null;
  }

  /// Verifica e recupera uma sessão persistente para este dispositivo.
  ///
  /// Lê o identificador único guardado no chaveiro criptografado e valida o registro
  /// bem como as permissões de acesso RBAC no banco de dados local. Retorna o [Usuario] ativo ou `null`.
  Future<Usuario?> checkSession() async {
    final String? id = await _keyStorage.read(key: 'user_id');

    if (id != null) {
      await _loadUsuario(id);
    }
    return _usuarioLogado;
  }

  /// Carrega o perfil do perito a partir da base de dados local aplicando as validações RBAC.
  ///
  /// Caso o usuário esteja inativo ou seu perfil não atenda às permissões autorizadas,
  /// executa o [logout] preventivo para anular a sessão residual.
  Future<void> _loadUsuario(String id) async {
    try {
      final Usuario? usuario = await _usuarioRepository.getUsuarioById(id);
      if (usuario != null && usuario.ativo) {
        final bool isAutorizado = usuario.roles.any(
          (String role) => _perfisAutorizados.contains(role.trim().toUpperCase()),
        );
        if (isAutorizado) {
          _usuarioLogado = usuario;
          return;
        }
      }
      await logout();
    } on Object catch (_) {
      await logout();
    }
  }

  /// Armazena no Secure Storage a identificação funcional (matrícula ou e-mail) para preenchimento ágil.
  Future<void> saveSavedLogin(String login) async {
    await _keyStorage.save(key: 'saved_login', value: login);
  }

  /// Recupera do Secure Storage a última identificação funcional registrada no dispositivo.
  Future<String?> getSavedLogin() async {
    return await _keyStorage.read(key: 'saved_login');
  }
}
