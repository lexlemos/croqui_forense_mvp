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

/// Serviço de domínio encarregado do controle de autenticação e sessão do [Perito]
/// no aplicativo de diagramação de lesões (croquis).
///
/// Gerencia as credenciais do perito, permitindo o [login] online ou offline, a renovação
/// automática de tokens de segurança e a atualização obrigatória do PIN de acesso
/// em conformidade com as políticas do Instituto Médico Legal (IML).
class AuthService {
  final UsuarioRepository _usuarioRepository;
  final KeyStorageInterface _keyStorage;
  final IRemoteDataSource _remoteDataSource;

  Usuario? _usuarioLogado;

  AuthService(this._usuarioRepository, this._keyStorage, this._remoteDataSource);

  /// Retorna os dados do [Perito] atualmente autenticado na sessão do dispositivo,
  /// ou `null` caso nenhum perito esteja ativo no momento.
  Usuario? get usuario => _usuarioLogado;

  /// Indica se há uma sessão de autenticação ativa para o [Perito] neste dispositivo.
  bool get isLogged => _usuarioLogado != null;

  bool _isConnectivityError(dynamic e) {
    if (e is DioException) {
      return e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.connectionError ||
          e.error is SocketException;
    }
    if (e is AuthException) {
      final msg = e.message;
      return msg.contains('Dispositivo offline') || 
             msg.contains('Falha na comunicação');
    }
    final errStr = e.toString();
    return errStr.contains('SocketException') || 
           errStr.contains('Network') || 
           errStr.contains('timeout') || 
           errStr.contains('Failed host lookup');
  }

  /// Realiza a autenticação do [Perito] utilizando sua matrícula funcional e PIN de acesso.
  ///
  /// Padrão "Network First, Local Fallback para Login":
  /// Tenta inicialmente realizar o login online no servidor central. Se a conexão falhar por motivos
  /// de conectividade, intercepta o erro e faz a validação offline usando credenciais locais.
  /// Se as credenciais estiverem incorretas ou inválidas (401/403), rejeita imediatamente.
  Future<void> login(String login, String senha) async {
    try {
      // Passo A: Tentar realizar a requisição de login na API
      final responseData = await _remoteDataSource.login(login, senha);

      final perfil = (responseData['user'] ?? responseData['usuario']) as Map<String, dynamic>? ?? responseData;
      final accessToken = responseData['access_token']?.toString() ?? responseData['token']?.toString();
      final refreshToken = responseData['refresh_token']?.toString();

      if (accessToken == null) {
        throw const AuthException('Token ausente na resposta.');
      }

      final userId = perfil['usuario_id']?.toString() ??
          perfil['id']?.toString() ??
          responseData['usuario_id']?.toString() ??
          responseData['id']?.toString() ??
          '';

      final nomeCompleto = perfil['usuario_nome']?.toString() ??
          perfil['nome_completo']?.toString() ??
          perfil['nome']?.toString() ??
          responseData['usuario_nome']?.toString() ??
          '';

      final matriculaFuncional = perfil['matricula_funcional']?.toString() ??
          perfil['matricula']?.toString() ??
          login;

      if (userId.isEmpty) {
        throw const AuthException('ID do usuário não fornecido pela API.');
      }

      await _keyStorage.save(key: 'access_token', value: accessToken);
      if (refreshToken != null) {
        await _keyStorage.save(key: 'refresh_token', value: refreshToken);
      }
      await _keyStorage.save(key: 'user_id', value: userId);

      final credenciais = _gerarCredenciaisEmBackground(senha);

      final rawRoles = perfil['roles'] ?? perfil['role'] ?? responseData['roles'];
      List<String> roles = [];
      if (rawRoles is List) {
        roles = rawRoles.map((e) => e.toString()).toList();
      } else if (rawRoles is String && rawRoles.isNotEmpty) {
        if (rawRoles.startsWith('[') && rawRoles.endsWith(']')) {
          try {
            final decoded = jsonDecode(rawRoles);
            if (decoded is List) {
              roles = decoded.map((e) => e.toString()).toList();
            }
          } catch (_) {
            roles = [rawRoles];
          }
        } else {
          roles = [rawRoles];
        }
      }

      final novoUsuario = Usuario(
        id: userId,
        matriculaFuncional: matriculaFuncional,
        nomeCompleto: nomeCompleto,
        roles: roles,
        ativo: true,
        hashPinOffline: credenciais['hash']!,
        salt: credenciais['salt']!,
        deveAlterarPin: perfil['deve_alterar_pin'] == true || perfil['deve_alterar_pin'] == 1,
        criadoEm: DateTime.now(),
        deviceId: perfil['device_id']?.toString(),
      );

      await _usuarioRepository.createUsuario(novoUsuario);
      _usuarioLogado = novoUsuario;

      developer.log('[AUTH] Login online realizado com sucesso (ID: $userId)', name: 'AuthService');

    } catch (e) {
      // Passo B: Se for uma exceção de conectividade, tentar local fallback
      if (_isConnectivityError(e)) {
        final localUsuario = await _usuarioRepository.getUsuarioByMatricula(login);
        if (localUsuario == null) {
          throw const AuthException('Dispositivo offline e sem dados locais armazenados para este usuário.');
        }

        if (localUsuario.ativo == false) {
          throw const AuthException('Usuário desativado.');
        }

        if (localUsuario.hashPinOffline == null || localUsuario.salt == null) {
          throw const AuthException('Erro de integridade nas credenciais locais.');
        }

        final bool isPinValido = await compute(_verificarPinEmBackground, {
          'pin': senha,
          'hash': localUsuario.hashPinOffline!,
          'salt': localUsuario.salt!,
        });

        if (!isPinValido) {
          throw const AuthException('Senha ou PIN incorreto');
        }

        _usuarioLogado = localUsuario;
        await _keyStorage.save(key: 'user_id', value: localUsuario.id);

        developer.log('[AUTH] Sem internet: Login via cache local autorizado', name: 'AuthService');
        return;
      }

      // Passo C: Se for 401/403 ou qualquer outro erro de credenciais inválidas, rejeita imediatamente
      if (e is AuthException) {
        rethrow;
      }
      throw AuthException('Erro de autenticação: $e');
    }
  }

