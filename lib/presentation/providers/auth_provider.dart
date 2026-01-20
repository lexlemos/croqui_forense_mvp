import 'package:flutter/material.dart';
import 'package:croqui_forense_mvp/domain/services/auth_service.dart';
import 'package:croqui_forense_mvp/data/models/usuario_model.dart';
import 'package:croqui_forense_mvp/core/exceptions/auth_exception.dart';

class AuthProvider extends ChangeNotifier {
  AuthService _authService;
  Usuario? _usuario;
  bool _isLoading = false; 

  AuthProvider(this._authService);

  void updateService(AuthService newService) {
    _authService = newService;
  }

  Usuario? get usuario => _usuario;
  bool get isLogged => _usuario != null; 
  bool get isLoading => _isLoading;

  Future<void> checkLoginStatus() async {
    _isLoading = true;
    
    try {
      _usuario = await _authService.checkSession();
    } catch (e) {
      _usuario = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> login(String matricula, String pin) async {
    _isLoading = true;
    notifyListeners(); 

    try {
      await _authService.login(matricula, pin);
      _usuario = _authService.usuario; 
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners(); 
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    _usuario = null;
    notifyListeners();
  }

Future<void> atualizarPinPrimeiroAcesso(String novoPin) async {
    if (_usuario == null) throw AuthException("Nenhum usuário logado");

    _isLoading = true;
    notifyListeners();
    try {
      await _authService.trocarPinObrigatorio(_usuario!, novoPin);
      _usuario = _authService.usuario; 
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners(); 
    }
  }
}