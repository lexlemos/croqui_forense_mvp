// Imports ajustados
import 'package:croqui_forense_mvp/core/security/key_storage_interface.dart';
import 'package:croqui_forense_mvp/core/security/security_helper.dart';
import 'package:croqui_forense_mvp/data/models/usuario_model.dart';
import 'package:croqui_forense_mvp/data/repositories/usuario_repository.dart';
import 'package:croqui_forense_mvp/core/exceptions/auth_exception.dart'; // <--- Importe a exceção nova

class AuthService {
  final UsuarioRepository _usuarioRepository;
  final KeyStorageInterface _keyStorage;
  
  Usuario? _usuarioLogado;

  AuthService(this._usuarioRepository, this._keyStorage);

  Usuario? get usuario => _usuarioLogado;
  bool get isLogged => _usuarioLogado != null;

  // Login agora lança AuthException
  Future<void> login(String matricula, String pin) async {
    final usuario = await _usuarioRepository.getUsuarioByMatricula(matricula);
    
    if (usuario == null) {
      throw AuthException('Usuário não encontrado');
    }

    if (usuario.ativo == false) {
      throw AuthException('Usuário desativado. Contate o administrador.');
    }

    if (usuario.hashPinOffline == null || usuario.salt == null) {
      throw AuthException('Erro de integridade nas credenciais');
    }

    final hashInput = SecurityHelper.hashPin(pin, usuario.salt!);
    
    if (hashInput != usuario.hashPinOffline) {
      throw AuthException('PIN incorreto');
    }

    _usuarioLogado = usuario;
    await _keyStorage.save(key: 'user_id', value: usuario.id);
  }

  Future<void> logout() async {
    _usuarioLogado = null;
    await _keyStorage.delete(key: 'user_id');
  }

  // MUDANÇA: Renomeado para checkSession e retorna Usuario?
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
    final novoSalt = SecurityHelper.generateSalt();
    final novoHash = SecurityHelper.hashPin(novoPin, novoSalt);
    await _usuarioRepository.updatePin(usuario.id, novoHash, novoSalt);
  }
}