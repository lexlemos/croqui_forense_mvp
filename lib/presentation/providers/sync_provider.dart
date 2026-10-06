import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:croqui_forense_mvp/core/exceptions/auth_exception.dart';
import 'package:croqui_forense_mvp/core/platform/safe_wakelock.dart';
import 'package:croqui_forense_mvp/core/theme/app_colors.dart';
import 'package:croqui_forense_mvp/domain/services/sync_service.dart';
import 'package:croqui_forense_mvp/presentation/providers/case_list_provider.dart';

/// Estados operacionais do ciclo de sincronização pericial na camada de apresentação.
enum SyncState {
  /// O sincronizador está ocioso e disponível para novo ciclo.
  idle,

  /// O ciclo de sincronização está em processamento ativo (Health Check -> Pull -> Push).
  loading,

  /// O ciclo de sincronização foi concluído com 100% de sucesso e integridade.
  success,

  /// O ciclo de sincronização concluiu parcialmente (com fotos pendentes ou laudos em conflito).
  partial,

  /// O ciclo falhou totalmente (queda de rede, falha de autenticação ou erro no servidor).
  error,
}

/// Provedor de apresentação encarregado do controle reativo do ciclo de sincronização pericial.
///
/// **Atenção: roda na UI thread.**
///
/// Gerencia a máquina de estados (`idle` -> `loading` -> `success`/`partial`/`error` -> `idle`),
/// garantindo que o perito tenha feedback claro e não-bloqueante através de barras de status
/// e recarregamento automático da listagem de laudos.
class SyncProvider extends ChangeNotifier {
  SyncService _syncService;
  final IWakelockManager _wakelock;

  SyncState _state = SyncState.idle;
  String? _feedbackMessage;
  String? _errorMessage;
  SyncResult? _lastResult;

  bool _disposed = false;
  bool _isExecuting = false;

  static const Duration _kFeedbackDuration = Duration(seconds: 3);

  /// Cria uma nova instância de [SyncProvider], permitindo injetar [wakelockManager]
  /// para testes ou utilizar [SafeWakelock] por padrão (ADR-0001).
  SyncProvider(
    this._syncService, {
    IWakelockManager? wakelockManager,
  }) : _wakelock = wakelockManager ?? SafeWakelock();

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Atualiza a referência de [SyncService] mantendo a integridade reativa.
  void updateService(SyncService newService) {
    _syncService = newService;
  }

  /// Estado atual da sincronização.
  SyncState get state => _state;

  /// Mensagem de retorno informativo para o perito legista.
  String? get feedbackMessage => _feedbackMessage;

  /// Mensagem de erro capturada em caso de falha.
  String? get errorMessage => _errorMessage;

  /// Último resultado analítico produzido pelo serviço de sincronização.
  SyncResult? get lastResult => _lastResult;

  /// Indica se há uma rotina de sincronização em execução no momento.
  bool get isLoading => _state == SyncState.loading;

  /// Dispara a execução do ciclo de sincronização orquestrado pelo [SyncService].
  ///
  /// **Atenção: roda na UI thread.**
  ///
  /// Evita execuções concorrentes duplicadas, transiciona o estado para [SyncState.loading],
  /// captura exceções de rede/autenticação e agenda o retorno suave para [SyncState.idle].
  Future<void> startSync() async {
    if (_isExecuting) return;
    _isExecuting = true;

    _setState(SyncState.loading, feedback: null, error: null);

    await _wakelock.enable();
    try {
      final result = await _syncService.execute();
      _lastResult = result;
      if (result.temPendencias) {
        _setState(SyncState.partial, feedback: result.mensagem);
      } else {
        _setState(SyncState.success, feedback: result.mensagem);
      }
    } on AuthException catch (e) {
      _setState(SyncState.error, error: e.message);
    } on SyncNetworkException catch (e) {
      _setState(SyncState.error, error: e.message);
    } on SyncPushTextualException catch (e) {
      _setState(SyncState.error, error: e.message);
    } on SyncException catch (e) {
      _setState(SyncState.error, error: e.message);
    } catch (e) {
      _setState(
        SyncState.error,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      await _wakelock.disable();
      await Future.delayed(_kFeedbackDuration);
      _setState(SyncState.idle, feedback: null, error: null);
      _isExecuting = false;
    }
  }

  /// Atualiza o estado interno e notifica os ouvintes da árvore de widgets.
  void _setState(SyncState newState, {String? feedback, String? error}) {
    if (_disposed) return;

    _state = newState;
    _feedbackMessage = feedback;
    _errorMessage = error;
    notifyListeners();
  }

  /// Limpa o estado da sincronização durante o logout do usuário.
  void clear() {
    _state = SyncState.idle;
    _feedbackMessage = null;
    _errorMessage = null;
    _lastResult = null;
    _isExecuting = false;
    notifyListeners();
  }
}

/// Botão de acionamento visual da sincronização pericial integrado na barra superior da aplicação.
///
/// **Atenção: roda na UI thread.**
///
/// Monitora o [SyncProvider] para:
/// - Exibir indicador de progresso giratório enquanto a sincronização estiver ativa.
/// - Emitir [SnackBar]s informativos ao término (sucesso, aviso de pendência parcial ou erro).
/// - Notificar o [CaseListProvider] para recarregar a listagem de laudos locais após a sincronização.
class SyncButtonWidget extends StatefulWidget {
  const SyncButtonWidget({super.key});

  @override
  State<SyncButtonWidget> createState() => _SyncButtonWidgetState();
}

class _SyncButtonWidgetState extends State<SyncButtonWidget> {
  SyncProvider? _provider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _provider?.removeListener(_onStateChanged);

    _provider = context.read<SyncProvider>();
    _provider!.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    _provider?.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (!mounted) return;

    final provider = _provider!;

    if (provider.state == SyncState.success) {
      _showSnackbar(
        message:
            provider.feedbackMessage ?? 'Laudos sincronizados com sucesso!',
        backgroundColor: AppColors.success,
        icon: Icons.check_circle_outline,
      );
      context.read<CaseListProvider>().carregarCasos();
    } else if (provider.state == SyncState.partial) {
      _showSnackbar(
        message:
            provider.feedbackMessage ??
            'Sincronização concluída com pendências.',
        backgroundColor: AppColors.warning,
        icon: Icons.warning_amber_rounded,
      );
      context.read<CaseListProvider>().carregarCasos();
    } else if (provider.state == SyncState.error) {
      _showSnackbar(
        message: provider.errorMessage ?? 'Erro na sincronização.',
        backgroundColor: AppColors.error,
        icon: Icons.error_outline,
      );
      context.read<CaseListProvider>().carregarCasos();
    }
  }

  void _showSnackbar({
    required String message,
    required Color backgroundColor,
    required IconData icon,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Selector<SyncProvider, (SyncState, bool)>(
      selector: (_, p) => (p.state, p.isLoading),
      builder: (context, data, _) {
        final (_, isLoading) = data;

        return ElevatedButton.icon(
          onPressed: isLoading
              ? null
              : () => context.read<SyncProvider>().startSync(),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.55),
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