  /// Encerra a sessão ativa do [Perito] corrente no dispositivo.
  ///
  /// Limpa a referência em memória do perito e remove de forma segura as chaves de acesso
  /// (tokens temporários de API e identificador do usuário) do armazenamento criptografado
  /// local para prevenir o acesso indevido aos laudos periciais.
  Future<void> logout() async {
    _usuarioLogado = null;
    await _keyStorage.delete(key: 'access_token');
    await _keyStorage.delete(key: 'refresh_token');
    await _keyStorage.delete(key: 'user_id');
  }

  /// Expira a sessão em memória do [Perito] ativo no momento de forma silenciosa.
  ///
  /// Utilizado internamente pelo interceptor de autenticação de rede para invalidar a sessão
  /// local quando os tokens de atualização (refresh tokens) falham no servidor central,
  /// forçando o perito a se reautenticar para a continuidade segura dos trabalhos.
  void forceExpireSession() {
    _usuarioLogado = null;
  }

  /// Verifica e recupera uma sessão pré-existente salva para algum [Perito] neste dispositivo.
  ///
  /// Lê o identificador único do perito guardado no chaveiro criptografado e carrega seu respectivo
  /// perfil do banco de dados local. Retorna o [Usuario] correspondente ativo ou `null`.
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

  /// Efetua a troca obrigatória de senha do [Perito].
  ///
  /// Envia a nova senha cifrada para atualização no servidor central e, após confirmação remota,
  /// calcula a derivação da credencial (hash e salt) em segundo plano para persistir a nova chave
  /// de validação local no banco de dados do dispositivo.
  ///
  /// @throws [AuthException] se ocorrer falha de conectividade com a rede ou se a alteração for
  /// rejeitada pelas políticas de segurança do servidor.
  Future<void> alterarSenhaObrigatoria(Usuario usuario, String novaSenha) async {
    await _remoteDataSource.alterarSenha(usuario.id, novaSenha);

    final resultado = await compute(_gerarCredenciaisEmBackground, novaSenha);

    await _usuarioRepository.updatePin(
      usuario.id,
      resultado['hash']!,
      resultado['salt']!,
    );

    if (_usuarioLogado != null && _usuarioLogado!.id == usuario.id) {
      _usuarioLogado = _usuarioLogado!.copyWith(deveAlterarPin: false);
    }
  }

  Future<void> saveSavedLogin(String login) async {
    await _keyStorage.save(key: 'saved_login', value: login);
  }

  Future<String?> getSavedLogin() async {
    return await _keyStorage.read(key: 'saved_login');
  }
}

