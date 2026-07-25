import 'package:flutter/foundation.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:croqui_forense_mvp/data/local/database_helper.dart';
import 'package:croqui_forense_mvp/data/models/atn_model.dart';

/// Repositório responsável pela persistência local da tabela de ATNs (Auxiliar Técnico de Necropsia).
class AtnRepository {
  final DatabaseHelper _dbHelper;

  AtnRepository(this._dbHelper);

  Future<Database> get database async => _dbHelper.database;

  /// Obtém a lista de todos os ATNs ativos cadastrados ordenados por nome.
  Future<List<AtnModel>> getAtns() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'atns',
        where: 'ativo = 1',
        orderBy: 'nome ASC',
      );
      return maps.map((m) => AtnModel.fromMap(m)).toList();
    } catch (e) {
      debugPrint('[AtnRepository] ❌ Erro ao buscar ATNs: $e');
      return [];
    }
  }

  /// Sincroniza em lote os ATNs recebidos do servidor backend.
  /// 
  /// REGRA DE SEGURANÇA (Guard Clause): Se a lista recebida do servidor estiver vazia,
  /// o método aborta imediatamente para evitar apagar (*wipe-out*) o cache local do SQLite.
  Future<void> sincronizarAtns(List<AtnModel> atnsServidor) async {
    // 🛡️ Guard Clause contra Wipe-out do cache local
    if (atnsServidor.isEmpty) {
      debugPrint('[AtnRepository] ⚠️ Lista de ATNs do servidor vazia. Sincronização ignorada para preservar o cache local.');
      return;
    }

    try {
      final db = await database;
      await db.transaction((txn) async {
        await txn.delete('atns');
        final batch = txn.batch();
        for (final atn in atnsServidor) {
          batch.insert(
            'atns',
            atn.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
      });
      debugPrint('[AtnRepository] ✅ Sincronizados ${atnsServidor.length} ATN(s) no banco local com sucesso.');
    } catch (e) {
      debugPrint('[AtnRepository] ❌ Erro ao sincronizar ATNs: $e');
      rethrow;
    }
  }
}
