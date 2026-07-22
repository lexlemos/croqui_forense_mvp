import 'package:flutter/foundation.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:croqui_forense_mvp/data/local/database_helper.dart';
import 'package:croqui_forense_mvp/data/models/exames/exame_solicitado_model.dart';
import 'package:croqui_forense_mvp/data/models/exames/detalhes_toxicologico_model.dart';
import 'package:croqui_forense_mvp/data/models/exames/amostra_genetica_model.dart';
import 'package:croqui_forense_mvp/data/models/exames/frasco_anatomo_model.dart';

/// Repositório SQLite especializado na persistência polimórfica de [ExameSolicitadoModel].
class ExameRepository {
  final DatabaseHelper _dbHelper;

  ExameRepository(this._dbHelper);

  Future<Database> get database async => _dbHelper.database;

  /// Persiste a lista de exames solicitados e suas filhas polimórficas de forma atômica e performática.
  Future<void> salvarExames(String casoUuid, List<ExameSolicitadoModel> exames) async {
    final db = await database;
    try {
      await db.transaction((txn) async {
        final batch = txn.batch();

        // 1. Deleta exames anteriores (ON DELETE CASCADE limpa as filhas automaticamente)
        batch.delete(
          'exames_solicitados',
          where: 'caso_uuid = ?',
          whereArgs: [casoUuid],
        );

        // 2. Insere a tabela mestra e as dependências relacionais nas filhas
        for (final exame in exames) {
          batch.insert('exames_solicitados', exame.toMap());

          final detalhes = exame.detalhes;
          if (detalhes == null) continue;

          final tipo = exame.tipoExame.toUpperCase().trim();

          if (tipo == 'TOXICOLOGICO') {
            if (detalhes is DetalhesToxicologicoModel) {
              batch.insert('detalhes_toxicologico', detalhes.toMap());
            } else if (detalhes is Map<String, dynamic>) {
              batch.insert('detalhes_toxicologico', detalhes);
            }
          } else if (tipo == 'GENETICA') {
            if (detalhes is List) {
              for (final item in detalhes) {
                if (item is AmostraGeneticaModel) {
                  batch.insert('amostras_genetica', item.toMap());
                } else if (item is Map<String, dynamic>) {
                  batch.insert('amostras_genetica', item);
                }
              }
            } else if (detalhes is AmostraGeneticaModel) {
              batch.insert('amostras_genetica', detalhes.toMap());
            }
          } else if (tipo == 'ANATOMO') {
            if (detalhes is List) {
              for (final item in detalhes) {
                if (item is FrascoAnatomoModel) {
                  batch.insert('frascos_anatomo', item.toMap());
                } else if (item is Map<String, dynamic>) {
                  batch.insert('frascos_anatomo', item);
                }
              }
            } else if (detalhes is FrascoAnatomoModel) {
              batch.insert('frascos_anatomo', detalhes.toMap());
            }
          }
        }

        await batch.commit(noResult: true);
      });
      debugPrint('[ExameRepository] ✅ ${exames.length} exames salvos com sucesso para o caso $casoUuid');
    } catch (e) {
      debugPrint('[ExameRepository] ❌ Erro ao salvar exames para o caso $casoUuid: $e');
      rethrow;
    }
  }

  /// Recupera todos os exames solicitados e suas tabelas filhas polimórficas para um caso específico.
  Future<List<ExameSolicitadoModel>> getExamesPorCaso(String casoUuid) async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> examesMaps = await db.query(
        'exames_solicitados',
        where: 'caso_uuid = ?',
        whereArgs: [casoUuid],
        orderBy: 'criado_em ASC',
      );

      final List<ExameSolicitadoModel> resultado = [];

      for (final mapMestre in examesMaps) {
        final String exameUuid = mapMestre['uuid']?.toString() ?? '';
        final String tipo = (mapMestre['tipo_exame']?.toString() ?? '').toUpperCase().trim();

        dynamic detalhesObj;

        if (tipo == 'TOXICOLOGICO') {
          final toxicMaps = await db.query(
            'detalhes_toxicologico',
            where: 'exame_uuid = ?',
            whereArgs: [exameUuid],
            limit: 1,
          );
          if (toxicMaps.isNotEmpty) {
            detalhesObj = DetalhesToxicologicoModel.fromMap(toxicMaps.first);
          }
        } else if (tipo == 'GENETICA') {
          final genMaps = await db.query(
            'amostras_genetica',
            where: 'exame_uuid = ?',
            whereArgs: [exameUuid],
          );
          detalhesObj = genMaps.map((m) => AmostraGeneticaModel.fromMap(m)).toList();
        } else if (tipo == 'ANATOMO') {
          final anatomoMaps = await db.query(
            'frascos_anatomo',
            where: 'exame_uuid = ?',
            whereArgs: [exameUuid],
            orderBy: 'numero_frasco ASC',
          );
          detalhesObj = anatomoMaps.map((m) => FrascoAnatomoModel.fromMap(m)).toList();
        }

        resultado.add(ExameSolicitadoModel.fromMap(mapMestre, detalhes: detalhesObj));
      }

      return resultado;
    } catch (e) {
      debugPrint('[ExameRepository] ❌ Erro ao obter exames para o caso $casoUuid: $e');
      return [];
    }
  }
}
