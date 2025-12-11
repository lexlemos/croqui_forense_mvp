import 'package:flutter/material.dart';
import 'package:croqui_forense_mvp/data/models/usuario_model.dart';
import 'package:croqui_forense_mvp/domain/services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;

  Usuario? _usuario;
  bool _isLoading = true; 
  Usuario? get usuario => _usuario;
  bool get isLogged => _usuario != null;
  bool get isLoading => _isLoading;

  AuthProvider(this._authService);
  Future<void> checkLoginStatus() async {
    _isLoading = true;
    notifyListeners(); 

    try {
      final usuarioSalvo = await _authService.checkSession();
      _usuario = usuarioSalvo;
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
      final usuarioLogado = await _authService.login(matricula, pin);
      _usuario = usuarioLogado;
    } on AuthException {
      rethrow;
    } catch (e) {
      throw Exception('Erro inesperado no login.');
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
}