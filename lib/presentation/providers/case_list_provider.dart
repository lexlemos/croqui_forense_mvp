import 'package:flutter/material.dart';
import 'package:croqui_forense_mvp/data/models/caso_model.dart';
import 'package:croqui_forense_mvp/data/models/usuario_model.dart';
import 'package:croqui_forense_mvp/data/models/evidencia_multimidia_model.dart';
import 'package:croqui_forense_mvp/domain/services/case_service.dart';
import 'package:croqui_forense_mvp/domain/services/sync_service.dart';

class CaseListProvider extends ChangeNotifier {
  CaseService _caseService;
  SyncService? _syncService;

  List<Caso> _todosCasos = [];
  List<Caso> _casosFiltrados = [];
  bool _isLoading = false;
  String? _erro;

  String _searchQuery = '';
  SortCriteria _sortCriteria = SortCriteria.data;
  SortOrder _sortOrder = SortOrder.desc;
  Set<StatusCaso> _statusFilter = {
    StatusCaso.rascunho,
    StatusCaso.laudo_pendente,
    StatusCaso.finalizado,
    StatusCaso.sincronizado,
  };

  List<Caso> get casos => _casosFiltrados;
  List<Caso> get casosEmAndamento => _casosFiltrados
      .where((c) => c.status == StatusCaso.rascunho || c.status == StatusCaso.laudo_pendente || c.status == StatusCaso.finalizado)
      .toList();
  List<Caso> get casosSincronizados => _casosFiltrados
      .where((c) => c.status == StatusCaso.sincronizado)
      .toList();

  bool get isLoading => _isLoading;
  String? get erro => _erro;
  
  SortCriteria get sortCriteria => _sortCriteria;
  SortOrder get sortOrder => _sortOrder;
  List<StatusCaso> get statusFilter => List.unmodifiable(_statusFilter);

  CaseListProvider(this._caseService, {SyncService? syncService})
      : _syncService = syncService;
  
  void updateService(CaseService newService) {
    _caseService = newService;
  }

  void updateServices({required CaseService caseService, SyncService? syncService}) {
    _caseService = caseService;
    _syncService = syncService;
  }

  Future<Caso> criarCaso({
    required Usuario criador,
    required String numeroLaudo,
    required Map<String, dynamic> dadosIniciais,
    required String numeroPic,
    required String numeroBo,
    required String numeroRequisicao,
    required String nomeVitima,
    required String destino,
    required String requisitante,
    required List<dynamic> fotosGerais,
  }) async {
    final novoCaso = await _caseService.createNewCase(
      criador: criador,
      numeroLaudo: numeroLaudo,
      dadosIniciais: dadosIniciais,
      numeroPic: numeroPic,
      numeroBo: numeroBo,
      numeroRequisicao: numeroRequisicao,
      nomeVitima: nomeVitima,
      destino: destino,
      requisitante: requisitante,
    );

    final List<EvidenciaMultimidia> evidencias = [];
    for (final foto in fotosGerais) {
      final Map<String, dynamic> map = Map<String, dynamic>.from(foto as Map);
      evidencias.add(
        EvidenciaMultimidia.novo(
          casoUuid: novoCaso.uuid,
          tipo: 'GERAL',
          caminhoArquivoEncriptado: map['path'],
          descricao: map['descricao'],
        ),
      );
    }
    await _caseService.salvarCasoComEvidenciasLote(novoCaso, evidencias);

    // Dispara push silencioso em background sem travar a UI
    _syncService?.pushCasoRascunho(novoCaso).catchError((e) {
      debugPrint('Erro ao fazer push silencioso do rascunho: $e');
    });

    await carregarCasos();
    return novoCaso;
  }

  Future<void> carregarCasos() async {
    if (_isLoading) return;
    _isLoading = true;
    _erro = null;
    notifyListeners();

    try {
      _todosCasos = await _caseService.listarCasos();
      _aplicarFiltros(); 
    } catch (e) {
      _erro = e.toString();
    } finally {
      if (_isLoading) {
        _isLoading = false;
        notifyListeners();
      }
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