import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:croqui_forense_mvp/core/theme/app_colors.dart';
import 'package:croqui_forense_mvp/domain/services/sync_service.dart';
import 'package:croqui_forense_mvp/presentation/providers/case_list_provider.dart';

enum SyncState {
  idle,
  loading,
  success,
  error,
}

class SyncProvider extends ChangeNotifier {
  SyncService _syncService;

  SyncState _state = SyncState.idle;
  String? _errorMessage;

  bool _disposed = false;

  static const Duration _kFeedbackDuration = Duration(seconds: 2);

  SyncProvider(this._syncService);

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void updateService(SyncService newService) {
    _syncService = newService;
  }

  SyncState get state => _state;

  String? get errorMessage => _errorMessage;

  bool get isLoading => _state == SyncState.loading;

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

  // 👇 3. Trava de segurança no _setState
  void _setState(SyncState newState, {String? error}) {
    if (_disposed) return; // Aborta se a tela já foi fechada
    
    _state = newState;
    _errorMessage = error;
    notifyListeners();
  }
}

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
        message: 'Laudos sincronizados com sucesso!',
        backgroundColor: AppColors.success,
        icon: Icons.check_circle_outline,
      );
      // Recarrega a biblioteca local para refletir casos sincronizados
      context.read<CaseListProvider>().carregarCasos();
    } else if (provider.state == SyncState.error) {
      _showSnackbar(
        message: provider.errorMessage ?? 'Erro desconhecido na sincronização.',
        backgroundColor: AppColors.error,
        icon: Icons.error_outline,
      );
      // Recarrega casos sincronizados parcialmente com sucesso
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