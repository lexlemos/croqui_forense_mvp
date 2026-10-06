import 'package:croqui_forense_mvp/core/enums/status_confirmacao_atn.dart';
import 'package:croqui_forense_mvp/core/exceptions/auth_exception.dart';
import 'package:croqui_forense_mvp/domain/services/sync_service.dart';

import 'package:croqui_forense_mvp/data/models/protocolo_lookup_model.dart';

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
  Future<Map<String, dynamic>> login(String login, String senha);

  /// Verifica a conectividade e disponibilidade do servidor central do IML.
  ///
  /// Retorna `true` se o servidor responder com status 200 ao endpoint de integridade operacional,
  /// ou `false` se houver recusa de conexão, tempo esgotado ou indisponibilidade de rede.
  Future<bool> checkHealth();

  /// Sincroniza os esquemas de formulários dinâmicos e templates anatômicos
  /// atualizados e aprovados pela central para uso nos Laudos Periciais.
  ///
  /// @throws [Exception] caso o formato da resposta (JSON) seja inválido ou
  /// a comunicação com a API falhe.
  Future<List<Map<String, dynamic>>> getTiposAchados();

  /// Consulta os dados cadastrais prévios de um procedimento a partir do PIC.
  ///
  /// Retorna uma instância de [ProtocoloLookupModel] tipada ou `null` caso ocorra
  /// falha de rede, timeout ou o protocolo não seja localizado.
  Future<ProtocoloLookupModel?> getDadosPorPic(String pic);

  /// Obtém a lista oficial de Auxiliares Técnicos de Necropsia (A.T.N.s) cadastrados no backend.
  Future<List<Map<String, dynamic>>> getAtns();

  /// Transmite a carga textual dos Laudos Periciais finalizados e seus
  /// respectivos Achados (lesões) para consolidação na base de dados central.
  ///
  /// @throws [SyncPushTextualException] em caso de rejeição do payload
  /// pelo servidor central ou perda abrupta de conectividade.
  Future<Map<String, dynamic>> pushTextual(Map<String, dynamic> payload);

  /// Sincroniza (Puxa) os casos da base central para o aplicativo,
  /// permitindo o uso em múltiplos tablets e restaurando o trabalho
  /// (inclui Lápides / Registros Removidos).
  Future<List<Map<String, dynamic>>> pullCasos({String? lastSyncTimestamp});

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
    required String? achadoUuid,
    required String evidenciaUuid,
    required String hash,
    required String filePath,
  });

  /// Faz o upload do PDF físico do Laudo para o servidor via multipart/form-data.
  /// Retorna a URL (pdfUrl) de onde o arquivo foi armazenado.
  Future<String> uploadLaudoPdf({
    required String casoUuid,
    required String filePath,
  });

  /// Atualiza o status de confirmação do ATN para um exame solicitado.
  /// Se o status for RECUSADO, a justificativa de recusa é obrigatória.
  Future<void> atualizarConfirmacaoAtnExameSolicitado({
    required String exameSolicitadoId,
    required StatusConfirmacaoATN status,
    String? justificativaRecusa,
  });

  /// Atualiza o status de confirmação do ATN para uma balística.
  /// Se o status for RECUSADO, a justificativa de recusa é obrigatória.
  Future<void> atualizarConfirmacaoAtnBalistica({
    required String balisticaId,
    required StatusConfirmacaoATN status,
    String? justificativaRecusa,
  });

  /// Configura o token Bearer de forma síncrona na memória do cliente HTTP.
  void setBearerToken(String token);
}
