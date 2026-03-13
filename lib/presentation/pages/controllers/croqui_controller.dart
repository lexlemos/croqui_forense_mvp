import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart'; 

import 'package:croqui_forense_mvp/data/models/caso_model.dart';
import 'package:croqui_forense_mvp/data/models/achado_model.dart';
import 'package:croqui_forense_mvp/data/models/usuario_model.dart';
import 'package:croqui_forense_mvp/domain/services/achado_service.dart';
import 'package:croqui_forense_mvp/domain/services/case_service.dart';
import 'package:croqui_forense_mvp/presentation/providers/auth_provider.dart';
import 'package:croqui_forense_mvp/core/utils/image_helper.dart';
import 'package:croqui_forense_mvp/domain/services/pdf_service.dart';

import 'package:croqui_forense_mvp/components/forms/injury_form_modal.dart';
import 'package:croqui_forense_mvp/core/constants/front_body_data.dart';
import 'package:croqui_forense_mvp/core/constants/back_body_data.dart';
import 'package:croqui_forense_mvp/core/constants/lateral_right_data.dart';
import 'package:croqui_forense_mvp/core/constants/lateral_left_data.dart';

class CroquiController extends ChangeNotifier {
  final AchadoService _achadoService;
  final CaseService _caseService;
  final PdfService _pdfService = PdfService();

  Caso casoAtual;
  List<Achado> achados = [];
  bool isLoading = false;

  bool get isReadOnly => casoAtual.status == StatusCaso.finalizado;

  CroquiController(this.casoAtual, this._achadoService, this._caseService) {
    _loadAchados();
  }

  Future<void> _loadAchados() async {
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
      if (context.mounted) _snack(context, "Caso finalizado. Edição bloqueada.");
      return;
    }

