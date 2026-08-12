import 'package:croqui_forense_mvp/data/repositories/usuario_repository.dart';
import 'package:croqui_forense_mvp/data/models/usuario_model.dart';
import 'package:croqui_forense_mvp/data/models/papel_model.dart';
import 'package:croqui_forense_mvp/core/security/security_helper.dart';
import 'package:uuid/uuid.dart';

/// Serviço responsável pela orquestração de usuários da aplicação.
///
/// Este serviço gerencia a "Gestão Administrativa Local de Peritos/Médicos Legistas" e o controle de
/// credenciais no dispositivo. Ele permite o cadastro, listagem, associação a perfis funcionais (papéis)
/// e ativação/desativação de profissionais do Instituto de Medicina Legal (IML).
class UserService {
  final UsuarioRepository _repository;

  /// Cria uma nova instância de [UserService].
  ///
  /// Requer um [UsuarioRepository] para persistência dos dados cadastrados e alterados localmente.
  UserService(this._repository);

  /// Retorna uma lista paginada e filtrada de peritos e médicos legistas.
  ///
  /// Retorna um [Map] contendo a chave `lista` com a lista de [Usuario] e `total` com o número
  /// total de registros encontrados na base local.
  ///
  /// Parâmetros:
  /// - [page]: O índice da página a ser retornada para paginação.
  /// - [query]: Filtro de busca textual opcional (ex: por nome ou matrícula funcional).
  ///
  /// @throws DatabaseException se ocorrer erro de leitura no banco de dados local.
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

  /// Lista todos os papéis e cargos funcionais cadastrados para os peritos e profissionais.
  ///
  /// Retorna uma lista de [Papel] representando os perfis administrativos disponíveis no IML.
  ///
  /// @throws DatabaseException se houver falha de leitura no banco de dados.
  Future<List<Papel>> listarPapeis() async {
    return await _repository.getAllPapeis();
  }

  /// Cadastra um novo médico legista ou perito no dispositivo local.
  ///
  /// Gera um hash criptograficamente seguro do PIN inicial utilizando uma string aleatória
  /// (salt) única por perito, salvando os dados cadastrais funcionais com a flag de ativação
  /// e a exigência de alteração obrigatória de senha no próximo login.
  ///
  /// Parâmetros:
  /// - [nome]: Nome completo do profissional do IML.
  /// - [matricula]: Matrícula funcional oficial.
  /// - [crm]: Número do conselho regional de medicina (para médicos legistas).
  /// - [classe]: Categoria funcional da carreira policial pericial.
  /// - [role]: Perfil/papel do profissional (ex: 'PERITO_GERAL', 'ADMIN').
  /// - [pinInicial]: PIN provisório para primeiro acesso.
  ///
  /// @throws ArgumentError se alguma informação obrigatória for inválida.
  /// @throws DatabaseException se ocorrer falha na inserção no banco de dados local.
  Future<void> cadastrarNovoUsuario({
    required String nome,
    required String matricula,
    required String role,
    required String pinInicial,
  }) async {
    final salt = SecurityHelper.generateSalt();
    final hashPin = SecurityHelper.hashPin(pinInicial, salt);

    final newId = const Uuid().v4();
    final novoUsuario = Usuario(
      id: newId, 
      matriculaFuncional: matricula,
      nomeCompleto: nome,
      roles: [role],
      ativo: true,
      hashPinOffline: hashPin,
      salt: salt,
      criadoEm: DateTime.now(),
    );

    await _repository.createUsuario(novoUsuario);
  }

  /// Ativa ou desativa a credencial de acesso de um profissional do IML no dispositivo.
  ///
  /// Altera o estado lógico da flag de atividade do usuário especificado.
  /// Um perito administrativo não pode desativar a sua própria conta ativa em uso.
  ///
  /// Parâmetros:
  /// - [usuarioAlvo]: O [Usuario] que terá o estado de atividade invertido.
  /// - [idUsuarioLogado]: O identificador único do perito atualmente autenticado no aplicativo.
  ///
  /// @throws Exception Caso o perito tente desativar a si próprio.
  /// @throws DatabaseException se houver falha na escrita do novo status no repositório.
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