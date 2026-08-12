import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart'; 

import 'package:croqui_forense_mvp/data/models/caso_model.dart';
import 'package:croqui_forense_mvp/data/models/achado_model.dart';
import 'package:croqui_forense_mvp/data/models/evidencia_multimidia_model.dart';
import 'package:croqui_forense_mvp/data/models/exame_solicitado_model.dart';
import 'package:croqui_forense_mvp/domain/services/achado_service.dart';
import 'package:croqui_forense_mvp/domain/services/case_service.dart';
import 'package:croqui_forense_mvp/presentation/providers/auth_provider.dart';
import 'package:croqui_forense_mvp/core/utils/image_helper.dart';
import 'package:croqui_forense_mvp/domain/services/pdf_service.dart';
import 'package:croqui_forense_mvp/domain/services/pdf_report_service.dart';
import 'package:croqui_forense_mvp/domain/services/sync_service.dart';
import 'package:croqui_forense_mvp/core/utils/globals.dart';
import 'package:croqui_forense_mvp/core/constants/diagram_constants.dart';

import 'package:croqui_forense_mvp/data/models/exames/exame_solicitado_model.dart';
import 'package:croqui_forense_mvp/data/repositories/achado_repository.dart';
import 'package:croqui_forense_mvp/data/repositories/caso_repository.dart';
import 'package:croqui_forense_mvp/data/repositories/injury_type_repository.dart';
import 'package:croqui_forense_mvp/presentation/widgets/forms/injury_form_modal.dart';
import 'package:croqui_forense_mvp/core/constants/front_body_data.dart';
import 'package:croqui_forense_mvp/core/constants/back_body_data.dart';
import 'package:croqui_forense_mvp/core/constants/lateral_right_data.dart' as face_right;
import 'package:croqui_forense_mvp/core/constants/lateral_left_data.dart' as face_left;
import 'package:croqui_forense_mvp/core/constants/lateral_right_body_data.dart' as lat_right;
import 'package:croqui_forense_mvp/data/repositories/atn_repository.dart';
import 'package:croqui_forense_mvp/data/models/atn_model.dart';
import 'package:croqui_forense_mvp/core/constants/lateral_left_body_data.dart' as lat_left;
import 'package:croqui_forense_mvp/core/constants/trunk_right_data.dart' as trunk_right;
import 'package:croqui_forense_mvp/core/constants/trunk_left_data.dart' as trunk_left;
import 'package:croqui_forense_mvp/core/constants/perineal_data.dart' as perineal;

class CroquiController extends ChangeNotifier {
  final AchadoService _achadoService;
  final CaseService _caseService;
  final InjuryTypeRepository _injuryTypeRepository;
  final AchadoRepository _achadoRepository;
  final CasoRepository _casoRepository;
  final AtnRepository _atnRepository;

  Caso casoAtual;
  List<Achado> achados = [];
  List<EvidenciaMultimidia> evidenciasGerais = [];
  List<ExameSolicitado> examesSolicitados = [];
  List<ExameSolicitadoModel> examesSolicitadosModel = [];
  List<AtnModel> atns = [];
  bool isLoading = false;
  bool _isExporting = false;
  bool get isExporting => _isExporting;

  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  bool _isDisposed = false;

  Timer? _autoSaveTimer;
  bool _isAutoSavePending = false;

  final bool? _isReadOnlyInput;
  bool get isReadOnly =>
      (_isReadOnlyInput == true) ||
      casoAtual.status == StatusCaso.finalizado ||
      casoAtual.status == StatusCaso.sincronizado;

  // Form text controllers
  late final TextEditingController numeroLaudoCtrl;
  late final TextEditingController boCtrl;
  late final TextEditingController picCtrl;
  late final TextEditingController reqOrigemCtrl;
  late final TextEditingController reqDestinoCtrl;
  late final TextEditingController nomeVitimaCtrl;
  late final TextEditingController historicoCtrl;
  late final TextEditingController vestesCtrl;
  late final TextEditingController caracteristicasCtrl;
  late final TextEditingController tanatoImediatoCtrl;
  late final TextEditingController tanatoConsecutivoCtrl;
  late final TextEditingController tanatoObservacaoCtrl;
  late final TextEditingController discussaoCtrl;
  late final TextEditingController conclusaoCtrl;
  late final TextEditingController quesito1Ctrl;
  late final TextEditingController quesito2Ctrl;
  late final TextEditingController quesito3Ctrl;
  late final TextEditingController quesito4Ctrl;

  CroquiController(
    this.casoAtual,
    this._achadoService,
    this._caseService,
    this._injuryTypeRepository,
    this._achadoRepository,
    this._casoRepository,
    this._atnRepository, {
    bool? isReadOnly,
  }) : _isReadOnlyInput = isReadOnly {
    scheduleMicrotask(() => _loadAchados());
    _initControllers();
  }

