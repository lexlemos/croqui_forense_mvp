import 'dart:async';
import 'package:croqui_forense_mvp/core/security/key_storage_interface.dart';
import 'package:croqui_forense_mvp/core/security/security_helper.dart';
import 'package:croqui_forense_mvp/data/models/usuario_model.dart';
import 'package:croqui_forense_mvp/data/repositories/usuario_repository.dart';

class AuthException implements Exception {
  final String message;
  final bool isLocked;
  AuthException(this.message, {this.isLocked = false});
}

class AuthService {
  final UsuarioRepository _usuarioRepository;
  final IKeyStorage _keyStorage;

  static const String kSessionKey = 'user_session_id';
  static const String kPrefixAttempts = 'auth_attempts_';
  static const String kPrefixLockout = 'auth_lockout_';

  static const int _maxAttempts = 5;
  static const int _lockoutDurationSeconds = 60; 

  AuthService(this._usuarioRepository, this._keyStorage);

  Future<Usuario?> login(String matricula, String pin) async {
    if (await _isBlocked(matricula)) {
      throw AuthException(
        'Muitas tentativas falhas. Aguarde $_lockoutDurationSeconds segundos.',
        isLocked: true,
      );
    }
    final usuario = await _usuarioRepository.getUsuarioByMatricula(matricula);

    bool credentialsValid = false;

    if (usuario != null && usuario.ativo && usuario.salt != null) {
      credentialsValid = SecurityHelper.verifyPin(
        pin, 
        usuario.hashPinOffline, 
        usuario.salt!
      );
    }else{
      final dummySalt = 'Jb9#kL@1z'; 
      final dummyHash = 'dummy_hash_string_for_calculation';
      SecurityHelper.verifyPin(pin, dummyHash, dummySalt);
      
      credentialsValid = false;
    }

    if (!credentialsValid) {
      await _incrementAttempts(matricula);
      throw AuthException('Matrícula ou PIN inválidos.');
    }

    await _resetAttempts(matricula);
    await _keyStorage.write(kSessionKey, usuario!.id.toString());
    
    return usuario;
  }

  Future<Usuario?> checkSession() async {
    final sessionIdStr = await _keyStorage.read(kSessionKey);
    if (sessionIdStr == null) return null;

    final id = int.tryParse(sessionIdStr);
    if (id == null) return null;

    final usuario = await _usuarioRepository.getUsuarioById(id);
    
    if (usuario == null || !usuario.ativo) {
      await logout();
      return null;
    }

    return usuario;
  }

  Future<void> logout() async {
    await _keyStorage.delete(kSessionKey);
  }

  Future<bool> _isBlocked(String matricula) async {
    final lockTimeStr = await _keyStorage.read('$kPrefixLockout$matricula');
    if (lockTimeStr != null) {
      final lockTime = DateTime.parse(lockTimeStr);
      if (DateTime.now().isBefore(lockTime)) {
        return true; 
      }
      await _keyStorage.delete('$kPrefixLockout$matricula');
      await _resetAttempts(matricula);
    }
    return false;
  }

  Future<void> _incrementAttempts(String matricula) async {
    final key = '$kPrefixAttempts$matricula';
    final currentStr = await _keyStorage.read(key);
    int current = int.tryParse(currentStr ?? '0') ?? 0;

    current++;
    
    if (current >= _maxAttempts) {
      final unlockTime = DateTime.now().add(const Duration(seconds: _lockoutDurationSeconds));
      await _keyStorage.write('$kPrefixLockout$matricula', unlockTime.toIso8601String());
      await _keyStorage.delete(key); 
    } else {
      await _keyStorage.write(key, current.toString());
    }
  }

  Future<void> _resetAttempts(String matricula) async {
    await _keyStorage.delete('$kPrefixAttempts$matricula');
    await _keyStorage.delete('$kPrefixLockout$matricula');
  }
}