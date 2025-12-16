import 'package:flutter/material.dart';
import 'package:croqui_forense_mvp/data/models/caso_model.dart';
import 'package:croqui_forense_mvp/domain/services/case_service.dart';



class CaseListProvider extends ChangeNotifier {
  CaseService _caseService;

  List<Caso> _todosCasos = [];
  List<Caso> _casosFiltrados = [];
  bool _isLoading = false;
  String? _erro;

  String _searchQuery = '';
  SortCriteria _sortCriteria = SortCriteria.data;
  SortOrder _sortOrder = SortOrder.desc;
  Set<StatusCaso> _statusFilter = {StatusCaso.rascunho, StatusCaso.finalizado};

  List<Caso> get casos => _casosFiltrados;
  bool get isLoading => _isLoading;
  String? get erro => _erro;
  
  SortCriteria get sortCriteria => _sortCriteria;
  SortOrder get sortOrder => _sortOrder;
  List<StatusCaso> get statusFilter => List.unmodifiable(_statusFilter);

  CaseListProvider(this._caseService);
  
  void updateService(CaseService newService) {
    _caseService = newService;
  }

  Future<void> carregarCasos() async {
    _isLoading = true;
    _erro = null;
    notifyListeners();

    try {
      _todosCasos = await _caseService.listarCasos();
      _aplicarFiltros(); 
    } catch (e) {
      _erro = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _aplicarFiltros();
    notifyListeners();
  }

  void aplicarFiltrosAvancados({
    required SortCriteria criterio,
    required SortOrder ordem,
    required Set<StatusCaso> status,
  }) {
    _sortCriteria = criterio;
    _sortOrder = ordem;
    _statusFilter = status;
    _aplicarFiltros();
    notifyListeners();
  }

  void _aplicarFiltros() {
    List<Caso> temp = List.from(_todosCasos);

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      temp = temp.where((c) => (c.numeroLaudoExterno ?? '').toLowerCase().contains(q)).toList();
    }

    if (_statusFilter.isNotEmpty) {
      temp = temp.where((c) => _statusFilter.contains(c.status)).toList();
    }

    temp.sort((a, b) {
      int cmp = 0;
      if (_sortCriteria == SortCriteria.data) {
        cmp = a.criadoEmDispositivo.compareTo(b.criadoEmDispositivo);
      } else {
        cmp = (a.numeroLaudoExterno ?? '').compareTo(b.numeroLaudoExterno ?? '');
      }
      return _sortOrder == SortOrder.asc ? cmp : -cmp;
    });

    _casosFiltrados = temp;
  }
}