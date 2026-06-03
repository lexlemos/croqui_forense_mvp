import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart'; 

import 'package:croqui_forense_mvp/data/models/caso_model.dart';
import 'package:croqui_forense_mvp/data/models/achado_model.dart';
import 'package:croqui_forense_mvp/domain/services/achado_service.dart';
import 'package:croqui_forense_mvp/domain/services/case_service.dart';
import 'package:croqui_forense_mvp/presentation/providers/auth_provider.dart';
import 'package:croqui_forense_mvp/core/utils/image_helper.dart';
import 'package:croqui_forense_mvp/domain/services/pdf_service.dart';
import 'package:croqui_forense_mvp/core/utils/globals.dart';
import 'package:croqui_forense_mvp/core/constants/diagram_constants.dart';

import 'package:croqui_forense_mvp/data/repositories/achado_repository.dart';
import 'package:croqui_forense_mvp/data/repositories/injury_type_repository.dart';
import 'package:croqui_forense_mvp/components/forms/injury_form_modal.dart';
import 'package:croqui_forense_mvp/core/constants/front_body_data.dart';
import 'package:croqui_forense_mvp/core/constants/back_body_data.dart';
import 'package:croqui_forense_mvp/core/constants/lateral_right_data.dart' as face_right;
import 'package:croqui_forense_mvp/core/constants/lateral_left_data.dart' as face_left;
import 'package:croqui_forense_mvp/core/constants/lateral_right_body_data.dart' as lat_right;
import 'package:croqui_forense_mvp/core/constants/lateral_left_body_data.dart' as lat_left;
import 'package:croqui_forense_mvp/core/constants/trunk_right_data.dart' as trunk_right;
import 'package:croqui_forense_mvp/core/constants/trunk_left_data.dart' as trunk_left;
import 'package:croqui_forense_mvp/core/constants/perineal_data.dart' as perineal;

class CroquiController extends ChangeNotifier {
  final AchadoService _achadoService;
  final CaseService _caseService;
  final InjuryTypeRepository _injuryTypeRepository;
  final AchadoRepository _achadoRepository;

  Caso casoAtual;
  List<Achado> achados = [];
  bool isLoading = false;
  bool _isExporting = false;
  bool get isExporting => _isExporting;

  bool get isReadOnly => casoAtual.status == StatusCaso.finalizado;

  CroquiController(this.casoAtual, this._achadoService, this._caseService, this._injuryTypeRepository, this._achadoRepository) {
    _loadAchados();
  }

