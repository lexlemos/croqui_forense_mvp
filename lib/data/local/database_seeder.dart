import 'dart:convert';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:croqui_forense_mvp/core/security/security_helper.dart';

class DatabaseSeeder {
  final DatabaseExecutor db;

  DatabaseSeeder(this.db);

  static const String roleAdminId = '11111111-2222-3333-4444-555555555555';
  static const String roleLegistaId = '8f9a3361-d3f3-4f8c-a89a-44998a3047e0';

  static const String permCriarId = 'b1c2d3e4-0001-4000-8000-000000000001';
  static const String permExportarId = 'b1c2d3e4-0002-4000-8000-000000000002';
  static const String permGestaoId = 'b1c2d3e4-0003-4000-8000-000000000003';

  static const String fixedDate = '2024-01-01T12:00:00.000';

  Future<void> seedAll() async {
    await _seedRoles();
    await _seedPermissions();
    await _seedRolePermissions(); 
    await _seedDefaultUser();
    await seedAtns();
  }

  Future<void> seedAtns() async {
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM atns'));
    if (count != null && count > 0) return;

    await db.insert('atns', {'id': 'atn-001', 'nome': 'ATN João'});
    await db.insert('atns', {'id': 'atn-002', 'nome': 'ATN Maria'});
  }
  
  Future<void> _seedRoles() async {
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM papeis'));
    if (count != null && count > 0) return;

    await db.insert('papeis', {
      'id': roleAdminId, 'nome': 'ADMIN', 'descricao': 'Administrador do Sistema', 'e_padrao': 0
    });
    await db.insert('papeis', {
      'id': roleLegistaId, 'nome': 'PERITO_GERAL', 'descricao': 'Médico Perito', 'e_padrao': 1
    });
  }

  Future<void> _seedPermissions() async {
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM permissoes'));
    if (count != null && count > 0) return;

    await db.insert('permissoes', {'id': permCriarId, 'codigo': 'CASO_CRIAR', 'descricao': 'Permite iniciar um novo caso.'});
    await db.insert('permissoes', {'id': permExportarId, 'codigo': 'CASO_EXPORTAR', 'descricao': 'Permite gerar o pacote ZIP final.'});
    await db.insert('permissoes', {'id': permGestaoId, 'codigo': 'GESTAO_USUARIOS', 'descricao': 'Permite gerenciar usuários e papéis.'});
  }

  Future<void> _seedRolePermissions() async {
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM papel_permissoes'));
    if (count != null && count > 0) return;

    await db.insert('papel_permissoes', {'papel_id': roleAdminId, 'permissao_id': permCriarId});
    await db.insert('papel_permissoes', {'papel_id': roleAdminId, 'permissao_id': permExportarId});
    await db.insert('papel_permissoes', {'papel_id': roleAdminId, 'permissao_id': permGestaoId});
    await db.insert('papel_permissoes', {'papel_id': roleLegistaId, 'permissao_id': permCriarId});
    await db.insert('papel_permissoes', {'papel_id': roleLegistaId, 'permissao_id': permExportarId});
  }

  Future<void> _seedDefaultUser() async {
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM usuarios'));
    if (count != null && count > 0) return;

    const String defaultPin = '1234';
    final String salt = SecurityHelper.generateSalt();
    final String hashedPin = SecurityHelper.hashPin(defaultPin, salt);
    const String adminUserId = 'f47ac10b-58cc-4372-a567-0e02b2c3d479';

    await db.insert('usuarios', {
      'id': adminUserId, 
      'matricula_funcional': 'ADMIN002',
      'nome_completo': 'Administrador Padrao',
      'papel_id': roleAdminId,
      'roles': jsonEncode(['ADMIN']),
      'hash_pin_offline': hashedPin,
      'salt': salt,
      'ativo': 1,
      'deve_alterar_pin': 1, 
      'criado_em': fixedDate,
    });
  }

}