  void _initControllers() {
    final caso = casoAtual;
    final dados = caso.dadosLaudo;

    numeroLaudoCtrl = TextEditingController(text: caso.numeroRequisicao.isNotEmpty ? caso.numeroRequisicao : (caso.numeroLaudoExterno ?? ''));
    boCtrl = TextEditingController(text: caso.numeroBo);
    picCtrl = TextEditingController(text: caso.numeroPic);
    reqOrigemCtrl = TextEditingController(text: caso.requisitante);
    reqDestinoCtrl = TextEditingController(text: caso.destino);
    nomeVitimaCtrl = TextEditingController(text: caso.nomeVitima);

    historicoCtrl = TextEditingController(
      text: dados['identificacao']?['historico'] ?? 
            "Consta em Boletim de Ocorrência de número ${caso.numeroBo} que às XX horas do dia XX de XXX do corrente ano. O fato descrito teria ocorrido na localidade conhecida como XXX."
    );

    vestesCtrl = TextEditingController(text: dados['identificacao']?['vestes'] ?? 'Despido no momento da necrópsia.');
    caracteristicasCtrl = TextEditingController(text: dados['caracteristicas']?['identificacao'] ?? 'Cadáver do sexo XXX, raça XXX, estado nutricional XXX, e idade aparente de XX anos.');
    tanatoImediatoCtrl = TextEditingController(text: dados['caracteristicas']?['tanato_imediato'] ?? 'XXX');
    tanatoConsecutivoCtrl = TextEditingController(text: dados['caracteristicas']?['tanato_consecutivo'] ?? 'XXX');
    tanatoObservacaoCtrl = TextEditingController(text: dados['caracteristicas']?['tanato_observacao'] ?? 'XXX');

    discussaoCtrl = TextEditingController(text: dados['conclusao']?['discussao'] ?? '');
    conclusaoCtrl = TextEditingController(text: dados['conclusao']?['conclusao_texto'] ?? '');

    quesito1Ctrl = TextEditingController(text: dados['conclusao']?['quesito_1_morte'] ?? '');
    quesito2Ctrl = TextEditingController(text: dados['conclusao']?['quesito_2_causa'] ?? '');
    quesito3Ctrl = TextEditingController(text: dados['conclusao']?['quesito_3_instrumento'] ?? '');
    quesito4Ctrl = TextEditingController(text: dados['conclusao']?['quesito_4_meio'] ?? '');
  }

  String _toDeterministicUuidV4(String namespace, String name) {
    final String uuidV5 = const Uuid().v5(namespace, name);
    return '${uuidV5.substring(0, 14)}4${uuidV5.substring(15, 19)}a${uuidV5.substring(20)}';
  }