  Future<void> _loadAchados() async {
    if (isLoading) return;
    isLoading = true;
    notifyListeners();
    try {
      achados = await _achadoService.listarAchados(casoAtual.uuid);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  List<Achado> getMarkersForView(String view) {
  return achados.where((a) => (a.dadosPreenchidos['view'] ?? '') == view).toList();
  }

  Future<void> addAchado(BuildContext context, String viewType, String partId, double x, double y) async {
    if (isReadOnly) {
      _snack("Caso finalizado. Edição bloqueada.");
      return;
    }

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
      if (result['dynamicFields'] is Map) 'dynamicFields': result['dynamicFields'],
    };

    final achadoFinal = Achado(
      uuid: const Uuid().v4(),
      casoUuid: casoAtual.uuid,
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
      proveniencia: 'APP_TABLET',
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
  }

  Future<void> editAchado(BuildContext context, Achado achado) async {
    if (isReadOnly) return;

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
    if (result['dynamicFields'] is Map) {
      novosDados['dynamicFields'] = result['dynamicFields'];
    }

    final achadoAtualizado = achado.copyWith(
      tipoAchadoId: tipoLesaoId,
      achadoRelacionadoUuid: achadoRelacionadoUuid,
      isInterno: isInterno,
      dadosPreenchidos: novosDados,
      observacoesTexto: description,
      versao: achado.versao + 1,
      atualizadoEm: DateTime.now(),
    );

    try {
      await _achadoService.atualizarAchado(achadoAtualizado);
      await _loadAchados();
      _snack("Achado atualizado!");
    } catch (e) {
      _snack("Erro ao atualizar: $e", color: Colors.red);
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
  }

  Future<void> finalizarCasoDireto(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Finalizar Laudo?"),
        content: const Text("O caso será marcado como concluído e não poderá ser mais editado."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text("FINALIZAR")
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _caseService.finalizarCaso(casoAtual.uuid, casoAtual.dadosLaudo);
      await _reloadCaso();
      _snack("Caso finalizado!", color: Colors.green);
    } catch (e) {
      globalMessengerKey.currentState?.hideCurrentSnackBar();
      globalMessengerKey.currentState?.showSnackBar(SnackBar(content: Text("Erro ao finalizar: $e"), backgroundColor: Colors.red));
    }
  }

  Future<void> reabrirCaso(BuildContext context) async {
    try {
      await _caseService.reabrirCaso(casoAtual.uuid);
      await _reloadCaso();
      _snack("Edição habilitada.");
    } catch (e) {
      globalMessengerKey.currentState?.hideCurrentSnackBar();
      globalMessengerKey.currentState?.showSnackBar(const SnackBar(content: Text("Erro ao reabrir"), backgroundColor: Colors.red));
    }
  }
  Future<void> exportarCaso(BuildContext context) async {
    if (_isExporting) return;
    _isExporting = true;
    notifyListeners();

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final usuarioLogado = auth.usuario;

    if (usuarioLogado == null) {
      globalMessengerKey.currentState?.showSnackBar(const SnackBar(content: Text("Usuário não autenticado."), backgroundColor: Colors.red));
      _isExporting = false;
      notifyListeners();
      return;
    }

    _snack("Gerando laudo PDF oficial...");

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
      );

      final tempDir = await getTemporaryDirectory();
      final String safeNum = (casoAtual.numeroLaudoExterno ?? 'sem-numero').replaceAll('/', '-');
      final File pdfFile = File("${tempDir.path}/laudo_$safeNum.pdf");
      
      await pdfFile.writeAsBytes(pdfBytes, flush: true);

      if (!context.mounted) return;
      globalMessengerKey.currentState?.hideCurrentSnackBar();

      await Share.shareXFiles(
        [XFile(pdfFile.path)],
        subject: 'Laudo Pericial PDF - ' + casoAtual.numeroLaudoExterno.toString(),
      );

    } catch (e) {
      debugPrint("Erro na exportação do PDF: $e");
      globalMessengerKey.currentState?.hideCurrentSnackBar();
      globalMessengerKey.currentState?.showSnackBar(SnackBar(content: Text("Erro ao gerar PDF: ${e.toString()}"), backgroundColor: Colors.red));
    } finally {
      _isExporting = false;
      notifyListeners();
    }
  }
  Future<void> _reloadCaso() async {
    final caso = await _caseService.buscarCasoPorUuid(casoAtual.uuid);
    if (caso != null) casoAtual = caso;
    notifyListeners();
  }

  String get sexoDoExaminado {
    final dadosId = casoAtual.dadosLaudo['identificacao'];
    if (dadosId != null && dadosId['sexo'] != null) {
      return dadosId['sexo'].toString();
    }
    // Fallback: parse from caracteristicas
    final caracteristicas = dadosId?['caracteristicas']?.toString().toLowerCase() ?? '';
    if (caracteristicas.contains('feminino') || caracteristicas.contains('mulher')) {
      return 'Feminino';
    }
    if (caracteristicas.contains('masculino') || caracteristicas.contains('homem')) {
      return 'Masculino';
    }
    return 'Masculino'; // Default
  }

  Future<void> alterarSexoExaminado(BuildContext context, String novoSexo) async {
    final novosDados = Map<String, dynamic>.from(casoAtual.dadosLaudo);
    novosDados['identificacao'] = {
      ...(novosDados['identificacao'] as Map<String, dynamic>? ?? {}),
      'sexo': novoSexo,
    };
    
    // Auto-update the caracteristicas text template if it is default/placeholder or opposite sex
    final caracteristicas = novosDados['identificacao']['caracteristicas']?.toString() ?? '';
    if (caracteristicas.isEmpty || caracteristicas.contains('sexo XXX')) {
      novosDados['identificacao']['caracteristicas'] = 
        'Cadáver do sexo ${novoSexo.toLowerCase()}, raça XXX, estado nutricional XXX, e idade aparente de XX anos.';
    } else if (caracteristicas.contains('sexo masculino') && novoSexo == 'Feminino') {
      novosDados['identificacao']['caracteristicas'] = caracteristicas.replaceAll('sexo masculino', 'sexo feminino');
    } else if (caracteristicas.contains('sexo feminino') && novoSexo == 'Masculino') {
      novosDados['identificacao']['caracteristicas'] = caracteristicas.replaceAll('sexo feminino', 'sexo masculino');
    }

    atualizarDadosLaudoMemoria(novosDados);
    
    if (!isReadOnly) {
      try {
        await _caseService.salvarRascunho(casoAtual);
      } catch (e) {
        debugPrint("Erro ao salvar rascunho após alterar sexo: $e");
      }
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


  void _snack(String msg, {Color? color}) {
    final messenger = globalMessengerKey.currentState;
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, duration: const Duration(seconds: 2))
    );
  }
}