    final String realPartName = _resolveBodyPartName(viewType, partId);

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => InjuryFormModal(bodyPartName: realPartName),
    );

    if (result == null) return;

    String? finalPhotoPath = result['photoPath'];
    if (finalPhotoPath != null) {
      final File compressedFile = await ImageHelper.compressImage(File(finalPhotoPath));
      finalPhotoPath = compressedFile.path;
    }

    if (!context.mounted) return;

    final String tipoLesaoId = result['typeId'] ?? 'outro';
    final String tipoLesaoNome = result['type'];
    final bool isInterno = result['isInterno'] ?? false;

    final Map<String, dynamic> dadosExtras = {
      'view': viewType,
      'local_anatomico_id': partId,
      'local_anatomico_nome': realPartName,
      'type_label': tipoLesaoNome,
      'size': result['size'],
      'depth': result['depth'],
      'photo_path': finalPhotoPath, 
      'is_interno': isInterno
    };

    final achadoFinal = Achado(
      uuid: const Uuid().v4(),
      diagramaCasoUuid: casoAtual.uuid,
      tipoAchadoId: tipoLesaoId,
      numeroSequencial: achados.length + 1,
      posX: x,
      posY: y,
      isInterno: isInterno,
      estaPendente: true,
      dadosPreenchidos: dadosExtras,
      observacoesTexto: result['description'] ?? '',
      removido: false,
      versao: 1,
      criadoEm: DateTime.now(),
      proveniencia: 'APP_TABLET',
    );

    try {
      await _achadoService.salvarAchado(achadoFinal);
      await _loadAchados();
      if (context.mounted) _snack(context, "Achado adicionado!");
    } catch (e) {
      if (context.mounted) _snack(context, "Erro ao salvar: $e", color: Colors.red);
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
        achadoToEdit: achado, 
      ),
    );

    if (result == null) return;

    String? finalPhotoPath = result['photoPath'];
    String? oldPhotoPath = achado.dadosPreenchidos['photo_path'];

    if (finalPhotoPath != null && finalPhotoPath != oldPhotoPath) {
      final File compressedFile = await ImageHelper.compressImage(File(finalPhotoPath));
      finalPhotoPath = compressedFile.path;
    }

    if (!context.mounted) return;

    final String tipoLesaoId = result['typeId'] ?? achado.tipoAchadoId;
    final String tipoLesaoNome = result['type'];

    final Map<String, dynamic> novosDados = Map.from(achado.dadosPreenchidos);
    novosDados['type_label'] = tipoLesaoNome;
    novosDados['size'] = result['size'];
    novosDados['depth'] = result['depth'];
    novosDados['photo_path'] = finalPhotoPath; 

    final achadoAtualizado = Achado(
      uuid: achado.uuid,
      diagramaCasoUuid: achado.diagramaCasoUuid,
      tipoAchadoId: tipoLesaoId,
      numeroSequencial: achado.numeroSequencial,
      posX: achado.posX,
      posY: achado.posY,
      isInterno: result['isInterno'] ?? achado.isInterno,
      estaPendente: false,
      dadosPreenchidos: novosDados,
      observacoesTexto: result['description'] ?? '',
      removido: false,
      versao: achado.versao + 1,
      criadoEm: achado.criadoEm,
      atualizadoEm: DateTime.now(),
      proveniencia: achado.proveniencia,
    );

    try {
      await _achadoService.atualizarAchado(achadoAtualizado);
      await _loadAchados();
      if (context.mounted) _snack(context, "Achado atualizado!");
    } catch (e) {
      if (context.mounted) _snack(context, "Erro ao atualizar: $e", color: Colors.red);
    }
  }

  Future<void> deleteAchado(BuildContext context, String uuid) async {
    if (isReadOnly) return;
    try {
      await _achadoService.removerAchado(uuid);
      await _loadAchados();
      if (context.mounted) _snack(context, "Achado removido.");
    } catch (e) {
      if (context.mounted) _snack(context, "Erro ao deletar", color: Colors.red);
    }
  }


  void atualizarDadosLaudoMemoria(Map<String, dynamic> novosDados) {
    casoAtual = Caso(
      uuid: casoAtual.uuid,
      idUsuarioCriador: casoAtual.idUsuarioCriador,
      numeroLaudoExterno: casoAtual.numeroLaudoExterno,
      status: casoAtual.status,
      hashIntegridade: casoAtual.hashIntegridade,
      removido: casoAtual.removido,
      versao: casoAtual.versao,
      criadoEmDispositivo: casoAtual.criadoEmDispositivo,
      criadoEmRedeConfiavel: casoAtual.criadoEmRedeConfiavel,
      atualizadoEm: DateTime.now(),
      deviceId: casoAtual.deviceId,
      dadosLaudo: novosDados,
      proveniencia: casoAtual.proveniencia,
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
      if (context.mounted) _snack(context, "Caso finalizado!", color: Colors.green);
    } catch (e) {
      if (context.mounted) _snack(context, "Erro ao finalizar: $e", color: Colors.red);
    }
  }

  Future<void> reabrirCaso(BuildContext context) async {
    try {
      await _caseService.reabrirCaso(casoAtual.uuid);
      await _reloadCaso();
      if (context.mounted) _snack(context, "Edição habilitada.");
    } catch (e) {
      if (context.mounted) _snack(context, "Erro ao reabrir", color: Colors.red);
    }

    
  }
  Future<void> exportarCaso(BuildContext context) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final usuarioLogado = auth.usuario;

    if (usuarioLogado == null) {
      _snack(context, "Usuário não autenticado.", color: Colors.red);
      return;
    }

    if (context.mounted) _snack(context, "Gerando laudo PDF oficial...");

    try {
      if (!isReadOnly) {
        await _caseService.salvarRascunho(casoAtual);
      }

      final pdfBytes = await PdfService().gerarLaudoPdf(
        caso: casoAtual,
        achados: achados,
        perito: usuarioLogado,
      );

      final tempDir = await getTemporaryDirectory();
      final String safeNum = (casoAtual.numeroLaudoExterno ?? 'sem-numero').replaceAll('/', '-');
      final File pdfFile = File("${tempDir.path}/laudo_$safeNum.pdf");
      
      await pdfFile.writeAsBytes(pdfBytes, flush: true);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      await Share.shareXFiles(
        [XFile(pdfFile.path)],
        subject: 'Laudo Pericial PDF - ${casoAtual.numeroLaudoExterno}',
      );

    } catch (e) {
      debugPrint("Erro na exportação do PDF: $e");
      if (context.mounted) {
        _snack(context, "Erro ao gerar PDF: ${e.toString()}", color: Colors.red);
      }
    }
  }
  Future<void> _reloadCaso() async {
    final casos = await _caseService.listarCasos();
    casoAtual = casos.firstWhere((c) => c.uuid == casoAtual.uuid);
    notifyListeners(); 
  }

  String _resolveBodyPartName(String view, String partId) {
    if (view == 'frente' && kIdToDefinitionFrontMap.containsKey(partId)) return kIdToDefinitionFrontMap[partId]!.name;
    if (view == 'costas' && kIdToDefinitionBackMap.containsKey(partId)) return kIdToDefinitionBackMap[partId]!.name;
    if (view == 'lateral_dir' && kIdToDefinitionLateralRightMap.containsKey(partId)) return kIdToDefinitionLateralRightMap[partId]!.name;
    if (view == 'lateral_esq' && kIdToDefinitionLateralLeftMap.containsKey(partId)) return kIdToDefinitionLateralLeftMap[partId]!.name;
    return partId.replaceAll('_', ' ').toUpperCase();
  }


  void _snack(BuildContext context, String msg, {Color? color}) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, duration: const Duration(seconds: 2))
    );
  }
}

