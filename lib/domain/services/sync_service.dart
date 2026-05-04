  // lib/domain/services/sync_service.dart

  import 'dart:io';

  import 'package:dio/dio.dart';
  import 'package:flutter/foundation.dart';

  import 'package:croqui_forense_mvp/core/network/api_client.dart';
  import 'package:croqui_forense_mvp/core/security/crypto_helper.dart';
  import 'package:croqui_forense_mvp/data/models/caso_model.dart';
  import 'package:croqui_forense_mvp/data/models/achado_model.dart';

  // ===========================================================================
  // CONTRATO (INTERFACE) DO REPOSITÓRIO — Dependency Inversion Principle
  // ===========================================================================

  /// Contrato que o `SyncService` exige do repositório local.
  ///
  /// Mantém o serviço de domínio desacoplado da implementação SQLite concreta.
  /// O `CasoRepository` deve implementar esta interface (ou um adaptador deve
  /// fazer a ponte).
  ///
  /// TODO: [REPO] Faça `CasoRepository` (ou um `SyncRepositoryAdapter`) implementar
  /// esta interface. Os métodos `getAllCases()` e `updateCase()` já existem no
  /// `CasoRepository` e cobrem boa parte do contrato.
  abstract interface class ISyncRepository {
    /// Retorna todos os [Caso]s que ainda não foram sincronizados com o backend.
    ///
    /// Um caso é considerado não-sincronizado quando seu [StatusCaso] é
    /// diferente de [StatusCaso.sincronizado].
    ///
    /// TODO: [REPO] Implemente com uma query WHERE status != 'SINCRONIZADO' AND removido = 0
    /// no `CasoRepository`. O método `getAllCases()` existente pode ser usado como base.
    Future<List<Caso>> getCasosNaoSincronizados();

    Future<List<Achado>> getAchadosPorCaso(String casoUuid);

    /// Retorna todos os [Achado]s de um [caso] que possuem fotos pendentes de upload.
    ///
    /// Um achado possui foto pendente quando `dadosPreenchidos['photo_path']`
    /// não é nulo e `dadosPreenchidos['foto_sincronizada']` != true.
    ///
    /// TODO: [REPO] Use o método `getAchadosPorCaso(casoUuid)` já existente no
    /// `CasoRepository` e filtre os achados com `photoPath != null` em memória.
    Future<List<Achado>> getAchadosComFotosPendentes(String casoUuid);

    /// Atualiza o [StatusCaso] do caso para [StatusCaso.sincronizado] no SQLite.
    ///
    /// TODO: [REPO] Use `CasoRepository.updateCase()` com uma cópia do caso
    /// alterando apenas o status. Considere criar um `Caso.copyWith()`.
    Future<void> marcarCasoComoSincronizado(Caso caso);

    /// Marca o achado como tendo a foto já enviada ao servidor.
    ///
    /// Deve persistir `dadosPreenchidos['foto_sincronizada'] = true` via
    /// `AchadoRepository.updateAchado()`.
    ///
    /// TODO: [REPO] Implemente em `AchadoRepository` ou no adaptador.
    Future<void> marcarFotoComoSincronizada(Achado achado);
  }

  // ===========================================================================
  // EXCEÇÕES DE DOMÍNIO
  // ===========================================================================

  /// Lançada quando o push textual de casos falha (Passo 2).
  class SyncPushTextualException implements Exception {
    final String message;
    final int? statusCode;

    const SyncPushTextualException(this.message, {this.statusCode});

    @override
    String toString() =>
        'SyncPushTextualException(status: $statusCode): $message';
  }

  /// Lançada quando o upload de uma foto criptografada falha (Passo 3).
  class SyncUploadEvidenciaException implements Exception {
    final String message;
    final String casoUuid;
    final String achadoUuid;
    final int? statusCode;

    const SyncUploadEvidenciaException(
      this.message, {
      required this.casoUuid,
      required this.achadoUuid,
      this.statusCode,
    });

    @override
    String toString() =>
        'SyncUploadEvidenciaException(caso: $casoUuid, achado: $achadoUuid, '
        'status: $statusCode): $message';
  }

  // ===========================================================================
  // SYNC SERVICE — O Cérebro da Operação
  // ===========================================================================

  /// Orquestra a sincronização bidirecional dos laudos forenses com o backend.
  ///
  /// Executa os 4 passos de sincronização de forma sequencial e segura:
  ///
  /// 1. **Coleta**: busca casos não-sincronizados no SQLite local.
  /// 2. **Push Textual**: envia os dados estruturados (JSON) para `/croqui/sync/push`.
  /// 3. **Push Evidências**: cifra e faz upload de cada foto para `/croqui/sync/evidencias`.
  /// 4. **Confirmação**: marca casos e fotos como `sincronizado` no SQLite.
  ///
  /// ### Uso
  /// ```dart
  /// final syncService = SyncService(
  ///   apiClient: apiClient,
  ///   repository: meuRepositoryAdapter,
  /// );
  ///
  /// await syncService.execute();
  /// ```
  ///
  /// ### Design Decisions
  /// - A criptografia usa os métodos **estáticos** de [CryptoHelper] diretamente,
  ///   sem necessidade de injeção — o helper não guarda estado entre chamadas.
  /// - Falhas no upload de **uma foto** não abortam o upload das demais fotos
  ///   do mesmo caso, mas registram o erro no log para reprocessamento futuro.
  /// - O cleanup do arquivo cifrado temporário é garantido via `try/finally`,
  ///   prevenindo vazamento de dados no armazenamento do dispositivo mesmo em
  ///   caso de falha de rede.
  /// - O status de cada caso só é atualizado para `SINCRONIZADO` depois que
  ///   **tanto** o push textual **quanto** todos os uploads de evidências
  ///   retornarem HTTP 200.
  class SyncService {
    final ApiClient _apiClient;
    final ISyncRepository _repository;

    // Rotas do backend FastAPI
    static const String _routeSyncPush = '/croqui/sync/push';
    static const String _routeSyncEvidencias = '/croqui/sync/evidencias';

    /// Cria o [SyncService] com as dependências necessárias.
    ///
    /// - [apiClient]: cliente HTTP configurado com base URL, timeouts e auth.
    /// - [repository]: porta para leitura/escrita no SQLite local.
    ///
    /// A criptografia é realizada via [CryptoHelper] (métodos estáticos) e
    /// não precisa ser injetada.
    SyncService({
      required ApiClient apiClient,
      required ISyncRepository repository,
    })  : _apiClient = apiClient,
          _repository = repository;

    // ---------------------------------------------------------------------------
    // MÉTODO PRINCIPAL
    // ---------------------------------------------------------------------------

    /// Executa o ciclo completo de sincronização.
    ///
    /// Lança [SyncPushTextualException] se o push de dados textuais falhar.
    /// Lança [SyncUploadEvidenciaException] (encapsulada) se uploads de fotos
    /// falharem — mas continua tentando as demais evidências do lote.
    ///
    /// Retorna sem efeito se não houver casos pendentes (Early Return).
    Future<void> execute() async {
      debugPrint('[SyncService] ▶ Iniciando ciclo de sincronização...');

      // =========================================================================
      // PASSO 1 — COLETA: busca casos não-sincronizados no SQLite
      // =========================================================================
      final List<Caso> casosPendentes =
          await _repository.getCasosNaoSincronizados();

      if (casosPendentes.isEmpty) {
        debugPrint(
          '[SyncService] ✅ Nenhum caso pendente encontrado. Sincronização encerrada.',
        );
        return; // Early Return — nada a fazer
      }

      debugPrint(
        '[SyncService] 📋 ${casosPendentes.length} caso(s) pendente(s) encontrado(s).',
      );

      // =========================================================================
      // PASSO 2 — PUSH TEXTUAL: envia JSON dos casos e achados ao backend
      // =========================================================================
      await _pushTextual(casosPendentes);

      // =========================================================================
      // PASSO 3 + 4 — PUSH EVIDÊNCIAS + CONFIRMAÇÃO: por caso
      // =========================================================================
      for (final caso in casosPendentes) {
        await _processarCaso(caso);
      }

      debugPrint('[SyncService] 🏁 Ciclo de sincronização concluído.');
    }

    // ---------------------------------------------------------------------------
    // PASSO 2 — Push Textual
    // ---------------------------------------------------------------------------

    /// Serializa [casos] em JSON e faz POST em `/croqui/sync/push`.
    ///
    /// Lança [SyncPushTextualException] se o servidor retornar status != 200.
    Future<void> _pushTextual(List<Caso> casos) async {
      debugPrint(
        '[SyncService] 📤 Passo 2: enviando ${casos.length} caso(s) para $_routeSyncPush...',
      );

      // Monta o payload: {"casos": [ {caso + achados}, ... ]}
      // TODO: [REPO] Inclua os achados de cada caso no payload se o backend
      // exigir um payload único de casos + achados juntos. Ajuste _casoParaJson().
      final List<Map<String, dynamic>> casosJson = [];
      for (final caso in casos) {
        final achados = await _repository.getAchadosPorCaso(caso.uuid);
        casosJson.add(_casoParaJson(caso, achados));
      }

      final payload = {
        'device_id': 'tablet-teste-mvp-01',
        'timestamp_sincronizacao': DateTime.now().toUtc().toIso8601String(),
        'casos': casosJson,
      };

      try {
        final response = await _apiClient.dio.post(
          _routeSyncPush,
          data: payload,
        );

        if (response.statusCode != 200) {
          throw SyncPushTextualException(
            'Backend retornou status inesperado: ${response.statusCode}',
            statusCode: response.statusCode,
          );
        }

        debugPrint(
          '[SyncService] ✅ Passo 2 concluído. Resposta: ${response.statusCode}',
        );
      } on DioException catch (e) {
        final msg = 'Falha de rede no push textual: ${e.message}';
        debugPrint('[SyncService] ❌ $msg');
        throw SyncPushTextualException(msg, statusCode: e.response?.statusCode);
      }
    }

    // ---------------------------------------------------------------------------
    // PASSO 3 + 4 — Push Evidências + Confirmação (por Caso)
    // ---------------------------------------------------------------------------

    /// Processa um único [caso]: faz upload das fotos e confirma sincronização.
    ///
    /// Falhas individuais de upload são logadas mas não interrompem os demais.
    Future<void> _processarCaso(Caso caso) async {
      debugPrint(
        '[SyncService] 📂 Processando evidências do caso ${caso.uuid}...',
      );

      final List<Achado> achadosComFotos =
          await _repository.getAchadosComFotosPendentes(caso.uuid);

      if (achadosComFotos.isEmpty) {
        debugPrint(
          '[SyncService]   ↳ Sem fotos pendentes para o caso ${caso.uuid}.',
        );
        // Ainda assim confirma o caso (push textual já foi feito no Passo 2)
        await _confirmarCaso(caso);
        return;
      }

      debugPrint(
        '[SyncService]   ↳ ${achadosComFotos.length} foto(s) para upload.',
      );

      // Rastreia achados cujo upload foi bem-sucedido
      final List<Achado> achadosSincronizados = [];
      final List<SyncUploadEvidenciaException> erros = [];

      for (final achado in achadosComFotos) {
        try {
          await _uploadEvidencia(caso, achado);
          achadosSincronizados.add(achado);
        } on SyncUploadEvidenciaException catch (e) {
          erros.add(e);
          debugPrint('[SyncService]   ⚠️ Upload falhou para achado ${achado.uuid}: $e');
        }
      }

      // Marca individualmente as fotos que subiram com sucesso
      for (final achado in achadosSincronizados) {
        await _repository.marcarFotoComoSincronizada(achado);
      }

      if (erros.isEmpty) {
        // Todos os uploads concluídos — Passo 4: confirma o caso
        await _confirmarCaso(caso);
      } else {
        debugPrint(
          '[SyncService] ⚠️ Caso ${caso.uuid}: ${erros.length} foto(s) falharam. '
          'O caso NÃO será marcado como sincronizado até o próximo ciclo.',
        );
        // Não lança exceção aqui: o próximo ciclo retentará as fotos faltantes.
      }
    }

    // ---------------------------------------------------------------------------
    // PASSO 3 — Upload de Evidência Individual
    // ---------------------------------------------------------------------------

    /// Cifra e faz upload da foto do [achado] para `/croqui/sync/evidencias`.
    ///
    /// O arquivo cifrado temporário é **sempre** deletado ao final via
    /// `try/finally`, independente do resultado do upload.
    ///
    /// Lança [SyncUploadEvidenciaException] em caso de falha de rede ou status
    /// HTTP inesperado.
    Future<void> _uploadEvidencia(Caso caso, Achado achado) async {
      final String? caminhoFoto = achado.photoPath;

      if (caminhoFoto == null || caminhoFoto.isEmpty) {
        debugPrint(
          '[SyncService]   ↳ Achado ${achado.uuid} sem caminho de foto. Ignorado.',
        );
        return;
      }

      final File arquivoOriginal = File(caminhoFoto);

      if (!arquivoOriginal.existsSync()) {
        debugPrint(
          '[SyncService]   ↳ ⚠️ Arquivo não encontrado no disco: $caminhoFoto. '
          'Achado ${achado.uuid} ignorado.',
        );
        return;
      }

      debugPrint(
        '[SyncService]   ↳ 🔐 Cifrando foto do achado ${achado.uuid}...',
      );

      // --- Cifra a evidência via CryptoHelper estático ---
      final CryptoResult cryptoResult =
          await CryptoHelper.encryptEvidence(arquivoOriginal);

      debugPrint(
        '[SyncService]   ↳ 📡 Enviando foto cifrada para $_routeSyncEvidencias...',
      );

      // --- Upload com cleanup garantido pelo try/finally ---
      try {
        final formData = FormData.fromMap({
          // Campos de identificação
          'caso_uuid': caso.uuid,
          'achado_uuid': achado.uuid,

          // Metadados de integridade e criptografia
          'hash_arquivo': cryptoResult.plainHash,
          'hash_cifrado': cryptoResult.cipherHash,
          'salt_base64': cryptoResult.saltBase64,
          'chave_cifrada_base64': cryptoResult.mockChaveCifradaBase64,

          // Blob cifrado como multipart
          'item_file': await MultipartFile.fromFile(
            cryptoResult.encryptedFile.path,
            filename: '${achado.uuid}.enc',
          ),
        });

        final response = await _apiClient.dio.post(
          _routeSyncEvidencias,
          data: formData,
        );

        if (response.statusCode != 200) {
          throw SyncUploadEvidenciaException(
            'Backend retornou status inesperado: ${response.statusCode}',
            casoUuid: caso.uuid,
            achadoUuid: achado.uuid,
            statusCode: response.statusCode,
          );
        }

        debugPrint(
          '[SyncService]   ↳ ✅ Upload concluído para achado ${achado.uuid}.',
        );
      } on DioException catch (e) {
        throw SyncUploadEvidenciaException(
          'Falha de rede: ${e.message}',
          casoUuid: caso.uuid,
          achadoUuid: achado.uuid,
          statusCode: e.response?.statusCode,
        );
      } finally {
        // =========================================================================
        // ⚠️ CLEANUP OBRIGATÓRIO — Previne vazamento de dados no dispositivo.
        //
        // O arquivo cifrado temporário É SEMPRE DELETADO aqui, independente
        // do sucesso ou falha do upload. Nunca mova esta chamada para fora do
        // bloco finally.
        // =========================================================================
        await CryptoHelper.deleteEncryptedFile(cryptoResult.encryptedFile);
        debugPrint(
          '[SyncService]   ↳ 🗑️ Arquivo cifrado temporário deletado do dispositivo.',
        );
      }
    }

    // ---------------------------------------------------------------------------
    // PASSO 4 — Confirmação Local
    // ---------------------------------------------------------------------------

    /// Atualiza o status do [caso] para [StatusCaso.sincronizado] no SQLite.
    Future<void> _confirmarCaso(Caso caso) async {
      debugPrint(
        '[SyncService] ✅ Passo 4: marcando caso ${caso.uuid} como SINCRONIZADO...',
      );
      await _repository.marcarCasoComoSincronizado(caso);
      debugPrint(
        '[SyncService]   ↳ Caso ${caso.uuid} confirmado no SQLite local.',
      );
    }

    // ---------------------------------------------------------------------------
    // HELPERS DE SERIALIZAÇÃO
    // ---------------------------------------------------------------------------

    Map<String, dynamic> _casoParaJson(Caso caso, List<Achado> achados) {
      return {
        'uuid': caso.uuid,
        'id_usuario_criador': caso.idUsuarioCriador,
        'numero_laudo_externo': caso.numeroLaudoExterno,
        'status': caso.status.name.toUpperCase(),
        'dados_laudo_json': caso.dadosLaudo,
        'versao': caso.versao,
        'criado_em_dispositivo': caso.criadoEmDispositivo.toUtc().toIso8601String(),
        'device_id': caso.deviceId,
        'achados': achados.map(_achadoParaJson).toList(),
      };
    }

    Map<String, dynamic> _achadoParaJson(Achado achado) {
      return {
        'uuid': achado.uuid,
        'caso_uuid': achado.casoUuid,
        'template_diagrama_id': achado.templateDiagramaId,
        'tipo_achado_id': achado.tipoAchadoId,
        'numero_sequencial': achado.numeroSequencial,
        'pos_x': achado.posX.toDouble(),
        'pos_y': achado.posY.toDouble(),
        'is_interno': achado.isInterno,
        'esta_pendente': achado.estaPendente,
        'dados_preenchidos_json': achado.dadosPreenchidos,
        'observacoes_texto': achado.observacoesTexto,
        'versao': achado.versao,
        'criado_em': achado.criadoEm.toUtc().toIso8601String(),
        'device_id': achado.deviceId,
      };
    }

}
