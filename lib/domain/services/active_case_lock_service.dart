/// Contrato para o serviço de controle de concorrência e trava de laudos em edição ativa (Active Case Mutex).
///
/// Previne condições de corrida onde operações em segundo plano (como o Pull de sincronização
/// do [SyncService]) sobrescrevem os dados de um laudo pericial que esteja sendo manipulado
/// ativamente pelo médico-legista na interface do aplicativo.
///
/// Consulte ADR-0002 para obter mais detalhes sobre a decisão de arquitetura.
abstract interface class IActiveCaseLockService {
  /// Registra que o laudo pericial identificado por [casoUuid] entrou em edição ativa.
  ///
  /// **Atenção: roda na UI thread.**
  void acquireLock(String casoUuid);

  /// Libera o bloqueio de edição ativa para o laudo pericial identificado por [casoUuid].
  ///
  /// **Atenção: roda na UI thread.**
  void releaseLock(String casoUuid);

  /// Verifica se o laudo pericial identificado por [casoUuid] está atualmente sob edição ativa.
  bool isLocked(String casoUuid);

  /// Retorna o conjunto imutável de identificadores ([casoUuid]s) atualmente bloqueados.
  Set<String> get lockedCaseUuids;
}

/// Implementação padrão em memória do [IActiveCaseLockService].
///
/// Mantém o rastreamento volátil dos laudos abertos em tela, garantindo que encerramentos
/// abruptos ou falhas de energia não deixem travas fantasmas persistidas no banco local.
class ActiveCaseLockService implements IActiveCaseLockService {
  final Set<String> _lockedCaseUuids = <String>{};

  @override
  void acquireLock(String casoUuid) {
    if (casoUuid.isNotEmpty) {
      _lockedCaseUuids.add(casoUuid);
    }
  }

  @override
  void releaseLock(String casoUuid) {
    _lockedCaseUuids.remove(casoUuid);
  }

  @override
  bool isLocked(String casoUuid) {
    return _lockedCaseUuids.contains(casoUuid);
  }

  @override
  Set<String> get lockedCaseUuids => Set.unmodifiable(_lockedCaseUuids);
}
