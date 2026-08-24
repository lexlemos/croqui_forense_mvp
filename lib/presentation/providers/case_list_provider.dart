import 'package:flutter/material.dart';
import 'package:croqui_forense_mvp/data/models/caso_model.dart';
import 'package:croqui_forense_mvp/data/models/usuario_model.dart';
import 'package:croqui_forense_mvp/data/models/evidencia_multimidia_model.dart';
import 'package:croqui_forense_mvp/domain/services/auth_service.dart';
import 'package:croqui_forense_mvp/domain/services/case_service.dart';
import 'package:croqui_forense_mvp/domain/services/sync_service.dart';

class CaseListProvider extends ChangeNotifier {
  CaseService _caseService;
  SyncService? _syncService;
  AuthService? _authService;

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

  bool _disposed = false;
  bool get isDisposed => _disposed;

  List<Caso> get casos => _casosFiltrados;

  bool get isLoading => _isLoading;
  String? get erro => _erro;
  
  SortCriteria get sortCriteria => _sortCriteria;
  SortOrder get sortOrder => _sortOrder;
  List<StatusCaso> get statusFilter => List.unmodifiable(_statusFilter);

  CaseListProvider(this._caseService, {SyncService? syncService, AuthService? authService})
      : _syncService = syncService,
        _authService = authService {
    _syncService?.onPullCompleted = () => carregarCasos();
  }

  @override
  void dispose() {
    _disposed = true;
    if (_syncService?.onPullCompleted != null) {
      _syncService?.onPullCompleted = null;
    }
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }
  
  void updateService(CaseService newService) {
    _caseService = newService;
  }

  void updateAuthService(AuthService authService) {
    _authService = authService;
  }

  void updateServices({required CaseService caseService, SyncService? syncService, AuthService? authService}) {
    _caseService = caseService;
    _syncService = syncService;
    _authService = authService;
    _syncService?.onPullCompleted = () => carregarCasos();
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
    required List<String> atnsIds,
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
      atnsIds: atnsIds,
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

  Future<void> carregarCasos([String? usuarioId]) async {
    if (_isLoading || _disposed) return;
    _isLoading = true;
    _erro = null;
    notifyListeners();

    try {
      final uid = usuarioId ?? _authService?.usuario?.id;
      if (uid == null || uid.isEmpty) {
        _todosCasos = [];
        _aplicarFiltros();
        return;
      }
      final result = await _caseService.listarCasos(uid);
      if (_disposed) return;
      _todosCasos = result;
      _aplicarFiltros(); 
    } catch (e) {
      if (!_disposed) {
        _erro = e.toString();
      }
    } finally {
      if (_isLoading && !_disposed) {
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

  /// Limpa todos os dados da memória RAM no momento do logout.
  void clear() {
    _todosCasos = [];
    _casosFiltrados = [];
    _searchQuery = '';
    _erro = null;
    _isLoading = false;
    notifyListeners();
  }
}
