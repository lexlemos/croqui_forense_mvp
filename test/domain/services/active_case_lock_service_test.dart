import 'package:flutter_test/flutter_test.dart';
import 'package:croqui_forense_mvp/domain/services/active_case_lock_service.dart';

void main() {
  group('ActiveCaseLockService - Active Case Mutex (ADR-0002)', () {
    late IActiveCaseLockService lockService;

    setUp(() {
      lockService = ActiveCaseLockService();
    });

    test('inicialmente nenhum laudo pericial deve estar bloqueado', () {
      expect(lockService.isLocked('caso-uuid-1'), isFalse);
      expect(lockService.lockedCaseUuids, isEmpty);
    });

    test('acquireLock bloqueia o UUID do caso ativo', () {
      lockService.acquireLock('caso-uuid-1');

      expect(lockService.isLocked('caso-uuid-1'), isTrue);
      expect(lockService.isLocked('caso-uuid-2'), isFalse);
      expect(lockService.lockedCaseUuids, contains('caso-uuid-1'));
      expect(lockService.lockedCaseUuids.length, equals(1));
    });

    test('releaseLock desfaz o bloqueio do caso', () {
      lockService.acquireLock('caso-uuid-1');
      expect(lockService.isLocked('caso-uuid-1'), isTrue);

      lockService.releaseLock('caso-uuid-1');
      expect(lockService.isLocked('caso-uuid-1'), isFalse);
      expect(lockService.lockedCaseUuids, isEmpty);
    });

    test('releaseLock é idempotente e não falha para UUID não bloqueado', () {
      expect(
        () => lockService.releaseLock('caso-inexistente'),
        returnsNormally,
      );
      expect(lockService.isLocked('caso-inexistente'), isFalse);
    });

    test('suporta múltiplos laudos bloqueados concomitantemente', () {
      lockService.acquireLock('caso-a');
      lockService.acquireLock('caso-b');

      expect(lockService.isLocked('caso-a'), isTrue);
      expect(lockService.isLocked('caso-b'), isTrue);
      expect(lockService.lockedCaseUuids, containsAll(['caso-a', 'caso-b']));

      lockService.releaseLock('caso-a');
      expect(lockService.isLocked('caso-a'), isFalse);
      expect(lockService.isLocked('caso-b'), isTrue);
    });

    test('lockedCaseUuids retorna conjunto imutável protegendo o estado interno', () {
      lockService.acquireLock('caso-seguro');
      final locked = lockService.lockedCaseUuids;

      expect(
        () => locked.add('caso-malicioso'),
        throwsUnsupportedError,
      );
      expect(lockService.isLocked('caso-malicioso'), isFalse);
    });
  });
}
