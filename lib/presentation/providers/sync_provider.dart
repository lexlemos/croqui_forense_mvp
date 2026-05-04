

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:croqui_forense_mvp/core/theme/app_colors.dart';
import 'package:croqui_forense_mvp/domain/services/sync_service.dart';

// =============================================================================
// ESTADO
// =============================================================================

/// Representa os estados possíveis do ciclo de sincronização.
enum SyncState {
  /// Parado — aguardando o perito iniciar a sincronização.
  idle,

  /// Sincronizando — requisição em andamento; UI deve bloquear interação.
  loading,

  /// Concluído com êxito — todos os laudos foram enviados ao servidor.
  success,

  /// Falha — a sincronização foi interrompida por erro de rede ou servidor.
  error,
}

// =============================================================================
// PROVIDER
// =============================================================================

/// Gerencia o estado do processo de sincronização offline → backend.
///
/// Recebe o [SyncService] via construtor (Dependency Injection) e expõe:
/// - [state]: o [SyncState] atual para a UI reagir.
/// - [errorMessage]: a mensagem de erro quando [state] é [SyncState.error].
/// - [startSync]: dispara o ciclo de sincronização de forma assíncrona.
///
/// ### Ciclo de vida do estado
/// ```
/// idle → loading → success → idle  (caminho feliz)
/// idle → loading → error   → idle  (caminho de falha)
/// ```
/// O retorno ao `idle` ocorre automaticamente após [_kFeedbackDuration],
/// permitindo que a UI exiba a mensagem de resultado antes de resetar.
class SyncProvider extends ChangeNotifier {
  SyncService _syncService;

  SyncState _state = SyncState.idle;
  String? _errorMessage;

  /// Duração em que o estado `success` ou `error` fica visível antes do reset.
  static const Duration _kFeedbackDuration = Duration(seconds: 2);

  SyncProvider(this._syncService);

  void updateService(SyncService newService) {
    _syncService = newService;
  }

  // ---------------------------------------------------------------------------
  // Getters públicos
  // ---------------------------------------------------------------------------

  /// Estado atual do ciclo de sincronização.
  SyncState get state => _state;

  /// Mensagem de erro preenchida quando [state] == [SyncState.error].
  /// É `null` nos demais estados.
  String? get errorMessage => _errorMessage;

  /// Atalho: `true` enquanto a sincronização está em andamento.
  bool get isLoading => _state == SyncState.loading;

  // ---------------------------------------------------------------------------
  // Ações
  // ---------------------------------------------------------------------------

  /// Inicia o ciclo completo de sincronização.
  ///
  /// - Muda o estado para [SyncState.loading] e notifica a UI.
  /// - Aguarda [SyncService.execute] concluir.
  /// - Em caso de sucesso → [SyncState.success].
  /// - Em caso de falha   → [SyncState.error] com [errorMessage] preenchido.
  /// - Após [_kFeedbackDuration] → reseta para [SyncState.idle].
  ///
  /// Chamadas enquanto [isLoading] for `true` são ignoradas (guard clause).
  Future<void> startSync() async {
    if (isLoading) return;

    _setState(SyncState.loading, error: null);

    try {
      await _syncService.execute();
      _setState(SyncState.success);
    } catch (e) {
      _setState(
        SyncState.error,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      // Mantém a mensagem de resultado visível na UI antes de resetar.
      await Future.delayed(_kFeedbackDuration);
      _setState(SyncState.idle, error: null);
    }
  }

  // ---------------------------------------------------------------------------
  // Helper interno
  // ---------------------------------------------------------------------------

  void _setState(SyncState newState, {String? error}) {
    _state = newState;
    _errorMessage = error;
    notifyListeners();
  }
}

// =============================================================================
// WIDGET — SyncButtonWidget
// =============================================================================

/// Botão reativo que dispara e acompanha o ciclo de sincronização.
///
/// Deve ser inserido abaixo de um [ChangeNotifierProvider]<[SyncProvider]>
/// na árvore de widgets. Exemplo mínimo:
///
/// ```dart
/// ChangeNotifierProvider(
///   create: (_) => SyncProvider(syncService),
///   child: Scaffold(
///     appBar: AppBar(actions: [SyncButtonWidget()]),
///   ),
/// )
/// ```
///
/// ### Comportamento
/// | Estado          | Ícone                       | Botão     |
/// |---|---|---|
/// | `idle`          | `Icons.sync`                | habilitado|
/// | `loading`       | `CircularProgressIndicator` | desabilitado|
/// | `success`/`error` | `Icons.sync`              | desabilitado|
///
/// Snackbars são exibidos automaticamente ao atingir `success` ou `error`.
class SyncButtonWidget extends StatefulWidget {
  const SyncButtonWidget({super.key});

  @override
  State<SyncButtonWidget> createState() => _SyncButtonWidgetState();
}

class _SyncButtonWidgetState extends State<SyncButtonWidget> {
  /// Referência ao [SyncProvider] usada para cancelar a escuta no dispose.
  SyncProvider? _provider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Cancela a escuta anterior (se houver) antes de reatribuir.
    _provider?.removeListener(_onStateChanged);

    _provider = context.read<SyncProvider>();
    _provider!.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    _provider?.removeListener(_onStateChanged);
    super.dispose();
  }

  /// Chamado sempre que o [SyncProvider] notifica mudança de estado.
  /// Exibe o Snackbar adequado ao atingir `success` ou `error`.
  void _onStateChanged() {
    if (!mounted) return;

    final provider = _provider!;

    if (provider.state == SyncState.success) {
      _showSnackbar(
        message: 'Laudos sincronizados com sucesso!',
        backgroundColor: AppColors.success,
        icon: Icons.check_circle_outline,
      );
    } else if (provider.state == SyncState.error) {
      _showSnackbar(
        message: provider.errorMessage ?? 'Erro desconhecido na sincronização.',
        backgroundColor: AppColors.error,
        icon: Icons.error_outline,
      );
    }
  }

  void _showSnackbar({
    required String message,
    required Color backgroundColor,
    required IconData icon,
  }) {
    // Remove qualquer Snackbar anterior antes de exibir o novo.
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Usa Selector para reconstruir apenas quando state ou isLoading mudam,
    // evitando rebuilds desnecessários causados por outras propriedades.
    return Selector<SyncProvider, (SyncState, bool)>(
      selector: (_, p) => (p.state, p.isLoading),
      builder: (context, data, _) {
        final (_, isLoading) = data;

        return ElevatedButton.icon(
          onPressed: isLoading
              ? null // Desabilitado durante loading/success/error
              : () => context.read<SyncProvider>().startSync(),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            disabledBackgroundColor: AppColors.primary.withOpacity(0.55),
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white70,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: isLoading ? 0 : 2,
          ),
          icon: isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                  ),
                )
              : const Icon(Icons.sync, size: 20),
          label: Text(
            isLoading ? 'Sincronizando...' : 'Sincronizar',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        );
      },
    );
  }
}
