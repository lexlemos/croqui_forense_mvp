import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:croqui_forense_mvp/data/models/caso_model.dart';
import 'package:croqui_forense_mvp/data/repositories/achado_repository.dart';
import 'package:croqui_forense_mvp/data/repositories/atn_repository.dart';
import 'package:croqui_forense_mvp/data/repositories/caso_repository.dart';
import 'package:croqui_forense_mvp/data/repositories/injury_type_repository.dart';
import 'package:croqui_forense_mvp/domain/services/achado_service.dart';
import 'package:croqui_forense_mvp/domain/services/active_case_lock_service.dart';
import 'package:croqui_forense_mvp/domain/services/case_service.dart';
import 'package:croqui_forense_mvp/presentation/pages/controllers/croqui_controller.dart';

class MockAchadoService extends Mock implements AchadoService {}
class MockCaseService extends Mock implements CaseService {}
class MockInjuryTypeRepository extends Mock implements InjuryTypeRepository {}
class MockAchadoRepository extends Mock implements AchadoRepository {}
class MockCasoRepository extends Mock implements CasoRepository {}
class MockAtnRepository extends Mock implements AtnRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CroquiController com ActiveCaseLockService (ADR-0002)', () {
    late MockAchadoService mockAchadoService;
    late MockCaseService mockCaseService;
    late MockInjuryTypeRepository mockInjuryTypeRepository;
    late MockAchadoRepository mockAchadoRepository;
    late MockCasoRepository mockCasoRepository;
    late MockAtnRepository mockAtnRepository;
    late IActiveCaseLockService lockService;

    final casoTeste = Caso.fromMap({
      'uuid': 'caso-em-edicao-123',
      'numero_requisicao': 'REQ-2026-99',
      'status': 'EM_ANDAMENTO',
    });

    setUpAll(() {
      registerFallbackValue(casoTeste);
    });

    setUp(() {
      mockAchadoService = MockAchadoService();
      mockCaseService = MockCaseService();
      mockInjuryTypeRepository = MockInjuryTypeRepository();
      mockAchadoRepository = MockAchadoRepository();
      mockCasoRepository = MockCasoRepository();
      mockAtnRepository = MockAtnRepository();
      lockService = ActiveCaseLockService();

      when(() => mockCaseService.salvarRascunho(any()))
          .thenAnswer((_) async {});
      when(() => mockAchadoService.listarAchados(any()))
          .thenAnswer((_) async => []);
      when(() => mockCaseService.getEvidenciasGerais(any()))
          .thenAnswer((_) async => []);
      when(() => mockCasoRepository.getEvidenciasPorCaso(any()))
          .thenAnswer((_) async => []);
      when(() => mockCaseService.getExamesSolicitados(any()))
          .thenAnswer((_) async => []);
      when(() => mockCasoRepository.getExamesPorCaso(any()))
          .thenAnswer((_) async => []);
      when(() => mockAtnRepository.getAtns())
          .thenAnswer((_) async => []);
    });

    test('adquire lock do caso no init e libera o lock no dispose', () async {
      expect(lockService.isLocked(casoTeste.uuid), isFalse);

      final controller = CroquiController(
        casoTeste,
        mockAchadoService,
        mockCaseService,
        mockInjuryTypeRepository,
        mockAchadoRepository,
        mockCasoRepository,
        mockAtnRepository,
        activeCaseLockService: lockService,
      );

      // Lock deve estar ativo enquanto o controller existir
      expect(lockService.isLocked(casoTeste.uuid), isTrue);

      controller.dispose();

      // Lock deve ter sido liberado no descarte da tela
      expect(lockService.isLocked(casoTeste.uuid), isFalse);
    });
  });
}
