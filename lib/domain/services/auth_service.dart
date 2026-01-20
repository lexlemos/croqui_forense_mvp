import 'package:flutter/foundation.dart'; 
import 'package:croqui_forense_mvp/core/security/key_storage_interface.dart';
import 'package:croqui_forense_mvp/core/security/security_helper.dart';
import 'package:croqui_forense_mvp/data/models/usuario_model.dart';
import 'package:croqui_forense_mvp/data/repositories/usuario_repository.dart';
import 'package:croqui_forense_mvp/core/exceptions/auth_exception.dart';

bool _verificarPinEmBackground(Map<String, String> dados) {

  final pin = dados['pin']!;
  final hash = dados['hash']!;
  final salt = dados['salt']!;
  
  final resultado = SecurityHelper.verifyPin(pin, hash, salt);
  
  return resultado;
}

Map<String, String> _gerarCredenciaisEmBackground(String pin) {
  final salt = SecurityHelper.generateSalt();
  final hash = SecurityHelper.hashPin(pin, salt);
  return {'hash': hash, 'salt': salt};
}

class AuthService {
  final UsuarioRepository _usuarioRepository;
  final KeyStorageInterface _keyStorage;
  
  Usuario? _usuarioLogado;

  AuthService(this._usuarioRepository, this._keyStorage);

  Usuario? get usuario => _usuarioLogado;
  bool get isLogged => _usuarioLogado != null;

  Future<void> login(String matricula, String pin) async {
    
    final usuario = await _usuarioRepository.getUsuarioByMatricula(matricula);
    if (usuario == null) throw AuthException('Usuário não encontrado');
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
      resultado['salt']!
    );

    if (_usuarioLogado != null && _usuarioLogado!.id == usuario.id) {
      _usuarioLogado = _usuarioLogado!.copyWith(deveAlterarPin: false);
    }
  }
}