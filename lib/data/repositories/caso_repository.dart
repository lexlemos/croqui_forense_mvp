import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:croqui_forense_mvp/data/local/database_helper.dart';
import 'package:croqui_forense_mvp/data/models/caso_model.dart';
import 'package:croqui_forense_mvp/core/constants/database_constants.dart';
import 'package:croqui_forense_mvp/data/models/achado_model.dart';
import 'package:croqui_forense_mvp/data/models/evidencia_multimidia_model.dart';
import 'package:croqui_forense_mvp/data/models/parsed_sync_payload.dart';
import 'package:croqui_forense_mvp/data/models/balistica_model.dart';
import 'package:croqui_forense_mvp/data/models/exame_solicitado_model.dart';
import 'package:croqui_forense_mvp/data/models/exames/exame_solicitado_model.dart';
import 'package:croqui_forense_mvp/data/models/exames/detalhes_toxicologico_model.dart';
import 'package:croqui_forense_mvp/data/models/exames/amostra_genetica_model.dart';
import 'package:croqui_forense_mvp/data/models/exames/frasco_anatomo_model.dart';
import 'package:croqui_forense_mvp/core/utils/uuid_helper.dart';
import 'package:croqui_forense_mvp/domain/services/sync_service.dart';

/// Repositório central do domínio pericial responsável pela persistência atômica no banco SQLite criptografado (SQLCipher).
///
/// Implementa o contrato [ISyncRepository] para garantir que todas as transações
/// locais mantenham a integridade processual e a cadeia de custódia forense.
/// Suporta exclusão lógica (*tombstones*), isolamento pericial por usuário autenticado
/// e reconciliação bidirecional Offline-First com controle de concorrência otimista (OCC).
class CasoRepository implements ISyncRepository {
  final DatabaseHelper _dbHelper;

  CasoRepository(this._dbHelper);

  /// Instância ativa da conexão criptografada com o banco SQLite.
  @override
  Future<Database> get database async => _dbHelper.database;