  Future<void> _loadAchados() async {
    if (isLoading) return;
    isLoading = true;
    notifyListeners();
    try {
      achados = await _achadoService.listarAchados(casoAtual.uuid);
      evidenciasGerais = await _caseService.getEvidenciasGerais(casoAtual.uuid);
      examesSolicitados = await _caseService.getExamesSolicitados(casoAtual.uuid);
      examesSolicitadosModel = await _casoRepository.getExamesPorCaso(casoAtual.uuid);
      atns = await _atnRepository.getAtns();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }



  Future<void> atualizarAtnResponsavel(String? atnId, [String? atnNome]) async {
    String? nome = atnNome;
    String? id = atnId;

    if (id != null && id.isNotEmpty) {
      final match = atns.where((a) => a.id == id || a.nome == id).firstOrNull;
      if (match != null) {
        id = match.id;
        nome = match.nome;
      }
    }

    casoAtual = casoAtual.copyWith(
      atnId: id,
      atnResponsavel: nome ?? id,
      atualizadoEm: DateTime.now(),
    );

    debugPrint('[CroquiController] 🔄 ATN Atualizado na RAIZ do Caso: atn_id=${casoAtual.atnId}, atn_responsavel=${casoAtual.atnResponsavel}');
    debugPrint('[CroquiController] 📦 Payload completo raiz (toSyncMap): ${jsonEncode(casoAtual.toSyncMap())}');

    notifyListeners();
    _scheduleAutoSave();
  }

  Future<void> salvarExamesModel(List<ExameSolicitadoModel> exames) async {
    examesSolicitadosModel = exames;
    await _casoRepository.salvarExames(casoAtual.uuid, exames);
    notifyListeners();
    _scheduleAutoSave();
  }

  List<Achado> getMarkersForView(String view) {
    return achados.where((a) => (a.dadosPreenchidos['view'] ?? '') == view).toList();
  }

  Future<void> addAchado(BuildContext context, String viewType, String partId, double x, double y) async {
    if (isReadOnly) {
      _snack("Caso finalizado. Edição bloqueada.");
      return;
    }
    if (_isProcessing) return;
    _isProcessing = true;
    notifyListeners();

    try {
      try {
        await _caseService.salvarRascunho(casoAtual);
      } catch (e) {
        debugPrint("Erro ao garantir salvamento do caso: $e");
        globalMessengerKey.currentState?.showSnackBar(const SnackBar(content: Text("Erro ao preparar o caso."), backgroundColor: Colors.red));
        return;
      }

      final String realPartName = _resolveBodyPartName(viewType, partId);

      if (!context.mounted) return;

      final result = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        builder: (context) => InjuryFormModal(
          bodyPartName: realPartName,
          injuryTypeRepository: _injuryTypeRepository,
          achadoRepository: _achadoRepository,
          casoUuid: casoAtual.uuid,
        ),
      );

      if (result == null) return;

      final String size = result['size']?.toString() ?? '';
      final String depth = result['depth']?.toString() ?? '';
      final String description = result['description']?.toString() ?? '';
      final String tipoLesaoNome = result['type']?.toString() ?? 'Não especificado';
      final String tipoLesaoId = result['typeId']?.toString() ?? 'outro';
      final bool isInterno = result['isInterno'] ?? false;
      final String? achadoRelacionadoUuid = result['achadoRelacionadoUuid']?.toString();

      String? finalPhotoPath = result['photoPath'];
      if (finalPhotoPath != null) {
        final File compressedFile = await ImageHelper.compressImage(File(finalPhotoPath));
        finalPhotoPath = compressedFile.path;
      }

      final Map<String, dynamic> dadosExtras = {
        'view': viewType,
        'local_anatomico_id': partId,
        'local_anatomico_nome': realPartName,
        'type_label': tipoLesaoNome,
        'size': size,
        'depth': depth,
        'photo_path': finalPhotoPath,
        'is_interno': isInterno,
        if (result['dados_dinamicos_json'] is Map) 'dados_dinamicos_json': result['dados_dinamicos_json'],
      };

      final String diagramaCasoUuid = _toDeterministicUuidV4(casoAtual.uuid, viewType);

      final achadoFinal = Achado(
        uuid: const Uuid().v4(),
        casoUuid: casoAtual.uuid,
        diagramaCasoUuid: diagramaCasoUuid,
        diagramaNome: DiagramTemplates.templateIdParaView(viewType),
        tipoAchadoId: tipoLesaoId,
        achadoRelacionadoUuid: achadoRelacionadoUuid,
        numeroSequencial: achados.length + 1,
        posX: x,
        posY: y,
        isInterno: isInterno,
        dadosPreenchidos: dadosExtras,
        observacoesTexto: description,
        removido: false,
        versao: 1,
        criadoEm: DateTime.now(),
        tamanho: size,
        vistaAnatomica: viewType,
        localAnatomico: realPartName,
      );

      try {
        await _achadoService.salvarAchado(achadoFinal);
        await _loadAchados();
        
        globalMessengerKey.currentState?.hideCurrentSnackBar();
        globalMessengerKey.currentState?.showSnackBar(const SnackBar(content: Text("Achado adicionado!")));
        
      } catch (e) {
        debugPrint("Erro real ao salvar achado: $e");
        globalMessengerKey.currentState?.hideCurrentSnackBar();
        globalMessengerKey.currentState?.showSnackBar(SnackBar(content: Text("Erro ao salvar: $e"), backgroundColor: Colors.red));
      }
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  Future<void> editAchado(BuildContext context, Achado achado) async {
    if (isReadOnly) return;
    if (_isProcessing) return;
    _isProcessing = true;
    notifyListeners();

    try {
      final dados = achado.dadosPreenchidos;
      final String localNome = dados['local_anatomico_nome'] ?? 
                               _resolveBodyPartName(dados['view'], dados['local_anatomico_id'] ?? '');

      final result = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        builder: (context) => InjuryFormModal(
          bodyPartName: localNome,
          injuryTypeRepository: _injuryTypeRepository,
          achadoRepository: _achadoRepository,
          casoUuid: casoAtual.uuid,
          achadoToEdit: achado,
        ),
      );

      if (result == null) return;

      final String size = result['size']?.toString() ?? '';
      final String depth = result['depth']?.toString() ?? '';
      final String description = result['description']?.toString() ?? '';
      final String tipoLesaoNome = result['type']?.toString() ?? achado.type;
      final String tipoLesaoId = result['typeId']?.toString() ?? achado.tipoAchadoId;
      final bool isInterno = result['isInterno'] ?? achado.isInterno;
      final String? achadoRelacionadoUuid = result['achadoRelacionadoUuid']?.toString();

      String? finalPhotoPath = result['photoPath'];
      String? oldPhotoPath = achado.dadosPreenchidos['photo_path'];

      if (finalPhotoPath != null && finalPhotoPath != oldPhotoPath) {
        final File compressedFile = await ImageHelper.compressImage(File(finalPhotoPath));
        finalPhotoPath = compressedFile.path;
      }

      if (!context.mounted) return;

      final Map<String, dynamic> novosDados = Map<String, dynamic>.from(achado.dadosPreenchidos);
      novosDados['type_label'] = tipoLesaoNome;
      novosDados['size'] = size;
      novosDados['depth'] = depth;
      novosDados['photo_path'] = finalPhotoPath;
      novosDados['is_interno'] = isInterno;
      if (result['dados_dinamicos_json'] is Map) {
        novosDados['dados_dinamicos_json'] = result['dados_dinamicos_json'];
      }

      final achadoAtualizado = achado.copyWith(
        tipoAchadoId: tipoLesaoId,
        achadoRelacionadoUuid: achadoRelacionadoUuid,
        isInterno: isInterno,
        dadosPreenchidos: novosDados,
        observacoesTexto: description,
        versao: achado.versao + 1,
        atualizadoEm: DateTime.now(),
        tamanho: size,
        vistaAnatomica: achado.vistaAnatomica,
        localAnatomico: localNome,
      );

      try {
        await _achadoService.atualizarAchado(achadoAtualizado);
        await _loadAchados();
        _snack("Achado atualizado!");
      } catch (e) {
        _snack("Erro ao atualizar: $e", color: Colors.red);
      }
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  Future<void> deleteAchado(BuildContext context, String uuid) async {
    if (isReadOnly) return;
    try {
      await _achadoService.removerAchado(uuid);
      await _loadAchados();
      _snack("Achado removido.");
    } catch (e) {
      _snack("Erro ao deletar", color: Colors.red);
    }
  }


  void atualizarDadosLaudoMemoria(Map<String, dynamic> novosDados) {
    casoAtual = casoAtual.copyWith(
      dadosLaudo: novosDados,
      atualizadoEm: DateTime.now(),
    );
    notifyListeners();
    _scheduleAutoSave();
  }

  Future<void> finalizarCasoDireto(BuildContext context) async {
    if (_isProcessing) return;
    _isProcessing = true;
    notifyListeners();

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);

      // 1. Sincronizar dados em memória (rascunho)
      sincronizarDadosEmMemoria(auth);

      // 2. Validação obrigatória
      if (!validarCamposObrigatorios()) {
        globalMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text("Por favor, responda todos os quesitos obrigatórios."),
            backgroundColor: Colors.orange,
          ),
        );

        try {
          DefaultTabController.of(context).animateTo(6);
        } catch (_) {}
        return;
      }

      final statusAtual = casoAtual.status;

      // Cenário A: Se o status for RASCUNHO, exibe o Modal 1 ("Finalizar Exame Físico?")
      if (statusAtual == StatusCaso.rascunho) {
        final confirmExame = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Finalizar Exame Físico?"),
            content: const Text(
              "A etapa de exame corporal será concluída. Você poderá optar por concluir o laudo agora ou manter pendente para finalizar o texto depois.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Voltar"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text("Sim, prosseguir"),
              ),
            ],
          ),
        );

        if (confirmExame != true) return;
      }

      // Cenário B: Se for LAUDO_PENDENTE, pula o Modal 1 e vai DIRETAMENTE ao Modal 2
      if (!context.mounted) return;
      final opcaoSelecionada = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text("Conclusão do Laudo"),
          content: const Text(
            "Deseja concluir o laudo pericial definitivamente agora (com geração automática do PDF e assinatura) ou deixar pendente?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, "PENDENTE"),
              child: const Text("Deixar Pendente"),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              icon: const Icon(Icons.check_circle),
              label: const Text("Concluir Laudo Agora"),
              onPressed: () => Navigator.pop(ctx, "CONCLUIR"),
            ),
          ],
        ),
      );

      if (opcaoSelecionada == null) return;

      if (opcaoSelecionada == "PENDENTE") {
        await _processarDeixarPendente(context);
      } else if (opcaoSelecionada == "CONCLUIR") {
        await _processarConcluirLaudoAgora(context);
      }
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  Future<void> _processarDeixarPendente(BuildContext context) async {
    try {
      final now = DateTime.now();
      final casoAtualizado = casoAtual.copyWith(
        status: StatusCaso.laudo_pendente,
        atualizadoEm: now,
        isDraftSynced: false,
        versao: casoAtual.versao + 1,
      );

      await _caseService.salvarRascunho(casoAtualizado);
      casoAtual = casoAtualizado;
      notifyListeners();

      _snack("Exame finalizado. Laudo mantido em andamento.", color: Colors.orange[800]);

      if (context.mounted) {
        final syncService = Provider.of<SyncService>(context, listen: false);
        syncService.pushCasoRascunho(casoAtual).catchError((e) {
          debugPrint('[CroquiController] Erro no push em background: $e');
        });
      }
    } catch (e) {
      _snack("Erro ao salvar status pendente: $e", color: Colors.red);
    }
  }

  Future<void> _processarConcluirLaudoAgora(BuildContext context) async {
    // 1. Exibe indicador de carregamento bloqueante
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Expanded(
                child: Text("Gerando laudo PDF e finalizando caso..."),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final usuarioLogado = auth.usuario;

      if (usuarioLogado == null) {
        throw Exception("Usuário não autenticado.");
      }

      await _caseService.salvarRascunho(casoAtual);

      final pdfReportService = PdfReportService();

      // 2. Geração automática do PDF em background
      final pdfBytes = await pdfReportService.gerarLaudoPdf(
        caso: casoAtual,
        achados: achados,
        perito: usuarioLogado,
        exames: examesSolicitados,
        examesModel: examesSolicitadosModel,
        evidenciasGerais: evidenciasGerais,
      );

      // 3. Gravação física do PDF e atualização do pdfLocalPath
      final pdfFilePath = await pdfReportService.salvarPdfNoDispositivo(
        caso: casoAtual,
        pdfBytes: pdfBytes,
        caseService: _caseService,
      );

      // 4. Mudar status para FINALIZADO e gravar pdfLocalPath
      final now = DateTime.now();
      final casoFinalizado = casoAtual.copyWith(
        status: StatusCaso.finalizado,
        pdfLocalPath: pdfFilePath,
        finalizadoEm: now,
        atualizadoEm: now,
        isDraftSynced: false,
        versao: casoAtual.versao + 1,
      );

      // 5. Salva no SQLite
      await _caseService.salvarRascunho(casoFinalizado);
      casoAtual = casoFinalizado;
      notifyListeners();

      // Dispara o push via SyncService (que usará pdfLocalPath para codificar em Base64 no Isolate)
      if (context.mounted) {
        final syncService = Provider.of<SyncService>(context, listen: false);
        syncService.pushCasoRascunho(casoFinalizado).catchError((e) {
          debugPrint('[CroquiController] Erro no push do caso finalizado: $e');
        });

        // 6. Fecha o loading
        Navigator.pop(context);
        _snack("Laudo concluído com sucesso e PDF gerado!", color: Colors.green);

        // Fecha a tela do croqui retornando para a biblioteca
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Erro ao concluir laudo programaticamente: $e");
      if (context.mounted) {
        Navigator.pop(context); // Fecha dialog de loading em erro
      }
      _snack("Erro ao concluir laudo: ${e.toString()}", color: Colors.red);
    }
  }

  Future<void> reabrirCaso(BuildContext context) async {
    try {
      await _caseService.reabrirCaso(casoAtual.uuid);
      final casoAtualizado = await _caseService.buscarCasoPorUuid(casoAtual.uuid);
      if (casoAtualizado != null) {
        casoAtual = casoAtualizado;
      } else {
        casoAtual = casoAtual.copyWith(
          status: StatusCaso.rascunho,
          atualizadoEm: DateTime.now(),
        );
      }
      await _loadAchados();
      notifyListeners();
      _snack("Edição habilitada.");
    } catch (e) {
      globalMessengerKey.currentState?.hideCurrentSnackBar();
      globalMessengerKey.currentState?.showSnackBar(SnackBar(content: Text("Erro ao reabrir: $e"), backgroundColor: Colors.red));
    }
  }
  Future<void> exportarCaso(BuildContext context) async {
    if (_isProcessing) return;
    _isProcessing = true;
    notifyListeners();

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final usuarioLogado = auth.usuario;

    if (usuarioLogado == null) {
      globalMessengerKey.currentState?.showSnackBar(const SnackBar(content: Text("Usuário não autenticado."), backgroundColor: Colors.red));
      _isProcessing = false;
      notifyListeners();
      return;
    }

    _snack("Gerando laudo PDF oficial...");

    File? tempPdfFile;
    try {
      if (!isReadOnly) {
        await _caseService.salvarRascunho(casoAtual);
      }

      final injuryTypes = await _injuryTypeRepository.getAllTypes();
      final Map<String, dynamic> schemas = {
        for (var t in injuryTypes) t.id: t.schemaFormulario
      };

      final pdfBytes = await PdfService().gerarLaudoPdf(
        caso: casoAtual,
        achados: achados,
        perito: usuarioLogado,
        schemas: schemas,
        exames: examesSolicitados,
        examesModel: examesSolicitadosModel,
        evidenciasGerais: evidenciasGerais,
      );

      final tempDir = await getTemporaryDirectory();
      final String safeNum = (casoAtual.numeroLaudoExterno ?? 'sem-numero').replaceAll('/', '-');
      tempPdfFile = File("${tempDir.path}/laudo_$safeNum.pdf");
      
      await tempPdfFile.writeAsBytes(pdfBytes, flush: true);

      if (!context.mounted) return;
      globalMessengerKey.currentState?.hideCurrentSnackBar();

      await Share.shareXFiles(
        [XFile(tempPdfFile.path)],
        subject: 'Laudo Pericial PDF - ${casoAtual.numeroLaudoExterno}',
      );

    } catch (e) {
      debugPrint("Erro na exportação do PDF: $e");
      globalMessengerKey.currentState?.hideCurrentSnackBar();
      globalMessengerKey.currentState?.showSnackBar(SnackBar(content: Text("Erro ao gerar PDF: ${e.toString()}"), backgroundColor: Colors.red));
    } finally {
      if (tempPdfFile != null && tempPdfFile.existsSync()) {
        try {
          await tempPdfFile.delete();
          debugPrint('[CroquiController] 🧹 PDF temporário de exportação limpo: ${tempPdfFile.path}');
        } catch (_) {}
      }
      _isProcessing = false;
      notifyListeners();
    }
  }

  String get sexoDoExaminado {
    final dadosId = casoAtual.dadosLaudo['identificacao'];
    if (dadosId != null && dadosId['sexo'] != null) {
      final s = dadosId['sexo'].toString().trim().toLowerCase();
      return s.startsWith('f') ? 'Feminino' : 'Masculino';
    }
    final caracteristicas = dadosId?['caracteristicas']?.toString().toLowerCase() ?? '';
    if (caracteristicas.contains('feminino') || caracteristicas.contains('mulher')) {
      return 'Feminino';
    }
    if (caracteristicas.contains('masculino') || caracteristicas.contains('homem')) {
      return 'Masculino';
    }
    return 'Indeterminado'; 
  }

  Future<void> alterarSexoExaminado(BuildContext context, String novoSexo) async {
    final novosDados = Map<String, dynamic>.from(casoAtual.dadosLaudo);
    final Map<String, dynamic> ident = novosDados['identificacao'] != null
        ? Map<String, dynamic>.from(novosDados['identificacao'] as Map)
        : {};
    novosDados['identificacao'] = {
      ...ident,
      'sexo': novoSexo,
    };
    
     final caracteristicas = novosDados['identificacao']['caracteristicas']?.toString() ?? '';
    if (caracteristicas.isEmpty || caracteristicas.toLowerCase().contains('sexo xxx')) {
      novosDados['identificacao']['caracteristicas'] = 
        'Cadáver do sexo ${novoSexo.toLowerCase()}, raça XXX, estado nutricional XXX, e idade aparente de XX anos.';
    } else if (novoSexo == 'Feminino') {
      novosDados['identificacao']['caracteristicas'] = caracteristicas.replaceAll(RegExp(r'sexo masculino', caseSensitive: false), 'sexo feminino');
    } else if (novoSexo == 'Masculino') {
      novosDados['identificacao']['caracteristicas'] = caracteristicas.replaceAll(RegExp(r'sexo feminino', caseSensitive: false), 'sexo masculino');
    }

    atualizarDadosLaudoMemoria(novosDados);
    
    if (!isReadOnly) {
      _scheduleAutoSave();
    }
  }

  String _resolveBodyPartName(String view, String partId) {
    if ((view == 'frente' || view == 'front') && kIdToDefinitionFrontMap.containsKey(partId)) return kIdToDefinitionFrontMap[partId]!.name;
    if ((view == 'costas' || view == 'back') && kIdToDefinitionBackMap.containsKey(partId)) return kIdToDefinitionBackMap[partId]!.name;
    if (view == 'lateral_dir' && lat_right.kIdToDefinitionLateralRightMap.containsKey(partId)) return lat_right.kIdToDefinitionLateralRightMap[partId]!.name;
    if (view == 'lateral_esq' && lat_left.kIdToDefinitionLateralLeftMap.containsKey(partId)) return lat_left.kIdToDefinitionLateralLeftMap[partId]!.name;
    if (view == 'trunk_dir' && trunk_right.kIdToDefinitionTrunkRightMap.containsKey(partId)) return trunk_right.kIdToDefinitionTrunkRightMap[partId]!.name;
    if (view == 'trunk_esq' && trunk_left.kIdToDefinitionTrunkLeftMap.containsKey(partId)) return trunk_left.kIdToDefinitionTrunkLeftMap[partId]!.name;
    if (view == 'perineal' && perineal.kIdToDefinitionPerinealMap.containsKey(partId)) return perineal.kIdToDefinitionPerinealMap[partId]!.name;
    if (view == 'face_dir' && face_right.kIdToDefinitionLateralRightMap.containsKey(partId)) return face_right.kIdToDefinitionLateralRightMap[partId]!.name;
    if (view == 'face_esq' && face_left.kIdToDefinitionLateralLeftMap.containsKey(partId)) return face_left.kIdToDefinitionLateralLeftMap[partId]!.name;
    return partId.replaceAll('_', ' ').toUpperCase();
  }


  Future<void> adicionarFotoGeral(String path) async {
    final ev = EvidenciaMultimidia.novo(
      casoUuid: casoAtual.uuid,
      tipo: 'GERAL',
      caminhoArquivoEncriptado: path,
    );
    await _caseService.salvarEvidenciaGeral(ev);
    await _loadAchados();
  }

  Future<void> removerFotoGeral(String uuid) async {
    await _caseService.removerEvidenciaGeral(uuid);
    await _loadAchados();
  }

  Future<void> salvarExamesSolicitados({
    required String? anatomoLacre,
    required String? toxicologicoLacre,
    required String? geneticaLacre,
    required String? outrosLacre,
  }) async {
    await _caseService.salvarExamesSolicitados(
      casoUuid: casoAtual.uuid,
      anatomoLacre: anatomoLacre,
      toxicologicoLacre: toxicologicoLacre,
      geneticaLacre: geneticaLacre,
      outrosLacre: outrosLacre,
    );
    examesSolicitados = await _caseService.getExamesSolicitados(casoAtual.uuid);
    notifyListeners();
  }

  void atualizarCasoCamposEJson({
    required String numeroBo,
    required String numeroPic,
    required String numeroRequisicao,
    required String nomeVitima,
    required String destino,
    required String requisitante,
    required Map<String, dynamic> novosDadosLaudo,
  }) {
    final Map<String, dynamic> finalDadosLaudo = Map<String, dynamic>.from(novosDadosLaudo);
    if (finalDadosLaudo['auditoria'] is Map) {
      final auditoriaMap = Map<String, dynamic>.from(finalDadosLaudo['auditoria'] as Map);
      auditoriaMap.remove('atn_id');
      auditoriaMap.remove('atn_nome');
      finalDadosLaudo['auditoria'] = auditoriaMap;
    }

    casoAtual = casoAtual.copyWith(
      numeroBo: numeroBo,
      numeroPic: numeroPic,
      numeroRequisicao: numeroRequisicao,
      nomeVitima: nomeVitima,
      destino: destino,
      requisitante: requisitante,
      dadosLaudo: finalDadosLaudo,
      atualizadoEm: DateTime.now(),
    );

    debugPrint('[CroquiController] 📦 atualizarCasoCamposEJson - atn_id na RAIZ: ${casoAtual.atnId}, atn_responsavel: ${casoAtual.atnResponsavel}');
    debugPrint('[CroquiController] 📦 dados_laudo_json (sem ATN): ${jsonEncode(casoAtual.dadosLaudo)}');
    notifyListeners();
    _scheduleAutoSave();
  }

  Future<void> salvarDescricaoFotoGeral(String uuid, String descricao) async {
    final index = evidenciasGerais.indexWhere((e) => e.uuid == uuid);
    if (index != -1) {
      final evAtualizada = evidenciasGerais[index].copyWith(descricao: descricao);
      await _caseService.salvarEvidenciaGeral(evAtualizada);
      await _loadAchados();
    }
  }

  void _scheduleAutoSave() {
    if (isReadOnly) return;
    _isAutoSavePending = true;
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 3), () async {
      if (_isDisposed) return;
      if (_isAutoSavePending && !isReadOnly) {
        _isAutoSavePending = false;
        try {
          await _caseService.salvarRascunho(casoAtual);
          debugPrint('[CroquiController] 💾 Auto-save resiliente gravado no SQLite.');
        } catch (e) {
          debugPrint('[CroquiController] ⚠️ Erro no auto-save resiliente: $e');
        }
      }
    });
  }

  Future<void> flushAutoSave() async {
    _autoSaveTimer?.cancel();
    if (_isAutoSavePending && !isReadOnly) {
      _isAutoSavePending = false;
      try {
        await _caseService.salvarRascunho(casoAtual);
        debugPrint('[CroquiController] 💾 Flush imediato de rascunho gravado no SQLite.');
      } catch (e) {
        debugPrint('[CroquiController] ⚠️ Erro ao forçar flush de rascunho: $e');
      }
    } else if (!isReadOnly) {
      try {
        await _caseService.salvarRascunho(casoAtual);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _autoSaveTimer?.cancel();

    // Copia o estado necessário ANTES de liberar os controllers
    // para evitar use-after-free na escrita assíncrona pós-dispose.
    final casoParaFlush = casoAtual;
    final deveFlush = _isAutoSavePending && !isReadOnly;

    // Libera todos os recursos síncronos imediatamente
    numeroLaudoCtrl.dispose();
    boCtrl.dispose();
    picCtrl.dispose();
    reqOrigemCtrl.dispose();
    reqDestinoCtrl.dispose();
    nomeVitimaCtrl.dispose();
    historicoCtrl.dispose();
    vestesCtrl.dispose();
    caracteristicasCtrl.dispose();
    tanatoImediatoCtrl.dispose();
    tanatoConsecutivoCtrl.dispose();
    tanatoObservacaoCtrl.dispose();
    discussaoCtrl.dispose();
    conclusaoCtrl.dispose();
    quesito1Ctrl.dispose();
    quesito2Ctrl.dispose();
    quesito3Ctrl.dispose();
    quesito4Ctrl.dispose();
    super.dispose();

    // Dispara o flush DEPOIS do super.dispose() operando apenas
    // sobre a cópia local — nunca sobre membros já liberados.
    if (deveFlush) {
      _caseService.salvarRascunho(casoParaFlush).catchError(
        (e) => debugPrint('[CroquiController] ⚠️ Erro no flush pós-dispose: $e'),
      );
    }
  }

  void sincronizarDadosEmMemoria(AuthProvider authProvider) {
    if (isReadOnly) return;

    final nomePerito = authProvider.usuario?.nomeCompleto ?? "Perito não identificado";

    final Map<String, dynamic> novosDados = {};
    final auditoriaExistente = Map<String, dynamic>.from(casoAtual.dadosLaudo['auditoria'] as Map? ?? {});

    final selectedAtnNome = casoAtual.atnResponsavel ?? auditoriaExistente['atn_nome']?.toString();
    String? selectedAtnId = auditoriaExistente['atn_id']?.toString();

    if (selectedAtnNome != null && selectedAtnNome.isNotEmpty && selectedAtnId == null) {
      final match = atns.where((a) => a.nome == selectedAtnNome).firstOrNull;
      selectedAtnId = match?.id;
    }

    novosDados['auditoria'] = {
      'perito_responsavel': nomePerito,
      'data_finalizacao': DateTime.now().toIso8601String(),
    };

    novosDados['identificacao'] = {
      'vestes': vestesCtrl.text,
      'historico': historicoCtrl.text,
    };

    novosDados['caracteristicas'] = {
      'identificacao': caracteristicasCtrl.text,
      'tanato_imediato': tanatoImediatoCtrl.text,
      'tanato_observacao': tanatoObservacaoCtrl.text,
      'tanato_consecutivo': tanatoConsecutivoCtrl.text,
    };

    novosDados['conclusao'] = {
      'discussao': discussaoCtrl.text,
      'quesito_1_morte': quesito1Ctrl.text,
      'quesito_2_causa': quesito2Ctrl.text,
      'quesito_3_instrumento': quesito3Ctrl.text,
      'quesito_4_meio': quesito4Ctrl.text,
      'conclusao_texto': conclusaoCtrl.text,
    };

    atualizarCasoCamposEJson(
      numeroBo: boCtrl.text,
      numeroPic: picCtrl.text,
      numeroRequisicao: numeroLaudoCtrl.text,
      nomeVitima: nomeVitimaCtrl.text,
      destino: reqDestinoCtrl.text,
      requisitante: reqOrigemCtrl.text,
      novosDadosLaudo: novosDados,
    );
  }

  bool validarCamposObrigatorios() {
    if (quesito1Ctrl.text.trim().isEmpty) return false;
    if (quesito2Ctrl.text.trim().isEmpty) return false;
    if (quesito3Ctrl.text.trim().isEmpty) return false;
    if (quesito4Ctrl.text.trim().isEmpty) return false;
    return true;
  }

  void _snack(String msg, {Color? color}) {
    final messenger = globalMessengerKey.currentState;
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, duration: const Duration(seconds: 2))
    );
  }
}

