import 'package:flutter/material.dart';
import 'package:croqui_forense_mvp/data/models/usuario_model.dart';
import 'package:croqui_forense_mvp/data/models/papel_model.dart';
import 'package:croqui_forense_mvp/domain/services/user_service.dart';

class UserManagementProvider extends ChangeNotifier {
  final UserService _userService;

  List<Usuario> _usuarios = [];
  List<Papel> _papeis = [];
  
  bool _isLoading = false;
  String? _erro;
  
  int _currentPage = 0;
  int _totalItems = 0;
  String _searchQuery = '';

  // Getters
  List<Usuario> get usuarios => _usuarios;
  List<Papel> get papeis => _papeis;
  bool get isLoading => _isLoading;
  String? get erro => _erro;
  bool get temMaisPaginas => _usuarios.length < _totalItems;

  UserManagementProvider(this._userService);

  Future<void> inicializar() async {
    _isLoading = true;
    _erro = null;
    notifyListeners();

    try {
      if (_papeis.isEmpty) {
        _papeis = await _userService.listarPapeis();
      }
      await _carregarPagina(reset: true);
    } catch (e) {
      _erro = 'Erro ao inicializar: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    inicializar(); 
  }
  Future<void> carregarMais() async {
    if (_isLoading || !temMaisPaginas) return;
    
    _isLoading = true;
    notifyListeners();
    
    try {
      _currentPage++;
      await _carregarPagina(reset: false);
    } catch (e) {
      _erro = 'Erro ao carregar mais itens';
      _currentPage--;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _carregarPagina({required bool reset}) async {
    if (reset) {
      _currentPage = 0;
      _usuarios = [];
    }

    final resultado = await _userService.listarUsuarios(
      page: _currentPage,
      query: _searchQuery,
    );

    final novosUsuarios = resultado['lista'] as List<Usuario>;
    _totalItems = resultado['total'] as int;

    if (reset) {
      _usuarios = novosUsuarios;
    } else {
      _usuarios.addAll(novosUsuarios);
    }
  }

  Future<void> criarUsuario({
    required String nome,
    required String matricula,
    required String papelId,
    required String pinInicial,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _userService.cadastrarNovoUsuario(
        nome: nome,
        matricula: matricula,
        papelId: papelId,
        pinInicial: pinInicial,
      );
      await inicializar();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }
  Future<void> toggleStatusUsuario(Usuario usuario, String idLogado) async {
    try {
      await _userService.alternarStatusUsuario(
        usuarioAlvo: usuario, 
        idUsuarioLogado: idLogado
      );
      final index = _usuarios.indexWhere((u) => u.id == usuario.id);
      if (index != -1) {
        final atual = _usuarios[index];
        _usuarios[index] = Usuario(
          id: atual.id,
          matriculaFuncional: atual.matriculaFuncional,
          nomeCompleto: atual.nomeCompleto,
          papelId: atual.papelId,
          ativo: !atual.ativo,
          hashPinOffline: atual.hashPinOffline,
          deveAlterarPin: atual.deveAlterarPin,
          salt: atual.salt,
          criadoEm: atual.criadoEm,
        );
        notifyListeners();
      }
    } catch (e) {
      rethrow;
    }
  }
}