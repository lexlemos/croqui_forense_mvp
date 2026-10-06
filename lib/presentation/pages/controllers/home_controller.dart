import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:croqui_forense_mvp/data/repositories/caso_repository.dart';
import 'package:croqui_forense_mvp/presentation/providers/auth_provider.dart';
import 'package:croqui_forense_mvp/presentation/providers/case_list_provider.dart';
import 'package:croqui_forense_mvp/presentation/widgets/home/new_case_dialog.dart';
import 'package:croqui_forense_mvp/presentation/widgets/home/case_filter_dialog.dart';
import 'package:croqui_forense_mvp/presentation/pages/croqui_page.dart';
import 'package:croqui_forense_mvp/core/utils/globals.dart';

import 'package:croqui_forense_mvp/data/models/protocolo_lookup_model.dart';
import 'package:croqui_forense_mvp/domain/services/case_service.dart';

/// Controlador de apresentação da tela inicial (*Home*), gerenciando busca textual,
/// filtros periciais avançados, lookup automatizado de dados por PIC e o fluxo de abertura de novo laudo.
class HomeController extends ChangeNotifier {
  /// Controlador de texto do campo de busca rápida de laudos na lista.
  final searchController = TextEditingController();
  CaseService? _caseService;

  bool _isFetchingPic = false;

  /// Indica se há uma requisição de consulta de PIC em andamento no momento.
  bool get isFetchingPic => _isFetchingPic;

  String _lastSearchedPic = '';

  bool _isDisposed = false;

  /// Inicializa os listeners de busca e dispara a rotina assíncrona de expurgo de laudos antigos em background.
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

  /// Libera os recursos alocados pelos controladores prevenindo vazamentos de memória.
  @override
  void dispose() {
    _isDisposed = true;
    searchController.dispose();
    super.dispose();
  }

  /// **Atenção: roda na UI thread.**
  ///
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
  /// Realiza a busca inicial de dados pelo PIC e autopreencha os controladores informados.
  /// Retorna o [ProtocoloLookupModel] recebido ou `null` caso não seja encontrado.
  Future<ProtocoloLookupModel?> buscarDadosIniciais(
    String pic, {
    required BuildContext context,
    required TextEditingController requisicaoCtrl,
    required TextEditingController boCtrl,
    required TextEditingController autoridadeCtrl,
    required TextEditingController delegaciaCtrl,
    required TextEditingController declaracaoCtrl,
    TextEditingController? destinoCtrl,
    TextEditingController? vitimaCtrl,
    bool forcar = false,
  }) async {
    final sanitizedPic = pic.trim();
    if (_isDisposed ||
        sanitizedPic.isEmpty ||
        _isFetchingPic ||
        (!forcar && sanitizedPic == _lastSearchedPic)) {
      return null;
    }

    _isFetchingPic = true;
    _lastSearchedPic = sanitizedPic;
    notifyListeners();

    try {
      final dto = await _caseService?.getDadosPorPic(sanitizedPic);

      if (_isDisposed || !context.mounted) return null;

      if (dto == null) {
        _lastSearchedPic = '';
        globalMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text(
              'Rede instável ou protocolo não localizado. Continue o preenchimento manual.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return null;
      }

      if (boCtrl.text.isEmpty && dto.numeroBo != null) {
        boCtrl.text = dto.numeroBo!;
      }

      if (requisicaoCtrl.text.isEmpty && dto.numeroRequisicao != null) {
        requisicaoCtrl.text = dto.numeroRequisicao!;
      }

      if (autoridadeCtrl.text.isEmpty && dto.requisitante != null) {
        autoridadeCtrl.text = dto.requisitante!;
      }

      if (delegaciaCtrl.text.isEmpty && dto.delegaciaSolicitante != null) {
        delegaciaCtrl.text = dto.delegaciaSolicitante!;
      }

      if (declaracaoCtrl.text.isEmpty && dto.numeroDeclaracaoObito != null) {
        declaracaoCtrl.text = dto.numeroDeclaracaoObito!;
      }

      if (destinoCtrl != null && destinoCtrl.text.isEmpty && dto.destinoLaudo != null) {
        destinoCtrl.text = dto.destinoLaudo!;
      }

      if (vitimaCtrl != null && vitimaCtrl.text.isEmpty && dto.nomeVitima != null) {
        vitimaCtrl.text = dto.nomeVitima!;
      }

      return dto;
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

  /// **Atenção: roda na UI thread.**
  ///
  /// Exibe o diálogo modal de criação de novo laudo ([NewCaseDialog]) e orquestra
  /// a inserção do registro inicial com abertura direta da tela de croqui ([CroquiPage]).
  Future<void> iniciarNovoCaso(BuildContext context) async {
    resetBuscaPic();
    final dadosRetornados = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => NewCaseDialog(controller: this),
    );

    if (dadosRetornados != null) {
      final String? uuid = dadosRetornados['uuid'];
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
          uuid: uuid,
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

  /// **Atenção: roda na UI thread.**
  ///
  /// Abre o diálogo modal de filtros e ordenação avançada ([CaseFilterDialog]),
  /// repassando os critérios selecionados para o [CaseListProvider].
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

  /// Cria o caso localmente e navega imediatamente para a tela de edição do [CroquiPage].
  Future<void> _criarCaso({
    String? uuid,
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
        uuid: uuid,
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
