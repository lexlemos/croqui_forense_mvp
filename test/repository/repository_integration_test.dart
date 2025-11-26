import 'package:flutter_test/flutter_test.dart';
// Importações essenciais para o banco de dados e testes
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';

// Importa todas as classes necessárias para o teste
import 'package:croqui_forense_mvp/data/local/database_helper.dart';
import 'package:croqui_forense_mvp/data/repositories/usuario_repository.dart';
import 'package:croqui_forense_mvp/data/repositories/caso_repository.dart';
import 'package:croqui_forense_mvp/data/models/caso_model.dart';
import 'package:croqui_forense_mvp/data/models/usuario_model.dart';

void main() {
  // Inicializa o Helper e Repositórios
  final dbHelper = DatabaseHelper();
  late UsuarioRepository usuarioRepo;
  late CasoRepository casoRepo;
  
  // Variável para armazenar o ID do usuário Admin para os testes
  late Usuario adminUser;

  // 1. Setup inicial: Abre o DB e garante que o Seeder rodou.
  setUpAll(() async {
    // Força a abertura do banco, que roda o onCreate e o Seeder
    await dbHelper.database; 

    usuarioRepo = UsuarioRepository(dbHelper);
    casoRepo = CasoRepository(dbHelper);
    
    // Busca o usuário padrão criado pelo Seeder
    final user = await usuarioRepo.getUsuarioByMatricula('ADMIN001');
    // Se esta linha falhar, o Seeder está com problemas ou o DB não abriu.
    expect(user, isNotNull, reason: 'Seeder falhou ao criar o usuário ADMIN001.');
    adminUser = user!;
    
    print('Setup Completo. Usuário Admin ID: ${adminUser.id}');
  });
  
  // 2. Limpeza (deixamos vazio por ser um MVP; a deleção do DB é complexa com SQLCipher)
  tearDownAll(() async {});


  group('Fase 2 - Persistência e Repositórios (Testes de Integração)', () {
    
    // Testa se o seeder injetou o usuário e se o Repository consegue buscá-lo.
    test('1. Deve encontrar o usuário Admin padrão (ADMIN001) e verificar o Hash', () async {
      final user = await usuarioRepo.getUsuarioByMatricula('ADMIN001');
      
      expect(user, isNotNull, reason: 'Usuário ADMIN001 não foi encontrado.');
      expect(user!.nomeCompleto, equals('Administrador Padrao MVP'));
      // Verifica se o hash SHA-256 foi gerado (tamanho maior que 20 caracteres)
      expect(user.hashPinOffline.length, greaterThan(20)); 
    });

    test('2. Deve criar e listar um novo caso', () async {
      final novoCaso = Caso.novo(
        idUsuarioCriador: adminUser.id,
        // Gera um ID de caso único e aleatório para garantir que não haja conflito
        numeroLaudoExterno: 'TESTE-2025-${const Uuid().v4().substring(0, 4)}',
        proveniencia: 'TESTE_AUTOMATIZADO',
      );
      
      await casoRepo.insertCase(novoCaso);
      
      final todosCasos = await casoRepo.getAllCases();
      final casoInserido = todosCasos.firstWhere((c) => c.uuid == novoCaso.uuid);
      
      // Validações
      expect(todosCasos.length, greaterThanOrEqualTo(1), reason: 'A lista de casos não pode estar vazia.');
      expect(casoInserido.numeroLaudoExterno, equals(novoCaso.numeroLaudoExterno));
      expect(casoInserido.status, equals(StatusCaso.rascunho));
    });

    // 🔴 TESTE CRÍTICO DE SEGURANÇA E INTEGRIDADE (FOREIGN KEY)
    test('3. Deve rejeitar a inserção de um caso com ID de usuário inexistente (Validação FK)', () async {
      // Cria um caso que tenta usar um ID de usuário que não existe (99999)
      final casoInvalido = Caso.novo(
        idUsuarioCriador: 99999, // ID que não existe na tabela 'usuarios'
        numeroLaudoExterno: 'ERRO-FK-001',
      );
      
      // Espera-se uma exceção de violação de chave estrangeira (DatabaseException)
      await expectLater(
        casoRepo.insertCase(casoInvalido),
        throwsA(isA<DatabaseException>()),
        reason: 'O banco deve rejeitar a inserção, provando que a Foreign Key (ON DELETE RESTRICT) está ativa.',
      );
    });
  });
}