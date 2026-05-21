import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:croqui_forense_mvp/core/security/security_helper.dart';
import 'package:croqui_forense_mvp/core/constants/diagram_constants.dart';

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
    await _seedCatalogData(); 
  }
  Future<void> _seedRoles() async {
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM papeis'));
    if (count != null && count > 0) return;

    await db.insert('papeis', {
      'id': roleAdminId, 'nome': 'ADMIN', 'descricao': 'Administrador do Sistema', 'e_padrao': 0
    });
    await db.insert('papeis', {
      'id': roleLegistaId, 'nome': 'PERITO', 'descricao': 'Médico Perito', 'e_padrao': 1
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
    final templates = [
      {'id': DiagramTemplates.frente, 'nome': 'Corpo Frente', 'caminho_svg': 'assets/images/croqui-frente.svg'},
      {'id': DiagramTemplates.costas, 'nome': 'Corpo Costas', 'caminho_svg': 'assets/images/croqui-costas.svg'},
      {'id': DiagramTemplates.lateralDireito, 'nome': 'Corpo Lateral Direito', 'caminho_svg': 'assets/images/croqui-rosto-direito.svg'},
      {'id': DiagramTemplates.lateralEsquerdo, 'nome': 'Corpo Lateral Esquerdo', 'caminho_svg': 'assets/images/croqui-rosto-frente.svg'},
    ];

    for (var tpl in templates) {
      await db.insert('templates_diagrama', {
        'id': tpl['id'],
        'nome': tpl['nome'],
        'caminho_svg': tpl['caminho_svg'],
        'criado_em': fixedDate,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    final types = [
      {'id': 'equimose', 'nome': 'Equimose', 'ordem': 1},
      {'id': 'escoriacao', 'nome': 'Escoriação', 'ordem': 2},
      {'id': 'ferida_contusa', 'nome': 'Ferida Contusa', 'ordem': 3},
      {'id': 'ferida_cortante', 'nome': 'Ferida Cortante', 'ordem': 4},
      {'id': 'perfuracao', 'nome': 'Perfuração', 'ordem': 5},
      {'id': 'hematoma', 'nome': 'Hematoma', 'ordem': 6},
      {'id': 'edema', 'nome': 'Edema', 'ordem': 7},
      {'id': 'fratura', 'nome': 'Fratura', 'ordem': 8},
      {'id': 'queimadura', 'nome': 'Queimadura', 'ordem': 9},
      {'id': 'tiro', 'nome': 'Tiro / PAF', 'ordem': 10},
      {'id': 'outro', 'nome': 'Outro', 'ordem': 99},
    ];

    const String defaultSchema = '{"fields": [{"name": "obs", "label": "Observações", "type": "text"}]}';

    for (var t in types) {
      await db.insert('tipos_achados', {
        'id': t['id'],
        'nome': t['nome'],
        'caminho_icone': null,
        'schema_formulario_json': defaultSchema,
        'ordem': t['ordem'],
        'ativo': 1,
        'versao': 1,
        'criado_em': fixedDate,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }
}