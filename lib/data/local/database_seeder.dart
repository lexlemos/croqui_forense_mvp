import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:croqui_forense_mvp/core/security/security_helper.dart';

class DatabaseSeeder {
  final DatabaseExecutor db;

  DatabaseSeeder(this.db);

  static const String roleAdminId = 'role_admin';
  static const String roleLegistaId = 'role_legista';
  
  static const String permCriarId = 'perm_criar_caso';
  static const String permExportarId = 'perm_exportar_caso';
  static const String permGestaoId = 'perm_gestao_users';

  static const String fixedDate = '2024-01-01T12:00:00.000';

  Future<void> seedAll() async {
    await _seedRoles();
    await _seedPermissions();
    await _seedRolePermissions(); 
    await _seedDefaultUser();
    await _seedCatalogData(); 
  }
  Future<void> seedInjuryTypes() async {
    
    List<Map<String, dynamic>> padroes = [
      {'id': 'equimose', 'label': 'Equimose', 'ordem': 1},
      {'id': 'escoriacao', 'label': 'Escoriação', 'ordem': 2},
      {'id': 'ferida_contusa', 'label': 'Ferida Contusa', 'ordem': 3},
      {'id': 'ferida_cortante', 'label': 'Ferida Cortante', 'ordem': 4},
      {'id': 'perfuracao', 'label': 'Perfuração', 'ordem': 5},
      {'id': 'hematoma', 'label': 'Hematoma', 'ordem': 6},
      {'id': 'edema', 'label': 'Edema', 'ordem': 7},
      {'id': 'fratura', 'label': 'Fratura', 'ordem': 8},
      {'id': 'queimadura', 'label': 'Queimadura', 'ordem': 9},
      {'id': 'tiro', 'label': 'Tiro / PAF', 'ordem': 10},
      {'id': 'outro', 'label': 'Outro', 'ordem': 99},
    ];

    for (var item in padroes) {
      final List<Map<String, dynamic>> exists = await db.query(
        'injury_types',
        where: 'id = ?',
        whereArgs: [item['id']],
      );
      
      if (exists.isEmpty) {
        await db.insert('injury_types', item);
      }
    }
  }

  Future<void> _seedRoles() async {
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM papeis'));
    if (count != null && count > 0) return;

    await db.insert('papeis', {
      'id': roleAdminId, 'nome': 'ADMIN', 'descricao': 'Administrador do Sistema', 'e_padrao': 0
    });
    await db.insert('papeis', {
      'id': roleLegistaId, 'nome': 'LEGISTA', 'descricao': 'Médico Perito', 'e_padrao': 1
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
    final String adminUserId = const Uuid().v4(); 

    await db.insert('usuarios', {
      'id': adminUserId, 
      'matricula_funcional': 'ADMIN001',
      'nome_completo': 'Administrador Padrao MVP',
      'crm': '12347/SE',
      'classe': '1',
      'papel_id': roleAdminId,
      'hash_pin_offline': hashedPin,
      'salt': salt,
      'ativo': 1,
      'deve_alterar_pin': 1, 
      'criado_em': fixedDate,
    });
  }

  Future<void> _seedCatalogData() async {
    await db.insert('templates_diagrama', {
      'id': 'corpo_humano_padrao',
      'nome': 'Corpo Humano Completo',
      'caminho_svg': 'assets/images/croqui-frente.svg', 
      'criado_em': fixedDate,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    final types = [
      {'id': 'equimose', 'nome': 'Equimose'},
      {'id': 'escoriacao', 'nome': 'Escoriação'},
      {'id': 'ferida_contusa', 'nome': 'Ferida Contusa'},
      {'id': 'ferida_cortante', 'nome': 'Ferida Cortante'},
      {'id': 'perfuracao', 'nome': 'Perfuração'},
      {'id': 'hematoma', 'nome': 'Hematoma'},
      {'id': 'edema', 'nome': 'Edema'},
      {'id': 'fratura', 'nome': 'Fratura'},
      {'id': 'queimadura', 'nome': 'Queimadura'},
      {'id': 'outro', 'nome': 'Outro'},
    ];

    const String defaultSchema = '{"fields": [{"name": "obs", "label": "Observações", "type": "text"}]}';

    for (var t in types) {
      await db.insert('tipos_achados', {
        'id': t['id'],
        'nome': t['nome'],
        'caminho_icone': null,
        'schema_formulario_json': defaultSchema,
        'versao': 1,
        'criado_em': fixedDate,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }
}