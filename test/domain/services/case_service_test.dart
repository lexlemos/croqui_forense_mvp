import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:croqui_forense_mvp/domain/services/case_service.dart';
import 'package:croqui_forense_mvp/data/repositories/caso_repository.dart';
import 'package:croqui_forense_mvp/data/models/caso_model.dart';
import 'package:croqui_forense_mvp/data/models/usuario_model.dart';

class MockCasoRepository extends Mock implements CasoRepository {}

// Fake necessário para o setUp do 'any()'
class FakeCaso extends Fake implements Caso {}

void main() {
  late CaseService caseService;
  late MockCasoRepository mockRepo;

  setUpAll(() {
    registerFallbackValue(FakeCaso());
  });

  setUp(() {
    mockRepo = MockCasoRepository();
    caseService = CaseService(mockRepo);
    
    // Configuração padrão
    when(() => mockRepo.insertCase(any())).thenAnswer((_) async {});
    when(() => mockRepo.getAllCases()).thenAnswer((_) async => []);
  });

  final mockUser = Usuario(
    id: 99,
    matriculaFuncional: 'PERITO_01',
    nomeCompleto: 'Perito Teste',
    papelId: 1,
    ativo: true,
    hashPinOffline: 'hash',
    criadoEm: DateTime.now(),
  );

  group('CaseService Logic', () {
    test('createNewCase DEVE gerar UUID e vincular ID do criador', () async {
      // 1. Executa a ação
      final novoCaso = await caseService.createNewCase(
        criador: mockUser,
        numeroLaudo: 'LAUDO-2025-X',
      );

      // 2. Verificações do objeto retornado
      expect(novoCaso.numeroLaudoExterno, 'LAUDO-2025-X');
      expect(novoCaso.idUsuarioCriador, 99);
      expect(novoCaso.uuid, isNotEmpty);
      expect(novoCaso.status, StatusCaso.rascunho);

      // 3. Verificação do Repositório (Simplificada e Mais Segura)
      // Verificamos se o insertCase foi chamado com O PRÓPRIO objeto retornado.
      // Isso prova que o serviço salvou exatamente o que criou.
      verify(() => mockRepo.insertCase(novoCaso)).called(1);
    });

    test('listarCasos DEVE repassar chamada ao repositório', () async {
      await caseService.listarCasos();
      verify(() => mockRepo.getAllCases()).called(1);
    });
  });
}