  /// Insere ou atualiza um laudo pericial ([Caso]) no banco local em transação atômica.
  ///
  /// Estratégia de persistência local:
  /// - Marca `is_draft_synced = 0` para assegurar que a alteração seja capturada na próxima sincronização (push).
  /// - Persiste de forma atômica o registro mestre na tabela `casos` e as filhas em `balisticas` e `exames_solicitados`.
  ///
  /// Throws [Exception] em caso de falha de I/O ou violação de restrições de integridade no banco.
  Future<void> insertCase(Caso novoCaso) async {
    final db = await database;
    try {
      await db.transaction((txn) async {
        final map = novoCaso.toMap()..['is_draft_synced'] = 0;
        map.remove('balisticas');
        map.remove('exames');
        map.remove('exames_solicitados');
        final rowsAffected = await txn.update(
          tableCasos,
          map,
          where: 'uuid = ?',
          whereArgs: [novoCaso.uuid],
        );
        if (rowsAffected == 0) {
          await txn.insert(
            tableCasos,
            map,
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }

        await txn.delete(
          tableBalisticas,
          where: 'exame_id = ?',
          whereArgs: [novoCaso.uuid],
        );
        for (final b in novoCaso.balisticas) {
          final balisticaFinal =
              (b.exameId.isEmpty || b.exameId != novoCaso.uuid)
              ? b.copyWith(exameId: novoCaso.uuid)
              : b;
          await txn.insert(
            tableBalisticas,
            balisticaFinal.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await salvarExames(novoCaso.uuid, novoCaso.exames, executor: txn);
      });
    } catch (e) {
      throw Exception('Erro de persistência ao inserir caso: $e');
    }
  }

  /// Insere um novo laudo pericial acompanhado de seu lote inicial de evidências multimídia.
  ///
  /// Executa todas as inserções (`casos`, `balisticas`, `evidencias_multimidia`, `exames`)
  /// sob a mesma transação atômica SQLite, garantindo que o caso e seus anexos nasçam coesos.
  ///
  /// Throws [Exception] caso ocorra erro na execução transacional.
  Future<void> insertCaseComEvidenciasLote(
    Caso novoCaso,
    List<EvidenciaMultimidia> evidencias,
  ) async {
    final db = await database;
    try {
      await db.transaction((txn) async {
        final map = novoCaso.toMap()..['is_draft_synced'] = 0;
        map.remove('balisticas');
        map.remove('exames');
        map.remove('exames_solicitados');
        final rows = await txn.update(
          tableCasos,
          map,
          where: 'uuid = ?',
          whereArgs: [novoCaso.uuid],
        );
        if (rows == 0) {
          await txn.insert(
            tableCasos,
            map,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        await txn.delete(
          tableBalisticas,
          where: 'exame_id = ?',
          whereArgs: [novoCaso.uuid],
        );
        for (final b in novoCaso.balisticas) {
          await txn.insert(
            tableBalisticas,
            b.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        for (final ev in evidencias) {
          await txn.insert(
            tableEvidenciasMultimidia,
            ev.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await salvarExames(novoCaso.uuid, novoCaso.exames, executor: txn);
      });
    } catch (e) {
      throw Exception(
        'Erro de persistência atômica ao inserir caso e evidências em lote: $e',
      );
    }
  }

  /// Motor de reconciliação e upsert durante o ciclo de sincronização de entrada (*Pull Sync*).
  ///
  /// Aplica as regras de resolução de conflitos e integridade:
  /// - **Optimistic Concurrency Control (OCC):** Se houver rascunho local com alterações não enviadas
  ///   (`is_draft_synced == 0`) e o timestamp remoto for anterior ou igual ao local, a atualização
  ///   remota é rejeitada para proteger o trabalho do perito no tablet.
  /// - **Preservação de Atributos Locais Críticos:** Mantém caminhos físicos de PDFs locais (`pdf_local_path`),
  ///   o perito criador original e o timestamp de criação no dispositivo se ausentes no payload remoto.
  /// - **Blindagem de Status Processual:** Impede que um laudo já finalizado ou concluído localmente regrida para `EM_ANDAMENTO`.
  /// - **Preservação de Evidências Multimídia Locais:** Fotos tiradas no dispositivo que ainda não foram enviadas
  ///   (`foto_sincronizada == 0`) não são sobrescritas nem apagadas pelo pull.
  ///
  /// Throws [Exception] em caso de falha de atomicidade durante a transação de lote (*batch*).
  @override
  Future<void> upsertCasoTransaction(ParsedSyncPayload payload) async {
    final db = await database;
    try {
      await db.transaction((txn) async {
        final casoBackend = payload.caso;

        final localRow = await txn.query(
          tableCasos,
          where: 'uuid = ?',
          whereArgs: [casoBackend.uuid],
          limit: 1,
        );

        bool deveAtualizarCaso = true;

        if (localRow.isNotEmpty) {
          final int isDraftSynced =
              (localRow.first['is_draft_synced'] as int?) ?? 1;
          final localAtualizadoEmStr = localRow.first['atualizado_em']
              ?.toString();
          final localAtualizadoEm = localAtualizadoEmStr != null
              ? DateTime.tryParse(localAtualizadoEmStr)
              : null;
          final backendAtualizadoEm = casoBackend.atualizadoEm;

          // SÃ³ rejeita a versÃ£o remota se houver rascunho local PENDENTE de sincronizaÃ§Ã£o (is_draft_synced == 0)
          // e o dado remoto for temporalmente mais antigo que a alteraÃ§Ã£o local.
          if (isDraftSynced == 0 &&
              localAtualizadoEm != null &&
              backendAtualizadoEm != null) {
            if (!backendAtualizadoEm.isAfter(localAtualizadoEm)) {
              deveAtualizarCaso = false;
              debugPrint(
                '[CasoRepository] ALERTA OCC: Caso ${casoBackend.uuid} '
                'remoto ($backendAtualizadoEm) rejeitado a favor do rascunho local ($localAtualizadoEm).',
              );
            }
          }
        }

        final batch = txn.batch();

        if (deveAtualizarCaso) {
          final mapParaSalvar = casoBackend.toMap()..['is_draft_synced'] = 1;
          mapParaSalvar.remove('balisticas');
          mapParaSalvar.remove('exames');
          mapParaSalvar.remove('exames_solicitados');

          if (localRow.isEmpty) {
            batch.insert(
              tableCasos,
              mapParaSalvar,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          } else {
            final localMap = localRow.first;
            // Preserva id_usuario_criador se o payload remoto vier vazio
            final localCriador = localMap['id_usuario_criador']?.toString();
            if ((mapParaSalvar['id_usuario_criador'] == null ||
                    mapParaSalvar['id_usuario_criador'].toString().isEmpty) &&
                localCriador != null &&
                localCriador.isNotEmpty) {
              mapParaSalvar['id_usuario_criador'] = localCriador;
            }

            // Preserva pdf_local_path local se o backend vier sem
            final localPdfPath = localMap['pdf_local_path']?.toString();
            if ((mapParaSalvar['pdf_local_path'] == null ||
                    mapParaSalvar['pdf_local_path'].toString().isEmpty) &&
                localPdfPath != null &&
                localPdfPath.isNotEmpty) {
              mapParaSalvar['pdf_local_path'] = localPdfPath;
            }

            // Blindagem contra regressão de status: se já está finalizado ou sincronizado localmente,
            // não regride para NAO_INICIADO ou EM_ANDAMENTO
            final localStatus = (localMap['status']?.toString() ?? '')
                .toUpperCase();
            final backendStatus = (mapParaSalvar['status']?.toString() ?? '')
                .toUpperCase();
            if ((localStatus == 'FINALIZADO' ||
                    localStatus == 'SINCRONIZADO' ||
                    localStatus == 'CONCLUIDO') &&
                (backendStatus == 'NAO_INICIADO' ||
                    backendStatus == 'EM_ANDAMENTO' ||
                    backendStatus == 'RASCUNHO')) {
              mapParaSalvar['status'] = localStatus;
            }

            // Preserva finalizado_em se o backend vier sem
            final localFinalizadoEm = localMap['finalizado_em']?.toString();
            if (mapParaSalvar['finalizado_em'] == null &&
                localFinalizadoEm != null) {
              mapParaSalvar['finalizado_em'] = localFinalizadoEm;
            }

            // Preserva data de criação original no dispositivo
            final localCriadoEm = localMap['criado_em_dispositivo']?.toString();
            if (localCriadoEm != null && localCriadoEm.isNotEmpty) {
              mapParaSalvar['criado_em_dispositivo'] = localCriadoEm;
            }

            batch.update(
              tableCasos,
              mapParaSalvar,
              where: 'uuid = ?',
              whereArgs: [casoBackend.uuid],
            );
          }

          // Coleta todas as balÃ­sticas do caso (tanto de casoBackend quanto do rawJson)
          final List<BalisticaModel> todasBalisticas = [];
          todasBalisticas.addAll(casoBackend.balisticas);

          if (payload.rawJson['balisticas'] is List) {
            for (final rawB in (payload.rawJson['balisticas'] as List)) {
              if (rawB is! Map) continue;
              final bMap = Map<String, dynamic>.from(rawB);
              final bModel = BalisticaModel.fromMap(bMap);
              if (bModel.id.isNotEmpty &&
                  !todasBalisticas.any(
                    (b) =>
                        b.id.trim().toLowerCase() ==
                        bModel.id.trim().toLowerCase(),
                  )) {
                todasBalisticas.add(bModel);
              }
            }
          }

          batch.delete(
            tableBalisticas,
            where: 'exame_id = ?',
            whereArgs: [casoBackend.uuid],
          );
          for (final b in todasBalisticas) {
            final balisticaFinal =
                (b.exameId.isEmpty || b.exameId != casoBackend.uuid)
                ? b.copyWith(exameId: casoBackend.uuid)
                : b;
            batch.insert(
              tableBalisticas,
              balisticaFinal.toMap(),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }

          final Map<String, BalisticaModel> balisticasById = {};
          final Map<String, BalisticaModel> balisticasByAchadoUuid = {};
          final Map<String, BalisticaModel> balisticasByExameId = {};

          for (final b in todasBalisticas) {
            final bId = b.id.trim().toLowerCase();
            if (bId.isNotEmpty) {
              balisticasById[bId] = b;
            }
            if (b.achadoUuid != null && b.achadoUuid!.trim().isNotEmpty) {
              balisticasByAchadoUuid[b.achadoUuid!.trim().toLowerCase()] = b;
            }
            final bExameId = b.exameId.trim().toLowerCase();
            if (bExameId.isNotEmpty) {
              balisticasByExameId[bExameId] = b;
            }
          }

          if (payload.rawJson['balisticas'] is List) {
            for (final rawB in (payload.rawJson['balisticas'] as List)) {
              if (rawB is! Map) continue;
              final achadoId =
                  rawB['achado_uuid']?.toString() ??
                  rawB['achado_id']?.toString();
              final bId = (rawB['id']?.toString() ?? rawB['uuid']?.toString())
                  ?.trim()
                  .toLowerCase();
              if (achadoId != null &&
                  achadoId.trim().isNotEmpty &&
                  bId != null) {
                final bModel = balisticasById[bId];
                if (bModel != null) {
                  balisticasByAchadoUuid[achadoId.trim().toLowerCase()] =
                      bModel;
                }
              }
            }
          }

          for (final achado in payload.achados) {
            final detId = deterministicUuidV5(
              achado.uuid,
              'balistica',
            ).toLowerCase();
            final legacyDetId = deterministicUuidV4(
              achado.uuid,
              'balistica',
            ).toLowerCase();
            final achadoUuidLower = achado.uuid.trim().toLowerCase();

            // HeurÃ­stica de match:
            // 1. ID determinÃ­stico V5 (e fallback V4 legado)
            // 2. achado_uuid / achado_id vÃ­nculo
            // 3. exame_id == achado.uuid
            // 4. ID direto da balÃ­stica == achado.uuid
            BalisticaModel? matchedBalistica =
                (detId.isNotEmpty ? balisticasById[detId] : null) ??
                (legacyDetId.isNotEmpty ? balisticasById[legacyDetId] : null);
            matchedBalistica ??= balisticasByAchadoUuid[achadoUuidLower];
            matchedBalistica ??= balisticasByExameId[achadoUuidLower];
            matchedBalistica ??= balisticasById[achadoUuidLower];
            if (matchedBalistica == null) {
              for (final b in todasBalisticas) {
                final bId = b.id.trim().toLowerCase();
                final bAchado = b.achadoUuid?.trim().toLowerCase();
                final bExame = b.exameId.trim().toLowerCase();
                if ((detId.isNotEmpty && bId == detId) ||
                    (bAchado != null && bAchado == achadoUuidLower) ||
                    bExame == achadoUuidLower ||
                    bId == achadoUuidLower) {
                  matchedBalistica = b;
                  break;
                }
              }
            }

            final achadoParaSalvar = (matchedBalistica != null)
                ? achado.copyWith(
                    tipoFerimento:
                        matchedBalistica.tipoFerimento ?? achado.tipoFerimento,
                    tipoObjeto:
                        matchedBalistica.tipoObjeto ?? achado.tipoObjeto,
                    numeroLacre:
                        matchedBalistica.numeroLacre ?? achado.numeroLacre,
                    comentarioAdicional:
                        matchedBalistica.comentarioAdicional ??
                        achado.comentarioAdicional,
                  )
                : achado;

            batch.insert(
              tableAchados,
              achadoParaSalvar.toMap(),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }

          // Busca evidÃªncias locais existentes para o caso para preservar fotos pendentes
          final localEvidenciasRows = await txn.query(
            tableEvidenciasMultimidia,
            where: 'caso_uuid = ?',
            whereArgs: [casoBackend.uuid],
          );
          final Map<String, Map<String, dynamic>> localEvidenciasByUuid = {
            for (final r in localEvidenciasRows) r['uuid'].toString(): r,
          };
          final Map<String, Map<String, dynamic>> localEvidenciasByAchado = {
            for (final r in localEvidenciasRows)
              if (r['achado_uuid'] != null &&
                  r['achado_uuid'].toString().isNotEmpty)
                r['achado_uuid'].toString(): r,
          };

          for (final evidencia in payload.evidencias) {
            final evMap = Map<String, dynamic>.from(evidencia.toMap());

            final localRow =
                localEvidenciasByUuid[evidencia.uuid] ??
                (evidencia.achadoUuid != null
                    ? localEvidenciasByAchado[evidencia.achadoUuid]
                    : null);

            if (localRow != null) {
              final int localSincronizada =
                  (localRow['foto_sincronizada'] as int?) ?? 0;
              final String? localPath = localRow['caminho_arquivo_encriptado']
                  ?.toString();

              // Se a foto local existe e NÃƒO estÃ¡ sincronizada (foto_sincronizada == 0)
              if (localSincronizada == 0) {
                evMap['foto_sincronizada'] = 0;
                if (localRow['uuid'] != null) {
                  evMap['uuid'] = localRow['uuid'];
                }
                if (localPath != null &&
                    localPath.isNotEmpty &&
                    !localPath.startsWith('http://') &&
                    !localPath.startsWith('https://')) {
                  evMap['caminho_arquivo_encriptado'] = localPath;
                }
                debugPrint(
                  '[CasoRepository] ðŸ›¡ï¸ Preservando foto pendente local: '
                  'uuid=${evMap['uuid']} achado=${evMap['achado_uuid']} com foto_sincronizada = 0',
                );
              }
            }

            batch.insert(
              tableEvidenciasMultimidia,
              evMap,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }

        await batch.commit(noResult: true);

        if (deveAtualizarCaso) {
          await salvarExames(
            payload.caso.uuid,
            payload.caso.exames,
            executor: txn,
            isSyncPull: true,
          );
        }
      });
    } catch (e, stackTrace) {
      debugPrint(
        '[CasoRepository] âŒ Erro na transaÃ§Ã£o de upsertCasoTransaction (caso uuid: ${payload.caso.uuid}): $e\n$stackTrace',
      );
      throw Exception('Erro de persistÃªncia atÃ´mica no Upsert: $e');
    }
  }

  /// Atualiza os dados de um laudo pericial em edição local no banco SQLite.
  ///
  /// Aplica a regra de segurança jurídica: não permite atualização direta de registros
  /// com status `FINALIZADO` sem que haja o fluxo formal de reabertura.
  /// Marca `is_draft_synced = 0` para submissão no próximo ciclo de push sync.
  ///
  /// Throws [Exception] em caso de falha de persistência no SQLite.
  Future<void> updateCase(Caso caso) async {
    final db = await database;
    try {
      final map = caso.toMap()..['is_draft_synced'] = 0;
      map.remove('balisticas');
      map.remove('exames');
      map.remove('exames_solicitados');

      await db.transaction((txn) async {
        await txn.update(
          tableCasos,
          map,
          where: "uuid = ? AND UPPER(status) != 'FINALIZADO'",
          whereArgs: [caso.uuid],
        );

        await txn.delete(
          tableBalisticas,
          where: 'exame_id = ?',
          whereArgs: [caso.uuid],
        );
        for (final b in caso.balisticas) {
          final balisticaFinal = (b.exameId.isEmpty || b.exameId != caso.uuid)
              ? b.copyWith(exameId: caso.uuid)
              : b;
          await txn.insert(
            tableBalisticas,
            balisticaFinal.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await salvarExames(caso.uuid, caso.exames, executor: txn);
      });
    } catch (e) {
      throw Exception('Erro de persistência ao atualizar caso: $e');
    }
  }

  /// Reabre um laudo previamente finalizado, redefinindo seu status para `RASCUNHO`.
  ///
  /// Marca o caso como pendente de sincronização (`is_draft_synced = 0`), permitindo novas
  /// anotações periciais e emissão de retificação antes do fechamento definitivo.
  ///
  /// Throws [Exception] caso o comando de atualização falhe.
  Future<void> reabrirCaso(Caso caso) async {
    final db = await database;
    try {
      final map = caso.toMap()
        ..['is_draft_synced'] = 0
        ..['status'] = 'RASCUNHO';
      map.remove('balisticas');
      map.remove('exames');
      map.remove('exames_solicitados');

      await db.update(
        tableCasos,
        map,
        where: 'uuid = ?',
        whereArgs: [caso.uuid],
      );
    } catch (e) {
      throw Exception('Erro de persistência ao reabrir caso: $e');
    }
  }

  /// Recupera a lista de achados periciais associados a um laudo ([casoUuid]), enriquecendo-os com dados balísticos vinculados.
  @override
  Future<List<Achado>> getAchadosPorCaso(String casoUuid) async {
    final db = await database;
    final result = await db.query(
      tableAchados,
      where: 'caso_uuid = ? AND removido = 0',
      whereArgs: [casoUuid],
      orderBy: 'criado_em DESC',
    );
    final achados = result.map((map) => Achado.fromMap(map)).toList();

    final balisticasRows = await db.rawQuery(
      '''
      SELECT * FROM $tableBalisticas 
      WHERE exame_id = ? 
         OR exame_id IN (SELECT uuid FROM $tableAchados WHERE caso_uuid = ?)
      ''',
      [casoUuid, casoUuid],
    );

    if (balisticasRows.isEmpty) {
      return achados;
    }

    final Map<String, Map<String, dynamic>> balisticaById = {
      for (final r in balisticasRows)
        if (r['id'] != null) r['id'].toString().trim().toLowerCase(): r,
    };

    return achados.map((achado) {
      final hasBalistica =
          (achado.tipoFerimento != null && achado.tipoFerimento!.isNotEmpty) ||
          (achado.tipoObjeto != null && achado.tipoObjeto!.isNotEmpty) ||
          (achado.numeroLacre != null && achado.numeroLacre!.isNotEmpty) ||
          (achado.comentarioAdicional != null &&
              achado.comentarioAdicional!.isNotEmpty);

      if (hasBalistica) return achado;

      final detId = deterministicUuidV5(achado.uuid, 'balistica').toLowerCase();
      final legacyDetId = deterministicUuidV4(
        achado.uuid,
        'balistica',
      ).toLowerCase();
      final achadoUuidLower = achado.uuid.trim().toLowerCase();
      final bRow =
          (detId.isNotEmpty ? balisticaById[detId] : null) ??
          (legacyDetId.isNotEmpty ? balisticaById[legacyDetId] : null) ??
          balisticaById[achadoUuidLower] ??
          balisticasRows
              .where(
                (r) =>
                    r['exame_id']?.toString().trim().toLowerCase() ==
                    achadoUuidLower,
              )
              .firstOrNull;

      if (bRow != null) {
        return achado.copyWith(
          tipoFerimento:
              bRow['tipo_ferimento']?.toString() ?? achado.tipoFerimento,
          tipoObjeto: bRow['tipo_objeto']?.toString() ?? achado.tipoObjeto,
          numeroLacre: bRow['numero_lacre']?.toString() ?? achado.numeroLacre,
          comentarioAdicional:
              bRow['comentario_adicional']?.toString() ??
              achado.comentarioAdicional,
        );
      }
      return achado;
    }).toList();
  }

  /// Recupera em lote os achados de múltiplos laudos ([casoUuids]) agrupados por identificador do caso.
  @override
  Future<Map<String, List<Achado>>> getAchadosEmLote(
    List<String> casoUuids,
  ) async {
    if (casoUuids.isEmpty) return {};
    final db = await database;
    final placeholders = List.filled(casoUuids.length, '?').join(',');
    final result = await db.query(
      tableAchados,
      where: 'caso_uuid IN ($placeholders) AND removido = 0',
      whereArgs: casoUuids,
      orderBy: 'criado_em DESC',
    );

    final balisticasRows = await db.rawQuery(
      '''
      SELECT * FROM $tableBalisticas 
      WHERE exame_id IN ($placeholders)
         OR exame_id IN (SELECT uuid FROM $tableAchados WHERE caso_uuid IN ($placeholders))
      ''',
      [...casoUuids, ...casoUuids],
    );

    final Map<String, Map<String, dynamic>> balisticaById = {
      for (final r in balisticasRows)
        if (r['id'] != null) r['id'].toString().trim().toLowerCase(): r,
    };

    final Map<String, List<Achado>> grouped = {};
    for (final map in result) {
      var achado = Achado.fromMap(map);

      final hasBalistica =
          (achado.tipoFerimento != null && achado.tipoFerimento!.isNotEmpty) ||
          (achado.tipoObjeto != null && achado.tipoObjeto!.isNotEmpty) ||
          (achado.numeroLacre != null && achado.numeroLacre!.isNotEmpty) ||
          (achado.comentarioAdicional != null &&
              achado.comentarioAdicional!.isNotEmpty);

      if (!hasBalistica && balisticasRows.isNotEmpty) {
        final detId = deterministicUuidV5(
          achado.uuid,
          'balistica',
        ).toLowerCase();
        final legacyDetId = deterministicUuidV4(
          achado.uuid,
          'balistica',
        ).toLowerCase();
        final achadoUuidLower = achado.uuid.trim().toLowerCase();
        final bRow =
            (detId.isNotEmpty ? balisticaById[detId] : null) ??
            (legacyDetId.isNotEmpty ? balisticaById[legacyDetId] : null) ??
            balisticaById[achadoUuidLower] ??
            balisticasRows
                .where(
                  (r) =>
                      r['exame_id']?.toString().trim().toLowerCase() ==
                      achadoUuidLower,
                )
                .firstOrNull;

        if (bRow != null) {
          achado = achado.copyWith(
            tipoFerimento:
                bRow['tipo_ferimento']?.toString() ?? achado.tipoFerimento,
            tipoObjeto: bRow['tipo_objeto']?.toString() ?? achado.tipoObjeto,
            numeroLacre: bRow['numero_lacre']?.toString() ?? achado.numeroLacre,
            comentarioAdicional:
                bRow['comentario_adicional']?.toString() ??
                achado.comentarioAdicional,
          );
        }
      }

      (grouped[achado.casoUuid] ??= []).add(achado);
    }
    return grouped;
  }

  /// Retorna todos os laudos cadastrados no dispositivo vinculados ao perito ([usuarioId]), hidratando balísticas, exames e evidências.
  Future<List<Caso>> getAllCases(String usuarioId) async {
    if (usuarioId.isEmpty) return [];
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableCasos,
      where:
          '(id_usuario_criador = ? OR id_usuario_criador IS NULL OR id_usuario_criador = "") AND removido = 0',
      whereArgs: [usuarioId],
      orderBy: 'atualizado_em DESC, criado_em_dispositivo DESC',
    );

    final List<Caso> casos = [];
    for (final map in maps) {
      final mutableMap = Map<String, dynamic>.from(map);
      final uuidStr = mutableMap['uuid'].toString();
      final balisticas = await db.query(
        tableBalisticas,
        where: 'exame_id = ?',
        whereArgs: [uuidStr],
      );
      mutableMap['balisticas'] = balisticas;
      final exames = await getExamesPorCaso(uuidStr);
      mutableMap['exames'] = exames.map((e) => e.toMap()).toList();
      final evidencias = await getEvidenciasPorCaso(uuidStr);
      mutableMap['evidencias_multimidia'] = evidencias
          .map((e) => e.toMap())
          .toList();
      casos.add(Caso.fromMap(mutableMap));
    }
    return casos;
  }

  /// Localiza um laudo pelo seu [uuid], hidratando completamente suas estruturas dependentes.
  Future<Caso?> getCaseByUuid(String uuid) async {
    final db = await database;
    final maps = await db.query(
      tableCasos,
      where: 'uuid = ? AND removido = 0',
      whereArgs: [uuid],
      limit: 1,
    );
    if (maps.isEmpty) return null;

    final mutableMap = Map<String, dynamic>.from(maps.first);
    final balisticas = await db.query(
      tableBalisticas,
      where: 'exame_id = ?',
      whereArgs: [uuid],
    );
    mutableMap['balisticas'] = balisticas;
    final exames = await getExamesPorCaso(uuid);
    mutableMap['exames'] = exames.map((e) => e.toMap()).toList();
    final evidencias = await getEvidenciasPorCaso(uuid);
    mutableMap['evidencias_multimidia'] = evidencias
        .map((e) => e.toMap())
        .toList();

    return Caso.fromMap(mutableMap);
  }

  /// Consulta todos os laudos que possuem alterações pendentes de sincronização (`is_draft_synced == 0`).
  @override
  Future<List<Caso>> getCasosPendentesSync(String usuarioId) async {
    if (usuarioId.isEmpty) return [];
    final db = await database;
    final maps = await db.query(
      tableCasos,
      where:
          "(id_usuario_criador = ? OR id_usuario_criador IS NULL OR id_usuario_criador = '') AND UPPER(status) IN ('EM_ANDAMENTO', 'EMANDAMENTO', 'NAO_INICIADO', 'RASCUNHO', 'LAUDO_PENDENTE', 'LAUDOPENDENTE', 'FINALIZADO', 'CONCLUIDO') AND (is_draft_synced IS NULL OR is_draft_synced = 0) AND removido = 0",
      whereArgs: [usuarioId],
      orderBy: 'criado_em_dispositivo ASC',
    );

    final List<Caso> casos = [];
    for (final map in maps) {
      final mutableMap = Map<String, dynamic>.from(map);
      final uuidStr = mutableMap['uuid'].toString();
      final balisticas = await db.query(
        tableBalisticas,
        where: 'exame_id = ?',
        whereArgs: [uuidStr],
      );
      mutableMap['balisticas'] = balisticas;
      final exames = await getExamesPorCaso(uuidStr);
      mutableMap['exames'] = exames.map((e) => e.toMap()).toList();
      final evidencias = await getEvidenciasPorCaso(uuidStr);
      mutableMap['evidencias_multimidia'] = evidencias
          .map((e) => e.toMap())
          .toList();
      casos.add(Caso.fromMap(mutableMap));
    }
    return casos;
  }

  /// Consulta laudos finalizados que ainda não foram sincronizados com o servidor central.
  @override
  Future<List<Caso>> getCasosNaoSincronizados(String usuarioId) async {
    if (usuarioId.isEmpty) return [];
    final db = await database;
    final maps = await db.query(
      tableCasos,
      where:
          "(id_usuario_criador = ? OR id_usuario_criador IS NULL OR id_usuario_criador = '') AND UPPER(status) IN ('FINALIZADO', 'CONCLUIDO') AND (is_draft_synced IS NULL OR is_draft_synced = 0) AND removido = 0",
      whereArgs: [usuarioId],
      orderBy: 'criado_em_dispositivo ASC',
    );

    final List<Caso> casos = [];
    for (final map in maps) {
      final mutableMap = Map<String, dynamic>.from(map);
      final uuidStr = mutableMap['uuid'].toString();
      final balisticas = await db.query(
        tableBalisticas,
        where: 'exame_id = ?',
        whereArgs: [uuidStr],
      );
      mutableMap['balisticas'] = balisticas;
      final exames = await getExamesPorCaso(uuidStr);
      mutableMap['exames'] = exames.map((e) => e.toMap()).toList();
      final evidencias = await getEvidenciasPorCaso(uuidStr);
      mutableMap['evidencias_multimidia'] = evidencias
          .map((e) => e.toMap())
          .toList();
      casos.add(Caso.fromMap(mutableMap));
    }
    return casos;
  }

  /// Consulta rascunhos em aberto com alterações pendentes de sincronização (`is_draft_synced == 0`).
  @override
  Future<List<Caso>> getRascunhosNaoSincronizados(String usuarioId) async {
    if (usuarioId.isEmpty) return [];
    final db = await database;
    final maps = await db.query(
      tableCasos,
      where:
          "(id_usuario_criador = ? OR id_usuario_criador IS NULL OR id_usuario_criador = '') AND UPPER(status) IN ('EM_ANDAMENTO', 'EMANDAMENTO', 'NAO_INICIADO', 'RASCUNHO', 'LAUDO_PENDENTE', 'LAUDOPENDENTE') AND (is_draft_synced IS NULL OR is_draft_synced = 0) AND removido = 0",
      whereArgs: [usuarioId],
      orderBy: 'criado_em_dispositivo ASC',
    );

    final List<Caso> casos = [];
    for (final map in maps) {
      final mutableMap = Map<String, dynamic>.from(map);
      final uuidStr = mutableMap['uuid'].toString();
      final balisticas = await db.query(
        tableBalisticas,
        where: 'exame_id = ?',
        whereArgs: [uuidStr],
      );
      mutableMap['balisticas'] = balisticas;
      final exames = await getExamesPorCaso(uuidStr);
      mutableMap['exames'] = exames.map((e) => e.toMap()).toList();
      final evidencias = await getEvidenciasPorCaso(uuidStr);
      mutableMap['evidencias_multimidia'] = evidencias
          .map((e) => e.toMap())
          .toList();
      casos.add(Caso.fromMap(mutableMap));
    }
    return casos;
  }

  /// Recupera em lote os achados que possuem arquivos de fotos pendentes de envio (`foto_sincronizada == 0`).
  @override
  Future<Map<String, List<Achado>>> getAchadosComFotosPendentesEmLote(
    List<String> casoUuids,
  ) async {
    if (casoUuids.isEmpty) return {};

    final Map<String, List<Achado>> grouped = {};
    for (final uuid in casoUuids) {
      grouped[uuid] = [];
    }

    final db = await database;
    final placeholders = List.filled(casoUuids.length, '?').join(',');

    try {
      final List<Map<String, dynamic>> generalEvidences = await db.query(
        tableEvidenciasMultimidia,
        where:
            'caso_uuid IN ($placeholders) AND tipo = ? AND foto_sincronizada = 0 AND removido = 0',
        whereArgs: [...casoUuids, 'GERAL'],
      );

      for (final row in generalEvidences) {
        final String caseUuid = row['caso_uuid'].toString();
        final String pathString =
            row['caminho_arquivo_encriptado']?.toString() ?? '';
        if (pathString.isEmpty) continue;

        final achadoVirtual = Achado(
          uuid: row['uuid'].toString(),
          casoUuid: caseUuid,
          diagramaCasoUuid: '',
          diagramaNome: 'GERAL',
          tipoAchadoId: 'FOTO_GERAL',
          numeroSequencial: 0,
          posX: 0.0,
          posY: 0.0,
          isInterno: false,
          versao: 1,
          removido: false,
          criadoEm:
              DateTime.tryParse(row['criado_em']?.toString() ?? '') ??
              DateTime.now(),
          dadosPreenchidos: {
            'photo_path': pathString,
            '_evidencia_uuid': row['uuid'].toString(),
          },
          tamanho: '',
          vistaAnatomica: '',
          localAnatomico: '',
        );
        (grouped[caseUuid] ??= []).add(achadoVirtual);
      }
    } catch (e) {
      debugPrint(
        '[CasoRepository] ❌ getAchadosComFotosPendentesEmLote (GERAL): $e',
      );
    }

    try {
      final sqlAchados =
          '''
        SELECT
          a.*,
          e.caminho_arquivo_encriptado AS _photo_path_override,
          e.uuid                        AS _evidencia_uuid
        FROM $tableAchados a
        INNER JOIN $tableEvidenciasMultimidia e
               ON  e.achado_uuid                = a.uuid
               AND e.removido                   = 0
               AND e.caminho_arquivo_encriptado IS NOT NULL
               AND e.caminho_arquivo_encriptado != ''
               AND e.foto_sincronizada          = 0
        WHERE a.caso_uuid IN ($placeholders)
          AND a.removido  = 0
        ORDER BY a.criado_em ASC
      ''';

      final rowsAchados = await db.rawQuery(sqlAchados, casoUuids);

      for (final row in rowsAchados) {
        final casoUuid = row['caso_uuid'].toString();
        final mutableRow = Map<String, dynamic>.from(row);
        final dadosJson =
            mutableRow['dados_preenchidos_json'] as String? ?? '{}';
        final dados = _decodeJson(dadosJson);

        dados['photo_path'] = row['_photo_path_override'] as String?;
        dados['_evidencia_uuid'] = row['_evidencia_uuid'] as String?;

        mutableRow['dados_preenchidos_json'] = _encodeJson(dados);
        mutableRow.remove('_photo_path_override');
        mutableRow.remove('_evidencia_uuid');

        (grouped[casoUuid] ??= []).add(Achado.fromMap(mutableRow));
      }
    } catch (e) {
      debugPrint(
        '[CasoRepository] ❌ getAchadosComFotosPendentesEmLote (SQL): $e',
      );
    }

    return grouped;
  }

  /// Consulta os metadados e caminhos locais de evidências multimídia não sincronizadas para um laudo específico.
  @override
  Future<List<Map<String, dynamic>>> getEvidenciasPendentesPorCaso(
    String casoUuid,
  ) async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> rows = await db.rawQuery(
        '''
        SELECT 
          e.uuid AS evidencia_uuid,
          COALESCE(e.caso_uuid, a.caso_uuid) AS caso_uuid,
          e.caminho_arquivo_encriptado,
          e.hash_arquivo,
          e.achado_uuid
        FROM $tableEvidenciasMultimidia e
        LEFT JOIN $tableAchados a ON e.achado_uuid = a.uuid
        WHERE (e.caso_uuid = ? OR a.caso_uuid = ?)
          AND e.removido = 0
          AND e.caminho_arquivo_encriptado IS NOT NULL
          AND e.caminho_arquivo_encriptado != ''
          AND e.foto_sincronizada = 0
        ''',
        [casoUuid, casoUuid],
      );
      return rows;
    } catch (e) {
      debugPrint('[CasoRepository] ❌ getEvidenciasPendentesPorCaso: $e');
      return [];
    }
  }

  /// Consulta global de todas as evidências multimídia pendentes de envio em todos os laudos do dispositivo.
  @override
  Future<List<Map<String, dynamic>>>
  getTodasEvidenciasPendentesGlobais() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT 
        e.uuid AS evidencia_uuid,
        e.caso_uuid AS caso_uuid_fallback,
        e.caminho_arquivo_encriptado,
        e.hash_arquivo,
        a.uuid AS achado_uuid,
        a.caso_uuid AS caso_uuid_achado
      FROM evidencias_multimidia e
      LEFT JOIN achados a ON e.achado_uuid = a.uuid
      WHERE e.removido = 0
        AND e.caminho_arquivo_encriptado IS NOT NULL
        AND e.caminho_arquivo_encriptado != ''
        AND e.foto_sincronizada = 0
    ''');
    return maps;
  }

  /// Marca o laudo como totalmente reconciliado com o backend (`is_draft_synced = 1`, `sync_error = 0`).
  @override
  Future<void> marcarCasoComoSincronizado(Caso caso) async {
    final db = await database;
    await db.rawUpdate(
      '''
      UPDATE $tableCasos
         SET is_draft_synced = 1,
             sync_error      = 0,
             atualizado_em   = ?
       WHERE uuid     = ?
         AND removido = 0
      ''',
      [DateTime.now().toIso8601String(), caso.uuid],
    );
  }

  /// Marca o rascunho de laudo como sincronizado com o backend.
  @override
  Future<void> marcarRascunhoComoSincronizado(String casoUuid) async {
    final db = await database;
    await db.rawUpdate(
      '''
      UPDATE $tableCasos
         SET is_draft_synced = 1,
             sync_error      = 0,
             atualizado_em   = ?
       WHERE uuid     = ?
         AND removido = 0
      ''',
      [DateTime.now().toIso8601String(), casoUuid],
    );
  }

  /// Registra que o laudo enfrentou erro ou conflito intransponível no ciclo de push sync (`sync_error = 1`).
  @override
  Future<void> marcarCasoComErroDeSincronizacao(String casoUuid) async {
    final db = await database;
    await db.rawUpdate(
      '''
      UPDATE $tableCasos
         SET sync_error      = 1,
             is_draft_synced = 0,
             atualizado_em   = ?
       WHERE uuid     = ?
         AND removido = 0
      ''',
      [DateTime.now().toIso8601String(), casoUuid],
    );
  }

  /// Marca a evidência multimídia vinculada ao achado como sincronizada no backend.
  @override
  Future<void> marcarFotoComoSincronizada(Achado achado) async {
    final evidenciaUuid = achado.dadosPreenchidos['_evidencia_uuid'];
    if (evidenciaUuid != null) {
      await marcarEvidenciaComoSincronizada(evidenciaUuid.toString());
    }
  }

  /// Define `foto_sincronizada = 1` para a evidência multimídia correspondente ao [uuid].
  @override
  Future<void> marcarEvidenciaComoSincronizada(String uuid) async {
    final db = await database;
    await db.update(
      tableEvidenciasMultimidia,
      {'foto_sincronizada': 1},
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  /// Atualiza o link remoto do laudo em PDF após geração no servidor central.
  @override
  Future<void> atualizarPdfUrl(String casoUuid, String pdfUrl) async {
    final db = await database;
    await db.rawUpdate(
      '''
      UPDATE $tableCasos
         SET pdf_url       = ?,
             atualizado_em = ?
       WHERE uuid     = ?
         AND removido = 0
      ''',
      [pdfUrl, DateTime.now().toIso8601String(), casoUuid],
    );
  }

  /// Busca uma evidência multimídia pelo seu [uuid].
  Future<EvidenciaMultimidia?> getEvidenciaByUuid(String uuid) async {
    final db = await database;
    final maps = await db.query(
      tableEvidenciasMultimidia,
      where: 'uuid = ? AND removido = 0',
      whereArgs: [uuid],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return EvidenciaMultimidia.fromMap(maps.first);
  }

  /// Recupera todas as evidências multimídia de contexto geral (fotografias gerais do corpo) de um caso.
  Future<List<EvidenciaMultimidia>> getEvidenciasGerais(String casoUuid) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableEvidenciasMultimidia,
      where: 'caso_uuid = ? AND tipo = ? AND removido = 0',
      whereArgs: [casoUuid, 'GERAL'],
    );
    return maps.map((m) => EvidenciaMultimidia.fromMap(m)).toList();
  }

  /// Recupera todas as evidências multimídia associadas a um caso (tanto gerais quanto de achados).
  Future<List<EvidenciaMultimidia>> getEvidenciasPorCaso(
    String casoUuid,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableEvidenciasMultimidia,
      where: 'caso_uuid = ? AND removido = 0',
      whereArgs: [casoUuid],
    );
    return maps.map((m) => EvidenciaMultimidia.fromMap(m)).toList();
  }

  /// Insere uma evidência multimídia geral e marca o laudo pai como pendente de sincronização (`is_draft_synced = 0`).
  Future<void> insertEvidenciaGeral(EvidenciaMultimidia evidencia) async {
    final db = await database;
    await db.insert(
      tableEvidenciasMultimidia,
      evidencia.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _marcarCasoPendenteSync(db, evidencia.casoUuid);
  }
  Future<void> deleteEvidenciaGeral(String uuid) async {
    final db = await database;
    final ev = await getEvidenciaByUuid(uuid);
    await db.update(
      tableEvidenciasMultimidia,
      {'removido': 1},
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
    if (ev != null) {
      await _marcarCasoPendenteSync(db, ev.casoUuid);
    }
  }

  /// Auxiliar interno para remarcar o laudo como pendente de sincronização (`is_draft_synced = 0`) e atualizar seu timestamp.
  Future<void> _marcarCasoPendenteSync(
    DatabaseExecutor db,
    String casoUuid,
  ) async {
    await db.rawUpdate(
      '''
      UPDATE $tableCasos
         SET is_draft_synced = 0,
             atualizado_em   = ?
       WHERE uuid     = ?
         AND removido = 0
      ''',
      [DateTime.now().toIso8601String(), casoUuid],
    );
  }

  /// Consulta simplificada de exames solicitados associados ao [casoUuid].
  Future<List<ExameSolicitado>> getExamesSolicitados(String casoUuid) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'exames_solicitados',
      where: 'caso_uuid = ?',
      whereArgs: [casoUuid],
    );
    return maps.map((m) => ExameSolicitado.fromMap(m)).toList();
  }

  /// Salva ou atualiza lacres de exames complementares de forma transacional.
  Future<void> salvarExamesSolicitados({
    required String casoUuid,
    required String? anatomoLacre,
    required String? toxicologicoLacre,
    required String? geneticaLacre,
    required String? outrosLacre,
  }) async {
    final db = await database;
    final map = {
      'ANATOMO': anatomoLacre,
      'TOXICOLOGICO': toxicologicoLacre,
      'GENETICA': geneticaLacre,
      'OUTROS': outrosLacre,
    };

    await db.transaction((txn) async {
      for (final entry in map.entries) {
        final tipo = entry.key;
        final lacre = entry.value;

        if (lacre == null || lacre.trim().isEmpty) {
          await txn.delete(
            'exames_solicitados',
            where: 'caso_uuid = ? AND tipo_exame = ?',
            whereArgs: [casoUuid, tipo],
          );
        } else {
          final existing = await txn.query(
            'exames_solicitados',
            where: 'caso_uuid = ? AND tipo_exame = ?',
            whereArgs: [casoUuid, tipo],
          );

          if (existing.isEmpty) {
            final novo = ExameSolicitado.novo(
              casoUuid: casoUuid,
              tipoExame: tipo,
              numeroLacre: lacre,
            );
            await txn.insert('exames_solicitados', novo.toMap());
          } else {
            await txn.update(
              'exames_solicitados',
              {'numero_lacre': lacre},
              where: 'caso_uuid = ? AND tipo_exame = ?',
              whereArgs: [casoUuid, tipo],
            );
          }
        }
      }
    });
  }

  Map<String, dynamic> _decodeJson(String raw) {
    try {
      return Map<String, dynamic>.from((jsonDecode(raw) as Map?) ?? {});
    } catch (_) {
      return {};
    }
  }

  String _encodeJson(Map<String, dynamic> map) => jsonEncode(map);

  /// Persiste a lista completa de exames solicitados e suas filhas polimórficas (toxicologia, genética, anatomopatologia) de forma atômica.
  ///
  /// Parâmetros:
  /// - [executor]: Permite executar dentro de uma transação externa (`txn`), garantindo atomicidade estrita.
  /// - [isSyncPull]: Se `true`, não remarca o laudo como pendente de sync (usado durante a ingestão do pull).
  Future<void> salvarExames(
    String casoUuid,
    List<ExameSolicitadoModel> exames, {
    DatabaseExecutor? executor,
    bool isSyncPull = false,
  }) async {
    Future<void> executarOperacoes(DatabaseExecutor targetDb) async {
      final batch = targetDb.batch();

      const subQueryExames =
          '(SELECT uuid FROM exames_solicitados WHERE caso_uuid = ?)';
      batch.delete(
        'detalhes_toxicologico',
        where: 'exame_uuid IN $subQueryExames',
        whereArgs: [casoUuid],
      );
      batch.delete(
        'amostras_genetica',
        where: 'exame_uuid IN $subQueryExames',
        whereArgs: [casoUuid],
      );
      batch.delete(
        'frascos_anatomo',
        where: 'exame_uuid IN $subQueryExames',
        whereArgs: [casoUuid],
      );
      batch.delete(
        'exames_solicitados',
        where: 'caso_uuid = ?',
        whereArgs: [casoUuid],
      );

      for (final exame in exames) {
        final mapExame = exame.toMap();
        mapExame.remove('detalhes');
        mapExame.remove('amostras_genetica');
        mapExame.remove('frascos_anatomo');
        mapExame.remove('detalhes_toxicologico');
        mapExame.remove('quantidade_amostras');
        mapExame.remove('debug_unmatched_detalhes');
        mapExame.remove('debug_tipo_recebido');
        mapExame['caso_uuid'] = casoUuid;
        batch.insert('exames_solicitados', mapExame);

        final detalhes = exame.detalhes;
        if (detalhes == null) continue;

        final tipo = exame.tipoExame.toUpperCase().trim();

        if (tipo == 'TOXICOLOGICO') {
          if (detalhes is DetalhesToxicologicoModel) {
            batch.insert(
              'detalhes_toxicologico',
              detalhes.copyWith(exameUuid: exame.uuid).toMap(),
            );
          } else if (detalhes is Map<String, dynamic>) {
            final map = Map<String, dynamic>.from(detalhes)
              ..['exame_uuid'] = exame.uuid;
            batch.insert('detalhes_toxicologico', map);
          }
        } else if (tipo == 'GENETICA') {
          final lista = detalhes is List ? detalhes : [detalhes];
          for (final item in lista) {
            if (item is AmostraGeneticaModel) {
              batch.insert(
                'amostras_genetica',
                item.copyWith(exameUuid: exame.uuid).toMap(),
              );
            } else if (item is Map<String, dynamic>) {
              final map = Map<String, dynamic>.from(item)
                ..['exame_uuid'] = exame.uuid;
              batch.insert('amostras_genetica', map);
            }
          }
        } else if (tipo == 'ANATOMO') {
          final lista = detalhes is List ? detalhes : [detalhes];
          for (final item in lista) {
            if (item is FrascoAnatomoModel) {
              batch.insert(
                'frascos_anatomo',
                item.copyWith(exameUuid: exame.uuid).toMap(),
              );
            } else if (item is Map<String, dynamic>) {
              final map = Map<String, dynamic>.from(item)
                ..['exame_uuid'] = exame.uuid;
              batch.insert('frascos_anatomo', map);
            }
          }
        }
      }

      if (!isSyncPull) {
        await _marcarCasoPendenteSync(targetDb, casoUuid);
      }

      await batch.commit(noResult: true);
    }

    if (executor != null) {
      await executarOperacoes(executor);
    } else {
      final dbInst = await database;
      await dbInst.transaction((txn) async => executarOperacoes(txn));
    }
  }

  /// Recupera todos os exames solicitados e suas tabelas filhas polimórficas para um laudo específico.
  ///
  /// Utiliza `UNION ALL` otimizado para hidratação de toxicologia, genética e frascos anatômicos em consulta consolidada.
  Future<List<ExameSolicitadoModel>> getExamesPorCaso(String casoUuid) async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> examesMaps = await db.query(
        'exames_solicitados',
        where: 'caso_uuid = ?',
        whereArgs: [casoUuid],
        orderBy: 'criado_em ASC',
      );

      if (examesMaps.isEmpty) return [];

      final exameUuids = examesMaps
          .map((map) => map['uuid']?.toString())
          .whereType<String>()
          .where((uuid) => uuid.isNotEmpty)
          .toSet()
          .toList();
      final detalhesQueries = <String>[];
      final detalhesArgs = <Object>[];

      final tiposPorUuid = <String, String>{
        for (final map in examesMaps)
          map['uuid']!.toString(): (map['tipo_exame']?.toString() ?? '')
              .toUpperCase()
              .trim(),
      };
      final toxicUuids = exameUuids
          .where((uuid) => tiposPorUuid[uuid] == 'TOXICOLOGICO')
          .toList();
      final geneticaUuids = exameUuids
          .where((uuid) => tiposPorUuid[uuid] == 'GENETICA')
          .toList();
      final anatomoUuids = exameUuids
          .where((uuid) => tiposPorUuid[uuid] == 'ANATOMO')
          .toList();

      String placeholdersFor(List<String> uuids) =>
          List.filled(uuids.length, '?').join(', ');

      if (toxicUuids.isNotEmpty) {
        detalhesQueries.add('''
          SELECT
            'TOXICOLOGICO' AS detalhe_tipo,
            uuid, exame_uuid,
            historico_ocorrencia, historico_outro,
            material_sg_femoral, material_sg_cardiaca, material_sg_outro,
            numero_lacre_sg, material_urina, numero_lacre_ur,
            material_humor_vitreo, numero_lacre_hv,
            material_estomago, numero_lacre_ce,
            material_pulmao, numero_lacre_pm, quantificacao_drogas,
            NULL AS tipo_amostra, NULL AS descricao_outro,
            NULL AS pesquisa_semen, NULL AS pesquisa_dna,
            NULL AS quantidade_swabs, NULL AS numero_lacre,
            NULL AS numero_frasco, NULL AS coracao, NULL AS figado,
            NULL AS baco, NULL AS encefalo,
            NULL AS pulmao_d_lsd, NULL AS pulmao_d_lmd, NULL AS pulmao_d_lid,
            NULL AS pulmao_e_lse, NULL AS pulmao_e_lie,
            NULL AS rim_d, NULL AS rim_e,
            NULL AS pele_regiao, NULL AS partes_moles_regiao,
            NULL AS outras_regiao
          FROM detalhes_toxicologico
          WHERE exame_uuid IN (${placeholdersFor(toxicUuids)})
        ''');
        detalhesArgs.addAll(toxicUuids);
      }

      if (geneticaUuids.isNotEmpty) {
        detalhesQueries.add('''
          SELECT
            'GENETICA' AS detalhe_tipo,
            uuid, exame_uuid,
            NULL AS historico_ocorrencia, NULL AS historico_outro,
            NULL AS material_sg_femoral, NULL AS material_sg_cardiaca,
            NULL AS material_sg_outro, NULL AS numero_lacre_sg,
            NULL AS material_urina, NULL AS numero_lacre_ur,
            NULL AS material_humor_vitreo, NULL AS numero_lacre_hv,
            NULL AS material_estomago, NULL AS numero_lacre_ce,
            NULL AS material_pulmao, NULL AS numero_lacre_pm,
            NULL AS quantificacao_drogas,
            tipo_amostra, descricao_outro, pesquisa_semen, pesquisa_dna,
            quantidade_swabs, numero_lacre,
            NULL AS numero_frasco, NULL AS coracao, NULL AS figado,
            NULL AS baco, NULL AS encefalo,
            NULL AS pulmao_d_lsd, NULL AS pulmao_d_lmd, NULL AS pulmao_d_lid,
            NULL AS pulmao_e_lse, NULL AS pulmao_e_lie,
            NULL AS rim_d, NULL AS rim_e,
            NULL AS pele_regiao, NULL AS partes_moles_regiao,
            NULL AS outras_regiao
          FROM amostras_genetica
          WHERE exame_uuid IN (${placeholdersFor(geneticaUuids)})
        ''');
        detalhesArgs.addAll(geneticaUuids);
      }

      if (anatomoUuids.isNotEmpty) {
        detalhesQueries.add('''
          SELECT
            'ANATOMO' AS detalhe_tipo,
            uuid, exame_uuid,
            NULL AS historico_ocorrencia, NULL AS historico_outro,
            NULL AS material_sg_femoral, NULL AS material_sg_cardiaca,
            NULL AS material_sg_outro, NULL AS numero_lacre_sg,
            NULL AS material_urina, NULL AS numero_lacre_ur,
            NULL AS material_humor_vitreo, NULL AS numero_lacre_hv,
            NULL AS material_estomago, NULL AS numero_lacre_ce,
            NULL AS material_pulmao, NULL AS numero_lacre_pm,
            NULL AS quantificacao_drogas,
            NULL AS tipo_amostra, NULL AS descricao_outro,
            NULL AS pesquisa_semen, NULL AS pesquisa_dna,
            NULL AS quantidade_swabs, numero_lacre,
            numero_frasco, coracao, figado, baco, encefalo,
            pulmao_d_lsd, pulmao_d_lmd, pulmao_d_lid,
            pulmao_e_lse, pulmao_e_lie, rim_d, rim_e,
            pele_regiao, partes_moles_regiao, outras_regiao
          FROM frascos_anatomo
          WHERE exame_uuid IN (${placeholdersFor(anatomoUuids)})
        ''');
        detalhesArgs.addAll(anatomoUuids);
      }

      final detalhesRows = detalhesQueries.isEmpty
          ? <Map<String, dynamic>>[]
          : await db.rawQuery(
              detalhesQueries.join(' UNION ALL '),
              detalhesArgs,
            );

      final toxicByExame = <String, Map<String, dynamic>>{};
      final geneticaByExame = <String, List<Map<String, dynamic>>>{};
      final anatomoByExame = <String, List<Map<String, dynamic>>>{};

      for (final row in detalhesRows) {
        final exameUuid = row['exame_uuid']?.toString() ?? '';
        switch (row['detalhe_tipo']) {
          case 'TOXICOLOGICO':
            toxicByExame.putIfAbsent(exameUuid, () => row);
            break;
          case 'GENETICA':
            geneticaByExame.putIfAbsent(exameUuid, () => []).add(row);
            break;
          case 'ANATOMO':
            anatomoByExame.putIfAbsent(exameUuid, () => []).add(row);
            break;
        }
      }

      return examesMaps.map((mapMestre) {
        final exameUuid = mapMestre['uuid']?.toString() ?? '';
        final tipo = tiposPorUuid[exameUuid] ?? '';
        dynamic detalhesObj;

        if (tipo == 'TOXICOLOGICO') {
          final detalhe = toxicByExame[exameUuid];
          if (detalhe != null) {
            detalhesObj = DetalhesToxicologicoModel.fromMap(detalhe);
          }
        } else if (tipo == 'GENETICA') {
          detalhesObj = (geneticaByExame[exameUuid] ?? [])
              .map(AmostraGeneticaModel.fromMap)
              .toList();
        } else if (tipo == 'ANATOMO') {
          final detalhes = anatomoByExame[exameUuid] ?? [];
          detalhes.sort(
            (a, b) => ((a['numero_frasco'] as num?) ?? 0).compareTo(
              (b['numero_frasco'] as num?) ?? 0,
            ),
          );
          detalhesObj = detalhes.map(FrascoAnatomoModel.fromMap).toList();
        }

        return ExameSolicitadoModel.fromMap(mapMestre, detalhes: detalhesObj);
      }).toList();
    } catch (e) {
      debugPrint(
        '[CasoRepository] ❌ Erro ao obter exames para o caso $casoUuid: $e',
      );
      return [];
    }
  }

  /// Executa o expurgo de laudos antigos finalizados no SQLite para prevenir o esgotamento do armazenamento.
  ///
  /// Regra de Retenção Forense:
  /// - Apenas laudos com status `FINALIZADO`, `SINCRONIZADO` ou `CONCLUIDO` são elegíveis para remoção local.
  /// - O laudo deve ter sido atualizado há mais de 15 dias.
  /// - Casos em `RASCUNHO` ou `LAUDO_PENDENTE` são blindados e jamais excluídos.
  /// - A exclusão em cascata das tabelas filhas (Achados, Evidências, Exames) é executada explicitamente em lote.
  Future<void> expurgarCasosAntigos() async {
    final db = await database;
    try {
      final dataLimite = DateTime.now()
          .subtract(const Duration(days: 15))
          .toIso8601String();

      final casosParaExcluir = await db.query(
        tableCasos,
        columns: ['uuid'],
        where:
            "status IN ('FINALIZADO', 'SINCRONIZADO', 'CONCLUIDO') AND atualizado_em < ?",
        whereArgs: [dataLimite],
      );

      if (casosParaExcluir.isEmpty) {
        debugPrint('[CasoRepository] Nenhum caso antigo para expurgar.');
        return;
      }

      final uuids = casosParaExcluir.map((e) => e['uuid'] as String).toList();
      final placeholders = List.filled(uuids.length, '?').join(',');

      await db.transaction((txn) async {
        final batch = txn.batch();
        batch.delete(
          tableEvidenciasMultimidia,
          where: 'caso_uuid IN ($placeholders)',
          whereArgs: uuids,
        );
        batch.delete(
          tableAchados,
          where: 'caso_uuid IN ($placeholders)',
          whereArgs: uuids,
        );

        final subQuery =
            '(SELECT uuid FROM exames_solicitados WHERE caso_uuid IN ($placeholders))';
        batch.delete(
          'detalhes_toxicologico',
          where: 'exame_uuid IN $subQuery',
          whereArgs: uuids,
        );
        batch.delete(
          'amostras_genetica',
          where: 'exame_uuid IN $subQuery',
          whereArgs: uuids,
        );
        batch.delete(
          'frascos_anatomo',
          where: 'exame_uuid IN $subQuery',
          whereArgs: uuids,
        );

        batch.delete(
          'exames_solicitados',
          where: 'caso_uuid IN ($placeholders)',
          whereArgs: uuids,
        );
        batch.delete(
          tableCasos,
          where: 'uuid IN ($placeholders)',
          whereArgs: uuids,
        );
        await batch.commit(noResult: true);
      });

      debugPrint(
        '[CasoRepository] Expurgados ${uuids.length} casos finalizados mais antigos que 15 dias e suas dependências.',
      );
    } catch (e, stackTrace) {
      debugPrint(
        '[CasoRepository] ❌ Falha na transação de expurgo de casos antigos: $e\n$stackTrace',
      );
    }
  }
}
