// lib/data/local/database_seeder.dart

import 'package:sqflite_sqlcipher/sqflite.dart'; 
import 'package:croqui_forense_mvp/core/security/security_helper.dart';

class DatabaseSeeder {
  final DatabaseExecutor db;

  DatabaseSeeder(this.db);

  Future<void> seedAll() async {
    await _seedRoles();
    await _seedPermissions();
    await _seedRolePermissions();
    await _seedDefaultUser();
    await _seedCatalogData();
  }

  Future<void> _seedRoles() async {
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM papeis'));
    if (count != null && count > 0) return;

    await db.insert('papeis', {'nome': 'ADMIN', 'descricao': 'Administrador do Sistema', 'e_padrao': 0});
    await db.insert('papeis', {'nome': 'LEGISTA', 'descricao': 'Médico Perito', 'e_padrao': 1});
  }

  Future<void> _seedPermissions() async {
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM permissoes'));
    if (count != null && count > 0) return;

    await db.insert('permissoes', {'codigo': 'CASO_CRIAR', 'descricao': 'Permite iniciar um novo caso.'});
    await db.insert('permissoes', {'codigo': 'CASO_EXPORTAR', 'descricao': 'Permite gerar o pacote ZIP final.'});
    await db.insert('permissoes', {'codigo': 'GESTAO_USUARIOS', 'descricao': 'Permite gerenciar usuários e papéis.'});
  }

  Future<void> _seedRolePermissions() async {
    final roles = await db.query('papeis');
    if (roles.isEmpty) return;

    final adminId = roles.firstWhere((r) => r['nome'] == 'ADMIN')['id'];
    final legistaId = roles.firstWhere((r) => r['nome'] == 'LEGISTA')['id'];

    final perms = await db.query('permissoes');
    final criarPermId = perms.firstWhere((p) => p['codigo'] == 'CASO_CRIAR')['id'];
    final exportPermId = perms.firstWhere((p) => p['codigo'] == 'CASO_EXPORTAR')['id'];
    final gestaoPermId = perms.firstWhere((p) => p['codigo'] == 'GESTAO_USUARIOS')['id'];

    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM papel_permissoes'));
    if (count != null && count > 0) return;

    await db.insert('papel_permissoes', {'papel_id': adminId, 'permissao_id': criarPermId});
    await db.insert('papel_permissoes', {'papel_id': adminId, 'permissao_id': exportPermId});
    await db.insert('papel_permissoes', {'papel_id': adminId, 'permissao_id': gestaoPermId});

    await db.insert('papel_permissoes', {'papel_id': legistaId, 'permissao_id': criarPermId});
    await db.insert('papel_permissoes', {'papel_id': legistaId, 'permissao_id': exportPermId});
  }

  Future<void> _seedDefaultUser() async {
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM usuarios'));
    if (count != null && count > 0) return;

    final adminId = await db.query('papeis', where: 'nome = ?', whereArgs: ['ADMIN']).then((list) => list.first['id']);
    
    const String defaultPin = '1234';

    final String salt = SecurityHelper.generateSalt();
    final String hashedPin = SecurityHelper.hashPin(defaultPin, salt);

    await db.insert('usuarios', {
      'matricula_funcional': 'ADMIN001',
      'nome_completo': 'Administrador Padrao MVP',
      'papel_id': adminId,
      'hash_pin_offline': hashedPin,
      'salt': salt,
      'ativo': 1,
      'criado_em': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _seedCatalogData() async {
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM tipos_achados'));
    if (count != null && count > 0) return;

    const String hematomaSchema = '''
      {
        "fields": [
          {"name": "dimensoes", "label": "Dimensões (cm)", "type": "text", "required": true},
          {"name": "cor", "label": "Coloração", "type": "select", "options": ["Roxa", "Amarelada"], "required": true},
          {"name": "profundidade", "label": "Profundidade (Tecido)", "type": "boolean", "required": false}
        ]
      }
    ''';
    
    await db.insert('tipos_achados', {
      'id': 'HEMATOMA',
      'nome': 'Hematoma / Contusão',
      'schema_formulario_json': hematomaSchema,
    });
    
    await db.insert('templates_diagrama', {
      'id': 'ADULTO_FRENTE',
      'nome': 'Adulto Masculino - Frente',
      'caminho_svg': 'assets/diagrams/male_front.svg',
    });
  }
}