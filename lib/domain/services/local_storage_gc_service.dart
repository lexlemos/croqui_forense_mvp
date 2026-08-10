import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'package:croqui_forense_mvp/data/local/database_helper.dart';
import 'package:croqui_forense_mvp/core/constants/database_constants.dart';

/// Serviço de Garbage Collection (GC) de armazenamento local.
///
/// Expurga do SQLite e do sistema de arquivos os dados de casos que:
/// - Estão com status `FINALIZADO`
/// - Já foram confirmados como sincronizados com o servidor (`is_draft_synced = 1`)
/// - Foram finalizados há mais de [retentionDays] dias
///
/// Protege rigorosamente rascunhos (mesmo não sincronizados) e laudos pendentes.
class LocalStorageGcService {
  final DatabaseHelper _dbHelper;
  final int retentionDays;

  LocalStorageGcService({
    required DatabaseHelper dbHelper,
    this.retentionDays = 30,
  }) : _dbHelper = dbHelper;

  Future<Database> get _db async => _dbHelper.database;

  /// Executa a rotina de limpeza de armazenamento local.
  ///
  /// Busca os casos elegíveis para expurgo, deleta os arquivos físicos do disco
  /// (fotos de evidências e PDF compilado) e remove os registros do SQLite em cascata.
  ///
  /// **Critério de elegibilidade (todas as condições devem ser atendidas):**
  /// - `status = 'FINALIZADO'`
  /// - `is_draft_synced = 1` (laudo já está confirmado na nuvem)
  /// - `finalizado_em <= agora - [retentionDays] dias`
  ///
  /// @returns Número de casos expurgados com sucesso.
  Future<int> executarLimpezaDeRotina() async {
    final db = await _db;
    final cutoffDate = DateTime.now().subtract(Duration(days: retentionDays));
    final cutoffIso = cutoffDate.toIso8601String();

    debugPrint(
      '[GC] 🗑️ Iniciando Garbage Collection. '
      'Janela de retenção: ${retentionDays}d. Corte: $cutoffIso',
    );

    // 1. Identificar os casos elegíveis para expurgo com critério triplo seguro
    final List<Map<String, dynamic>> casosElegiveis = await db.rawQuery(
      '''
      SELECT
        uuid,
        pdf_local_path,
        finalizado_em
      FROM $tableCasos
      WHERE status          = 'FINALIZADO'
        AND is_draft_synced  = 1
        AND finalizado_em   IS NOT NULL
        AND finalizado_em   <= ?
        AND removido         = 0
      ''',
      [cutoffIso],
    );

    if (casosElegiveis.isEmpty) {
      debugPrint('[GC] ✅ Nenhum caso elegível para expurgo. Armazenamento limpo.');
      return 0;
    }

    debugPrint('[GC] 📋 ${casosElegiveis.length} caso(s) elegível(is) para expurgo.');
    int casosExpurgados = 0;

    for (final casoRow in casosElegiveis) {
      final String casoUuid = casoRow['uuid'] as String;
      final String? pdfPath = casoRow['pdf_local_path'] as String?;

      try {
        // 2a. Coletar todos os caminhos de arquivos físicos deste caso
        final List<Map<String, dynamic>> evidencias = await db.rawQuery(
          '''
          SELECT caminho_arquivo_encriptado
          FROM $tableEvidenciasMultimidia
          WHERE caso_uuid = ?
            AND caminho_arquivo_encriptado IS NOT NULL
            AND caminho_arquivo_encriptado != ''
          ''',
          [casoUuid],
        );

        int arquivosApagados = 0;
        int arquivosFalha = 0;

        // 2b. Apagar fisicamente os arquivos de fotos das evidências
        for (final ev in evidencias) {
          final String? filePath = ev['caminho_arquivo_encriptado'] as String?;
          if (filePath == null || filePath.isEmpty) continue;
          try {
            final file = File(filePath);
            if (await file.exists()) {
              await file.delete();
              arquivosApagados++;
            }
          } catch (e) {
            arquivosFalha++;
            debugPrint('[GC] ⚠️ Falha ao apagar evidência ($casoUuid): $filePath — $e');
          }
        }

        // 2c. Apagar o PDF compilado local
        if (pdfPath != null && pdfPath.isNotEmpty) {
          try {
            final pdfFile = File(pdfPath);
            if (await pdfFile.exists()) {
              await pdfFile.delete();
              arquivosApagados++;
              debugPrint('[GC] 🧹 PDF expurgado: $pdfPath');
            }
          } catch (e) {
            arquivosFalha++;
            debugPrint('[GC] ⚠️ Falha ao apagar PDF ($casoUuid): $pdfPath — $e');
          }
        }

        // 3. Só apaga do SQLite se TODOS os arquivos físicos foram removidos com sucesso.
        // Caso contrário, adia o expurgo para o próximo boot do app.
        if (arquivosFalha > 0) {
          debugPrint(
            '[GC] ⛔ Caso $casoUuid NÃO expurgado do SQLite: '
            '$arquivosFalha arquivo(s) físico(s) com falha. '
            'Tentativa adiada para o próximo boot.',
          );
          continue;
        }

        // 4. Apagar registros do SQLite em cascata
        // evidencias_multimidia, achados e exames_solicitados são removidos
        // automaticamente via ON DELETE CASCADE definido no schema.
        await db.delete(
          tableCasos,
          where: 'uuid = ?',
          whereArgs: [casoUuid],
        );

        casosExpurgados++;
        debugPrint(
          '[GC] ✅ Caso $casoUuid expurgado. '
          'Arquivos apagados: $arquivosApagados | Falhas: $arquivosFalha.',
        );
      } catch (e) {
        debugPrint('[GC] ❌ Erro ao expurgar caso $casoUuid: $e. Pulando.');
      }
    }

    debugPrint(
      '[GC] 🏁 Garbage Collection concluído. '
      '$casosExpurgados/${casosElegiveis.length} caso(s) expurgado(s).',
    );
    return casosExpurgados;
  }
}
