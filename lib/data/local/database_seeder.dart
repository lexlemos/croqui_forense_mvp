import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:croqui_forense_mvp/core/security/security_helper.dart';

class DatabaseSeeder {
  final DatabaseExecutor db;

  DatabaseSeeder(this.db);

  static const String ROLE_ADMIN_ID = 'role_admin';
  static const String ROLE_LEGISTA_ID = 'role_legista';
  
  static const String PERM_CRIAR_ID = 'perm_criar_caso';
  static const String PERM_EXPORTAR_ID = 'perm_exportar_caso';
  static const String PERM_GESTAO_ID = 'perm_gestao_users';

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

    await db.insert('papeis', {
      'id': ROLE_ADMIN_ID, 
      'nome': 'ADMIN', 
      'descricao': 'Administrador do Sistema', 
      'e_padrao': 0
    });
    
    await db.insert('papeis', {
      'id': ROLE_LEGISTA_ID, 
      'nome': 'LEGISTA', 
      'descricao': 'Médico Perito', 
      'e_padrao': 1
    });
  }

  Future<void> _seedPermissions() async {
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM permissoes'));
    if (count != null && count > 0) return;

    await db.insert('permissoes', {
      'id': PERM_CRIAR_ID, 
      'codigo': 'CASO_CRIAR', 
      'descricao': 'Permite iniciar um novo caso.'
    });
    
    await db.insert('permissoes', {
      'id': PERM_EXPORTAR_ID,
      'codigo': 'CASO_EXPORTAR', 
      'descricao': 'Permite gerar o pacote ZIP final.'
    });
    
    await db.insert('permissoes', {
      'id': PERM_GESTAO_ID,
      'codigo': 'GESTAO_USUARIOS', 
      'descricao': 'Permite gerenciar usuários e papéis.'
    });
  }

  Future<void> _seedRolePermissions() async {
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM papel_permissoes'));
    if (count != null && count > 0) return;

    await db.insert('papel_permissoes', {'papel_id': ROLE_ADMIN_ID, 'permissao_id': PERM_CRIAR_ID});
    await db.insert('papel_permissoes', {'papel_id': ROLE_ADMIN_ID, 'permissao_id': PERM_EXPORTAR_ID});
    await db.insert('papel_permissoes', {'papel_id': ROLE_ADMIN_ID, 'permissao_id': PERM_GESTAO_ID});

    await db.insert('papel_permissoes', {'papel_id': ROLE_LEGISTA_ID, 'permissao_id': PERM_CRIAR_ID});
    await db.insert('papel_permissoes', {'papel_id': ROLE_LEGISTA_ID, 'permissao_id': PERM_EXPORTAR_ID});
  }

  Future<void> _seedDefaultUser() async {
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM usuarios'));
    if (count != null && count > 0) return;

    const String defaultPin = '1234';
    final String salt = SecurityHelper.generateSalt();
    final String hashedPin = SecurityHelper.hashPin(defaultPin, salt);
    
    final String adminUserId = const Uuid().v4(); 

    await db.insert('usuarios', {
      'id': adminUserId, 
      'matricula_funcional': 'ADMIN001',
      'nome_completo': 'Administrador Padrao MVP',
      'papel_id': ROLE_ADMIN_ID,
      'hash_pin_offline': hashedPin,
      'salt': salt,
      'ativo': 1,
      'deve_alterar_pin': 1, 
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