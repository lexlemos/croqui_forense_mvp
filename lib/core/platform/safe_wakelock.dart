import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Contrato para controle do ciclo de vida de energia e bloqueio de suspensão da tela.
///
/// Impede que o sistema operacional móvel (Android Doze Mode / LMK) suspenda a CPU
/// e interrompa conexões de rede durante transferências de dados sensíveis e volumosas.
///
/// Consulte ADR-0001 para obter mais detalhes sobre a decisão de arquitetura.
abstract interface class IWakelockManager {
  /// Solicita ao sistema operacional a manutenção do dispositivo em estado ativo (tela/CPU ligadas).
  ///
  /// **Atenção: roda na UI thread.**
  Future<void> enable();

  /// Libera o bloqueio de energia permitindo que o sistema entre em suspensão normal.
  ///
  /// **Atenção: roda na UI thread.**
  Future<void> disable();

  /// Retorna se o wakelock está atualmente habilitado no dispositivo.
  Future<bool> get isEnabled;
}

/// Implementação segura do [IWakelockManager] baseada no plugin `wakelock_plus`.
///
/// Trata e isola falhas de plataforma (ex.: ausência de canal nativo em testes unitários,
/// ambientes desktop sem suporte ou exceções de runtime) para garantir que a sincronização
/// nunca seja abortada por indisponibilidade de wakelock.
class SafeWakelock implements IWakelockManager {
  @override
  Future<void> enable() async {
    try {
      await WakelockPlus.enable();
      debugPrint('[SafeWakelock] ⚡ Wakelock ativado com sucesso.');
    } catch (e) {
      debugPrint('[SafeWakelock] ⚠️ Falha ao ativar wakelock (ignorado de forma segura): $e');
    }
  }

  @override
  Future<void> disable() async {
    try {
      await WakelockPlus.disable();
      debugPrint('[SafeWakelock] 💤 Wakelock liberado com sucesso.');
    } catch (e) {
      debugPrint('[SafeWakelock] ⚠️ Falha ao desativar wakelock (ignorado de forma segura): $e');
    }
  }

  @override
  Future<bool> get isEnabled async {
    try {
      return await WakelockPlus.enabled;
    } catch (e) {
      debugPrint('[SafeWakelock] ⚠️ Falha ao consultar status do wakelock: $e');
      return false;
    }
  }
}
