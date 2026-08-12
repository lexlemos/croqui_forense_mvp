import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:croqui_forense_mvp/domain/services/auth_service.dart';
import 'package:croqui_forense_mvp/domain/services/domain_sync_service.dart';
import 'package:croqui_forense_mvp/data/models/usuario_model.dart';
import 'package:croqui_forense_mvp/core/utils/globals.dart';
import 'package:croqui_forense_mvp/presentation/providers/case_list_provider.dart';
import 'package:croqui_forense_mvp/presentation/providers/user_management_provider.dart';
import 'package:croqui_forense_mvp/presentation/providers/sync_provider.dart';

class AuthProvider extends ChangeNotifier {
  AuthService _authService;
  DomainSyncService? _domainSyncService;
  Usuario? _usuario;
  bool _isLoading = false;
  bool _isLogged = false;

  AuthProvider(this._authService);

  void updateService(AuthService newService) {
    _authService = newService;
  }

  void updateDomainSyncService(DomainSyncService service) {
    _domainSyncService = service;
  }

  void onSessionExpired([BuildContext? context]) {
    _authService.forceExpireSession();
    _usuario = null;
    _isLogged = false;
    _limparMemoriaEController(context);
    notifyListeners();
    _redirecionarParaLogin(context);
  }

  Usuario? get usuario => _usuario;
  bool get isLogged => _isLogged; 
  bool get isLoading => _isLoading;

  Future<void> checkLoginStatus() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      _usuario = await _authService.checkSession();
      _isLogged = _usuario != null;
    } catch (e) {
      _usuario = null;
      _isLogged = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> login(String login, String senha) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.login(login, senha);
      _usuario = _authService.usuario;
      _isLogged = true;
      await _domainSyncService?.syncTiposAchados();
      await _domainSyncService?.syncAtns();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout([BuildContext? context]) async {
    final targetContext = context ?? globalMessengerKey.currentContext;
    await _authService.logout();
    _usuario = null;
    _isLogged = false;
    // ignore: use_build_context_synchronously
    _limparMemoriaEController(targetContext);
    notifyListeners();
    // ignore: use_build_context_synchronously
    _redirecionarParaLogin(targetContext);
  }

  void _limparMemoriaEController(BuildContext? context) {
    final ctx = globalNavigatorKey.currentContext ?? context ?? globalMessengerKey.currentContext;
    if (ctx != null && ctx.mounted) {
      try {
        ctx.read<CaseListProvider>().clear();
      } catch (e) {
        debugPrint('[AuthProvider] Erro ao limpar CaseListProvider no logout: $e');
      }
      try {
        ctx.read<UserManagementProvider>().clear();
      } catch (e) {
        debugPrint('[AuthProvider] Erro ao limpar UserManagementProvider no logout: $e');
      }
      try {
        ctx.read<SyncProvider>().clear();
      } catch (e) {
        debugPrint('[AuthProvider] Erro ao limpar SyncProvider no logout: $e');
      }
    }
  }

  void _redirecionarParaLogin([BuildContext? context]) {
    final nav = globalNavigatorKey.currentState;
    if (nav != null) {
      nav.pushNamedAndRemoveUntil('/login', (Route<dynamic> route) => false);
    } else if (context != null && context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (Route<dynamic> route) => false);
    }
  }


  Future<void> saveSavedLogin(String login) async {
    await _authService.saveSavedLogin(login);
  }

  Future<String?> getSavedLogin() async {
    return await _authService.getSavedLogin();
  }
}