import 'package:croqui_forense_mvp/data/repositories/usuario_repository.dart';
import 'package:croqui_forense_mvp/data/models/usuario_model.dart';
import 'package:croqui_forense_mvp/data/models/papel_model.dart';
import 'package:croqui_forense_mvp/core/security/security_helper.dart';
import 'package:uuid/uuid.dart';

class UserService {
  final UsuarioRepository _repository;

  UserService(this._repository);

  Future<Map<String, dynamic>> listarUsuarios({int page = 0, String? query}) async {
    final results = await Future.wait([
      _repository.getUsuarios(page: page, query: query),
      _repository.countUsuarios(query: query),
    ]);

    return {
      'lista': results[0] as List<Usuario>,
      'total': results[1] as int,
    };
  }

  Future<List<Papel>> listarPapeis() async {
    return await _repository.getAllPapeis();
  }
  Future<void> cadastrarNovoUsuario({
    required String nome,
    required String matricula,
    required String papelId,
    required String pinInicial,
  }) async {
    final salt = SecurityHelper.generateSalt();
    final hashPin = SecurityHelper.hashPin(pinInicial, salt);

    final newId = const Uuid().v4();
    final novoUsuario = Usuario(
      id: newId, 
      matriculaFuncional: matricula,
      nomeCompleto: nome,
      papelId: papelId,
      ativo: true,
      hashPinOffline: hashPin,
      deveAlterarPin: true,
      salt: salt,
      criadoEm: DateTime.now(),
    );

    await _repository.createUsuario(novoUsuario);
  }
  Future<void> alternarStatusUsuario({
    required Usuario usuarioAlvo, 
    required String idUsuarioLogado
  }) async {
    if (usuarioAlvo.id == idUsuarioLogado) {
      throw Exception('Você não pode desativar seu próprio usuário.');
    }

    final novoStatus = !usuarioAlvo.ativo;
    await _repository.updateStatusUsuario(usuarioAlvo.id, novoStatus);
  }
}