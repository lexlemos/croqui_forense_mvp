import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:croqui_forense_mvp/data/repositories/caso_repository.dart';
import 'package:croqui_forense_mvp/presentation/providers/auth_provider.dart';
import 'package:croqui_forense_mvp/presentation/providers/case_list_provider.dart';
import 'package:croqui_forense_mvp/presentation/widgets/home/new_case_dialog.dart';
import 'package:croqui_forense_mvp/presentation/widgets/home/case_filter_dialog.dart';
import 'package:croqui_forense_mvp/presentation/pages/croqui_page.dart';
import 'package:croqui_forense_mvp/core/utils/globals.dart';

import 'package:croqui_forense_mvp/domain/services/case_service.dart';

class HomeController extends ChangeNotifier {
  final searchController = TextEditingController();
  CaseService? _caseService;

  bool _isFetchingPic = false;
  bool get isFetchingPic => _isFetchingPic;

  String _lastSearchedPic = '';

  bool _isDisposed = false;

  void init(BuildContext context) {
    _caseService = context.read<CaseService>();
    final casoRepo = context.read<CasoRepository>();
    searchController.addListener(() {
      context.read<CaseListProvider>().setSearchQuery(searchController.text);
    });

    Future.microtask(() async {
      try {
        await casoRepo.expurgarCasosAntigos();
      } catch (e, stackTrace) {
        debugPrint(
          '[HomeController] ❌ Erro ao disparar expurgo em background: $e\n$stackTrace',
        );
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    searchController.dispose();
    super.dispose();
  }

  /// Busca dados burocráticos associados ao número do PIC no serviço remoto.
  ///
  /// Executa o autopreenchimento seguro sem sobrescrever valores já preenchidos
  /// pelo perito e sem bloquear a interação do usuário.
  ///
  /// [context] é obrigatório porque os `TextEditingController`s recebidos
  /// pertencem ao [NewCaseDialog]: se o modal for fechado durante a requisição,
  /// eles já terão sido descartados e não podem mais ser escritos.
  ///
  /// Em caso de falha, o cache `_lastSearchedPic` é liberado para permitir
  /// nova tentativa pela lupa sem precisar alterar o PIC.
  Future<void> buscarDadosIniciais(
    String pic, {
    required BuildContext context,
    required TextEditingController requisicaoCtrl,
    required TextEditingController boCtrl,
    required TextEditingController autoridadeCtrl,
    required TextEditingController delegaciaCtrl,
    required TextEditingController declaracaoCtrl,
    bool forcar = false,
  }) async {
    final sanitizedPic = pic.trim();
    if (_isDisposed ||
        sanitizedPic.isEmpty ||
        _isFetchingPic ||
        (!forcar && sanitizedPic == _lastSearchedPic)) {
      return;
    }

    _isFetchingPic = true;
    _lastSearchedPic = sanitizedPic;
    notifyListeners();

    try {
      final res = await _caseService?.getDadosPorPic(sanitizedPic);

      if (_isDisposed || !context.mounted) return;

      if (res == null) {
        _lastSearchedPic = '';
        globalMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text(
              'Rede instável ou PIC não localizado. Continue o preenchimento manual.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final boValue = res['numero_bo'] ?? res['bo'];
      if (boCtrl.text.isEmpty && boValue != null) {
        boCtrl.text = boValue.toString();
      }

      final reqValue =
          res['numero_requisicao'] ??
          res['requisicao'] ??
          res['cd'] ??
          res['numero_laudo'];
      if (requisicaoCtrl.text.isEmpty && reqValue != null) {
        requisicaoCtrl.text = reqValue.toString();
      }

      final autoridadeValue =
          res['requisitante'] ??
          res['autoridade'] ??
          res['autoridade_requisitante'];
      if (autoridadeCtrl.text.isEmpty && autoridadeValue != null) {
        autoridadeCtrl.text = autoridadeValue.toString();
      }

      final delegaciaValue =
          res['delegacia_solicitante'] ??
          res['delegacia'] ??
          res['delegacia_origem'];
      if (delegaciaCtrl.text.isEmpty && delegaciaValue != null) {
        delegaciaCtrl.text = delegaciaValue.toString();
      }

      final declaracaoValue =
          res['numero_declaracao_obito'] ??
          res['declaracao_obito'] ??
          res['numero_do'];
      if (declaracaoCtrl.text.isEmpty && declaracaoValue != null) {
        declaracaoCtrl.text = declaracaoValue.toString();
      }
    } finally {
      _isFetchingPic = false;
      if (!_isDisposed) notifyListeners();
    }
  }

  /// Limpa o cache de busca de PIC para que cada novo caso comece sem
  /// bloqueio de buscas idênticas feitas em diálogos anteriores.
  void resetBuscaPic() {
    _lastSearchedPic = '';
  }

  Future<void> iniciarNovoCaso(BuildContext context) async {
    resetBuscaPic();
    final dadosRetornados = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => NewCaseDialog(controller: this),
    );

    if (dadosRetornados != null) {
      final String numero = dadosRetornados['numero_laudo'] ?? '';
      final String numeroPic = dadosRetornados['numero_pic'] ?? '';
      final String numeroBo = dadosRetornados['numero_bo'] ?? '';
      final String numeroRequisicao =
          dadosRetornados['numero_requisicao'] ?? '';
      final String nomeVitima = dadosRetornados['nome_vitima'] ?? '';
      final String destino = dadosRetornados['destino'] ?? '';
      final String requisitante = dadosRetornados['requisitante'] ?? '';
      final String delegaciaSolicitante =
          dadosRetornados['delegacia_solicitante'] ?? '';
      final String numeroDeclaracaoObito =
          dadosRetornados['numero_declaracao_obito'] ?? '';
      final Map<String, dynamic> conteudoJson =
          dadosRetornados['dados_laudo'] ?? {};
      final List<dynamic> fotosGerais = dadosRetornados['fotos_gerais'] ?? [];
      final List<String> atnsIds = dadosRetornados['atns_ids'] is List
          ? List<String>.from(dadosRetornados['atns_ids'])
          : [];

      if (context.mounted) {
        await _criarCaso(
          context: context,
          numeroLaudo: numero,
          dadosLaudo: conteudoJson,
          numeroPic: numeroPic,
          numeroBo: numeroBo,
          numeroRequisicao: numeroRequisicao,
          nomeVitima: nomeVitima,
          destino: destino,
          requisitante: requisitante,
          delegaciaSolicitante: delegaciaSolicitante,
          numeroDeclaracaoObito: numeroDeclaracaoObito,
          fotosGerais: fotosGerais,
          atnsIds: atnsIds,
        );
      }
    }
  }

  Future<void> abrirFiltro(BuildContext context) async {
    final provider = context.read<CaseListProvider>();

    final result = await showDialog<FilterResult>(
      context: context,
      builder: (_) => CaseFilterDialog(
        currentCriteria: provider.sortCriteria,
        currentOrder: provider.sortOrder,
        currentStatuses: provider.statusFilter,
      ),
    );

    if (result != null) {
      provider.aplicarFiltrosAvancados(
        criterio: result.sortCriteria,
        ordem: result.sortOrder,
        status: result.selectedStatuses,
      );
    }
  }

  Future<void> _criarCaso({
    required BuildContext context,
    required String numeroLaudo,
    required Map<String, dynamic> dadosLaudo,
    required String numeroPic,
    required String numeroBo,
    required String numeroRequisicao,
    required String nomeVitima,
    required String destino,
    required String requisitante,
    String? delegaciaSolicitante,
    String? numeroDeclaracaoObito,
    required List<dynamic> fotosGerais,
    required List<String> atnsIds,
  }) async {
    try {
      final usuario = context.read<AuthProvider>().usuario;
      if (usuario == null) return;
      final novoCaso = await context.read<CaseListProvider>().criarCaso(
        criador: usuario,
        numeroLaudo: numeroLaudo,
        dadosIniciais: dadosLaudo,
        numeroPic: numeroPic,
        numeroBo: numeroBo,
        numeroRequisicao: numeroRequisicao,
        nomeVitima: nomeVitima,
        destino: destino,
        requisitante: requisitante,
        delegaciaSolicitante: delegaciaSolicitante,
        numeroDeclaracaoObito: numeroDeclaracaoObito,
        fotosGerais: fotosGerais,
        atnsIds: atnsIds,
      );

      if (!context.mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => CroquiPage(caso: novoCaso)),
      );

      if (!context.mounted) return;
      context.read<CaseListProvider>().carregarCasos();
    } catch (e) {
      globalMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
      );
    }
  }
}
