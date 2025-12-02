import 'package:flutter/material.dart';
import 'package:croqui_forense_mvp/domain/services/auth_service.dart';
import 'package:croqui_forense_mvp/data/models/usuario_model.dart';

class AuthProvider extends ChangeNotifier {
  AuthService _authService;
  
  Usuario? _usuarioLogado;
  bool _isLoading = false;

  Usuario? get usuario => _usuarioLogado;
  bool get isAuthenticated => _usuarioLogado != null;
  bool get isLoading => _isLoading;

  AuthProvider(this._authService);

  void update(AuthService newService) {
    _authService = newService;
  }

  Future<void> checkSession() async {
    _setLoading(true);
    try {
      final isLogged = await _authService.isLogged();
      if (isLogged) {
        // TODO: Para o MVP V1, se tiver sessão, precisaremos buscar o usuário completo no banco.
        // Por enquanto, se tiver sessão, vamos forçar o logout para garantir integridade ou 
        // implementar o 'getUsuarioById' no futuro.
        // Para este passo, deixaremos como 'não logado' se não tivermos o objeto completo em memória.
      }
    } catch (e) {
      debugPrint('Erro ao verificar sessão: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<String?> login(String matricula, String pin) async {
    _setLoading(true);
    try {
      final user = await _authService.login(matricula, pin);
      
      if (user != null) {
        _usuarioLogado = user;
        notifyListeners();
        return null;
      } else {
        return 'Matrícula ou PIN inválidos.';
      }
    } catch (e) {
      return 'Erro interno: $e';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    _usuarioLogado = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}