import 'package:sqflite_sqlcipher/sqflite.dart';

import 'package:croqui_forense_mvp/data/models/injury_marker_model.dart';
import 'package:croqui_forense_mvp/data/local/database_helper.dart';

class InjuryService {
  Future<Database> get _db async => await DatabaseHelper.instance.database;

  Future<void> saveMarker(InjuryMarker marker) async {
    final db = await _db;
    await db.insert(
      'injury_markers',
      marker.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace, 
    );
  }

  Future<List<InjuryMarker>> getMarkersByCase(String caseId) async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      'injury_markers',
      where: 'case_id = ?',
      whereArgs: [caseId],
    );

    return List.generate(maps.length, (i) {
      return InjuryMarker.fromMap(maps[i]);
    });
  }
  
  Future<void> updateMarker(InjuryMarker marker) async {
    final db = await _db;
    await db.update(
      'injury_markers',
      marker.toMap(),
      where: 'id = ?',
      whereArgs: [marker.id],
    );
  }

  Future<void> deleteMarker(String markerId) async {
    final db = await _db;
    await db.delete(
      'injury_markers',
      where: 'id = ?',
      whereArgs: [markerId],
    );
  }

  Future<void> clearMarkersByCase(String caseId) async {
    final db = await _db;
    await db.delete(
      'injury_markers',
      where: 'case_id = ?',
      whereArgs: [caseId],
    );
  }
}