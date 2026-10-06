import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:croqui_forense_mvp/core/constants/database_constants.dart';
import 'package:croqui_forense_mvp/data/local/database_helper.dart';
import 'package:croqui_forense_mvp/data/models/injury_type_model.dart';

/// Repositório de persistência e consulta dos tipos de lesões e achados forenses cadastrados.
///
/// Gerencia as definições dinâmicas de tipos de lesão (ex: PAF, perfurocontundente, cortante),
/// seus esquemas de formulário JSON e ordenação visual na tabela `tipos_achados`.
class InjuryTypeRepository {
  final DatabaseHelper _dbHelper;

  /// Cria uma instância de [InjuryTypeRepository] vinculada ao [DatabaseHelper].
  InjuryTypeRepository(this._dbHelper);

  /// Retorna todos os tipos de lesões ativos (`ativo = 1`) ordenados pela posição de exibição.
  Future<List<InjuryType>> getAllTypes() async {
    final db = await _dbHelper.database;
    final result = await db.query(
      tableTiposAchados,
      where: 'ativo = 1',
      orderBy: 'ordem ASC',
    );
    return result.map((m) => InjuryType.fromMap(m)).toList();
  }

  /// Retorna os tipos de lesões ativos filtrados pelo escopo anatômico (interno vs externo).
  ///
  /// Parâmetros:
  /// - [isInterno]: Se `true`, retorna tipos aplicáveis a cavidades internas; caso contrário, lesões de exame externo.
  Future<List<InjuryType>> getTypesByScope({required bool isInterno}) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      tableTiposAchados,
      where: 'ativo = 1 AND is_interno = ?',
      whereArgs: [isInterno ? 1 : 0],
      orderBy: 'ordem ASC',
    );
    return result.map((m) => InjuryType.fromMap(m)).toList();
  }

  /// Insere ou atualiza em lote uma lista de tipos de lesão via transação atômica SQLite.
  ///
  /// Parâmetros:
  /// - [types]: Coleção de [InjuryType] sincronizada ou atualizada.
  Future<void> upsertAll(List<InjuryType> types) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      final existingRows = await txn.query(tableTiposAchados, columns: ['id']);
      final existingIds = existingRows
          .map((row) => row['id'] as String)
          .toSet();

      final batch = txn.batch();
      for (final type in types) {
        if (existingIds.contains(type.id)) {
          batch.update(
            tableTiposAchados,
            type.toMap(),
            where: 'id = ?',
            whereArgs: [type.id],
          );
        } else {
          batch.insert(
            tableTiposAchados,
            type.toMap(),
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      }
      await batch.commit(noResult: true);
    });
  }
}
