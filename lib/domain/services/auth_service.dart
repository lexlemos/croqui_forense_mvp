import 'package:croqui_forense_mvp/core/security/key_storage_interface.dart';
import 'package:croqui_forense_mvp/core/security/security_helper.dart';
import 'package:croqui_forense_mvp/data/models/usuario_model.dart';
import 'package:croqui_forense_mvp/data/repositories/usuario_repository.dart';

class AuthService {
  final UsuarioRepository _usuarioRepository;
  final IKeyStorage _keyStorage;

  static const String kSessionKey = 'user_session_id';

  AuthService(this._usuarioRepository, this._keyStorage);

  Future<Usuario?> login(String matricula, String pin) async {
    final usuario = await _usuarioRepository.getUsuarioByMatricula(matricula);

    if (usuario == null || !usuario.ativo) {
      return null;
    }

    final hashedPin = SecurityHelper.hashPin(pin);
    if (hashedPin == usuario.hashPinOffline) {
      await _keyStorage.write(kSessionKey, usuario.id.toString());
      return usuario;
    }

    return null;
  }

  Future<bool> isLogged() async {
    final sessionId = await _keyStorage.read(kSessionKey);
    return sessionId != null;
  }
  Future<void> logout() async {
    await _keyStorage.delete(kSessionKey);
  }
}