import 'package:croqui_forense_mvp/core/exceptions/auth_exception.dart';
import 'package:croqui_forense_mvp/domain/services/sync_service.dart';

/// Contrato abstrato (Interface) que define a comunicação do dispositivo
/// do Perito com o servidor central do IML.
///
/// Por seguir o Princípio da Inversão de Dependência (Clean Architecture),
/// esta interface garante que as regras de negócio do Domínio não conheçam 
/// pacotes de infraestrutura de rede (como Dio ou HTTP), exigindo apenas 
/// tipos primitivos e estruturas nativas do Dart.
abstract interface class IRemoteDataSource {
  /// Realiza a autenticação online do Perito junto ao servidor central.
  ///
  /// @throws [AuthException] caso as credenciais (matrícula/PIN) sejam
  /// inválidas ou haja falha na conectividade.
  Future<Map<String, dynamic>> login(String matricula, String pin);

  /// Atualiza a credencial de acesso local (PIN) do Perito no servidor central.
  ///
  /// @throws [AuthException] caso a operação seja rejeitada pelo backend
  /// ou ocorra timeout de rede.
  Future<void> trocarPin(String usuarioId, String novoPin);

  /// Sincroniza os esquemas de formulários dinâmicos e templates anatômicos
  /// atualizados e aprovados pela central para uso nos Laudos Periciais.
  ///
  /// @throws [Exception] caso o formato da resposta (JSON) seja inválido ou
  /// a comunicação com a API falhe.
  Future<List<Map<String, dynamic>>> getTiposAchados();

  /// Transmite a carga textual dos Laudos Periciais finalizados e seus 
  /// respectivos Achados (lesões) para consolidação na base de dados central.
  ///
  /// @throws [SyncPushTextualException] em caso de rejeição do payload
  /// pelo servidor central ou perda abrupta de conectividade.
  Future<Map<String, dynamic>> pushTextual(Map<String, dynamic> payload);

  /// Transmite uma Evidência Fotográfica associada a uma lesão, 
  /// garantindo a Cadeia de Custódia.
  ///
  /// Recebe o [hash] criptográfico (ex: SHA-256) calculado localmente para 
  /// atestar a integridade inviolável da imagem após a transmissão.
  ///
  /// @throws [SyncUploadEvidenciaException] se o servidor rejeitar o arquivo,
  /// houver divergência de hash na recepção ou o arquivo físico falhar.
  Future<void> uploadEvidencia({
    required String casoUuid,
    required String achadoUuid,
    required String evidenciaUuid,
    required String hash,
    required String filePath,
  });
}