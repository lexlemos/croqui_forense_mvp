import 'package:flutter/material.dart';
import 'package:croqui_forense_mvp/domain/services/auth_service.dart';
import 'package:croqui_forense_mvp/domain/services/domain_sync_service.dart';
import 'package:croqui_forense_mvp/data/models/usuario_model.dart';
import 'package:croqui_forense_mvp/core/exceptions/auth_exception.dart';

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

  void onSessionExpired() {
    _authService.forceExpireSession();
    _usuario = null;
    _isLogged = false;
    notifyListeners();
  }

  Usuario? get usuario => _usuario;
  bool get isLogged => _isLogged; 
  bool get isLoading => _isLoading;

  Future<void> checkLoginStatus() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      _usuario = await _authService.checkSession();
    } catch (e) {
      _usuario = null;
    } finally {
      _isLoading = false;
      _isLogged = false;
      notifyListeners();
    }
  }

  Future<void> login(String matricula, String pin) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.login(matricula, pin);
      _usuario = _authService.usuario;
      _isLogged = true;
      await _domainSyncService?.syncTiposAchados();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    _usuario = null;
    _isLogged = false;
    notifyListeners();
  }

  Future<void> atualizarPinPrimeiroAcesso(String novoPin) async {
    if (_usuario == null) throw const AuthException("Nenhum usuário logado");

    _isLoading = true;
    notifyListeners();
    try {
      await _authService.trocarPinObrigatorio(_usuario!, novoPin);
      _usuario = _authService.usuario;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}