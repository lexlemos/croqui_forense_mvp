import 'package:flutter/material.dart';
import 'package:croqui_forense_mvp/domain/services/auth_service.dart';
import 'package:croqui_forense_mvp/data/models/usuario_model.dart';
import 'package:croqui_forense_mvp/core/exceptions/auth_exception.dart';

class AuthProvider extends ChangeNotifier {
  AuthService _authService;
  Usuario? _usuario;
  bool _isLoading = true;

  AuthProvider(this._authService) {
    _init();
  }


  void updateService(AuthService newService) {
    _authService = newService;
  }

  Usuario? get usuario => _usuario;

  bool get isLogged => _usuario != null; 
  bool get isAuthenticated => _usuario != null;
  bool get isLoading => _isLoading;

  Future<void> _init() async {
    try {
      _usuario = await _authService.checkSession();
    } catch (e) {
      _usuario = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  Future<void> checkLoginStatus() async {
    if (_usuario == null) {
      await _init();
    }
  }

  Future<void> login(String matricula, String pin) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.login(matricula, pin);
      _usuario = _authService.usuario; 
      _isLoading = false;
      notifyListeners();
    } on AuthException catch (_) {
      _isLoading = false;
      notifyListeners();
      rethrow; 
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      throw AuthException('Erro inesperado no login : $e');
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

      _usuario = await _authService.checkSession(); 
      
      notifyListeners();
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}