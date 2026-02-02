import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'package:croqui_forense_mvp/data/models/caso_model.dart';
import 'package:croqui_forense_mvp/data/models/achado_model.dart';
import 'package:croqui_forense_mvp/data/models/injury_marker_model.dart';
import 'package:croqui_forense_mvp/domain/services/achado_service.dart';
import 'package:croqui_forense_mvp/domain/services/case_service.dart';
import 'package:croqui_forense_mvp/presentation/providers/auth_provider.dart';
import 'package:croqui_forense_mvp/core/utils/image_helper.dart';

import 'package:croqui_forense_mvp/components/forms/injury_form_modal.dart';
import 'package:croqui_forense_mvp/presentation/widgets/home/finalize_case_dialog.dart';
import 'package:croqui_forense_mvp/core/constants/front_body_data.dart';
import 'package:croqui_forense_mvp/core/constants/back_body_data.dart';
import 'package:croqui_forense_mvp/core/constants/lateral_right_data.dart';
import 'package:croqui_forense_mvp/core/constants/lateral_left_data.dart';

class CroquiController extends ChangeNotifier {
  final AchadoService _achadoService;
  final CaseService _caseService;

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

  Future<void> addAchado(BuildContext context, String viewType, String partId, double x, double y) async {
    if (isReadOnly) {
      _snack(context, "Caso finalizado. Edição bloqueada.");
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
      try {
        final File compressedFile = await ImageHelper.compressImage(File(finalPhotoPath));
        finalPhotoPath = compressedFile.path;
        print("✅ Imagem comprimida com sucesso: $finalPhotoPath");
      } catch (e) {
        print("⚠️ Falha na compressão (usando original): $e");
      }
    }

    final String tipoLesaoNome = result['type'];
    final String tipoLesaoId = _mapNameToId(tipoLesaoNome);

    final Map<String, dynamic> dadosExtras = {
      'view': viewType,
      'local_anatomico_id': partId,
      'local_anatomico_nome': realPartName,
      'type_label': tipoLesaoNome,
      'size': result['size'],
      'depth': result['depth'],
      'photo_path': finalPhotoPath, 
    };

    final novoAchadoTemporario = Achado.novo(
      diagramaCasoUuid: casoAtual.uuid,
      tipoAchadoId: tipoLesaoId,
      numeroSequencial: achados.length + 1,
      posX: x,
      posY: y,
    );

    final achadoFinal = Achado(
      uuid: novoAchadoTemporario.uuid,
      diagramaCasoUuid: novoAchadoTemporario.diagramaCasoUuid,
      tipoAchadoId: novoAchadoTemporario.tipoAchadoId,
      numeroSequencial: novoAchadoTemporario.numeroSequencial,
      posX: novoAchadoTemporario.posX,
      posY: novoAchadoTemporario.posY,
      estaPendente: true,
      dadosPreenchidos: dadosExtras,
      observacoesTexto: result['description'],
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
      print("❌ Erro: $e");
      if (context.mounted) _snack(context, "Erro ao salvar: $e", color: Colors.red);
    }
  }

  Future<void> editAchado(BuildContext context, Achado achado) async {
    if (isReadOnly) return;

    final dados = achado.dadosPreenchidos;
    final String localNome = dados['local_anatomico_nome'] ?? _resolveBodyPartName(dados['view'], achado.tipoAchadoId);

    final markerAdapter = InjuryMarker(
      id: achado.uuid,
      caseId: achado.diagramaCasoUuid,
      croquiType: dados['view'] ?? 'frente',
      bodyPartId: dados['local_anatomico_id'] ?? 'desconhecido',
      xPercent: achado.posX,
      yPercent: achado.posY,
      type: dados['type_label'] ?? '',
      size: dados['size'] ?? '',
      depth: dados['depth'] ?? '',
      photoPath: dados['photo_path'],
      description: achado.observacoesTexto,
    );

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => InjuryFormModal(
        bodyPartName: localNome,
        markerToEdit: markerAdapter,
      ),
    );

    if (result == null) return;

    String? finalPhotoPath = result['photoPath'];
    String? oldPhotoPath = achado.dadosPreenchidos['photo_path'];

    if (finalPhotoPath != null && finalPhotoPath != oldPhotoPath) {
       try {
        final File compressedFile = await ImageHelper.compressImage(File(finalPhotoPath));
        finalPhotoPath = compressedFile.path;
        print("✅ Nova imagem comprimida na edição");
      } catch (e) {
        print("⚠️ Falha na compressão (usando original): $e");
      }
    }

    final String tipoLesaoNome = result['type'];
    final String tipoLesaoId = _mapNameToId(tipoLesaoNome);

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
      estaPendente: true,
      dadosPreenchidos: novosDados,
      observacoesTexto: result['description'],
      removido: false,
      versao: achado.versao + 1,
      criadoEm: achado.criadoEm,
      atualizadoEm: DateTime.now(),
      proveniencia: achado.proveniencia,
    );

    await _achadoService.atualizarAchado(achadoAtualizado);
    await _loadAchados();
  }

  Future<void> deleteAchado(String uuid) async {
    if (isReadOnly) return;
    await _achadoService.removerAchado(uuid);
    await _loadAchados();
  }


  Future<void> reabrirCaso(BuildContext context) async {
    try {
      await _caseService.reabrirCaso(casoAtual.uuid);
      await _reloadCaso();
      if (context.mounted) _snack(context, "Modo de edição habilitado.");
    } catch (e) {
      if (context.mounted) _snack(context, "Erro: $e");
    }
  }

  Future<void> exportarCaso(BuildContext context) async {
    _snack(context, "Gerando arquivo de exportação...");

    try {
      final authProvider = context.read<AuthProvider>();
      final String nomeExportador = authProvider.usuario?.nomeCompleto ?? 'Usuário Desconhecido';
      
      String nomeCriador;
      if (authProvider.usuario != null && authProvider.usuario!.id == casoAtual.idUsuarioCriador) {
        nomeCriador = authProvider.usuario!.nomeCompleto;
      } else {
        nomeCriador = "ID: ${casoAtual.idUsuarioCriador}";
      }
      final Map<String, dynamic> dadosExportacao = await _caseService.gerarJsonExportacao(
        casoAtual.uuid, 
        nomeCriador,
        nomeExportador
      );

      final encoder = const JsonEncoder.withIndent('  ');
      final String jsonString = encoder.convert(dadosExportacao);

      final directory = await getTemporaryDirectory();
      final String safeLaudoNum = (casoAtual.numeroLaudoExterno ?? 'sem_numero').replaceAll('/', '-');
      final String fileName = 'export_laudo_$safeLaudoNum.json';
      
      final File file = File('${directory.path}/$fileName');
      await file.writeAsString(jsonString);

      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        _snack(context, "Exportado: .../$fileName", color: Colors.green);
      }

    } catch (e) {
      if (context.mounted) {
         ScaffoldMessenger.of(context).hideCurrentSnackBar();
        _snack(context, "Erro ao gerar JSON: $e", color: Colors.red);
      }
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
  }

  Future<void> finalizarCasoDireto(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Finalizar Laudo?"),
        content: const Text("O caso será marcado como concluído e não poderá ser mais editado.\n\nConfirma que revisou todos os dados e quesitos?"),
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
      if (context.mounted) _snack(context, "Caso finalizado com sucesso!", color: Colors.green);
    } catch (e) {
      if (context.mounted) _snack(context, "Erro ao finalizar: $e", color: Colors.red);
    }
  }

  Future<void> _reloadCaso() async {
    final casos = await _caseService.listarCasos();
    casoAtual = casos.firstWhere((c) => c.uuid == casoAtual.uuid);
    notifyListeners(); 
  }

  List<InjuryMarker> getMarkersForView(String view) {
    return achados
        .where((a) => (a.dadosPreenchidos['view'] ?? '') == view)
        .map((a) {
          return InjuryMarker(
            id: a.uuid,
            caseId: a.diagramaCasoUuid,
            croquiType: view,
            bodyPartId: a.dadosPreenchidos['local_anatomico_id'] ?? 'desconhecido',
            xPercent: a.posX,
            yPercent: a.posY,
            type: a.dadosPreenchidos['type_label'] ?? '',
            photoPath: a.dadosPreenchidos['photo_path'],
          );
        }).toList();
  }

  void _snack(BuildContext context, String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  String _mapNameToId(String name) {
    switch (name) {
      case 'Equimose': return 'equimose';
      case 'Escoriação': return 'escoriacao';
      case 'Ferida Contusa': return 'ferida_contusa';
      case 'Ferida Cortante': return 'ferida_cortante';
      case 'Perfuração': return 'perfuracao';
      case 'Hematoma': return 'hematoma';
      case 'Edema': return 'edema';
      case 'Fratura': return 'fratura';
      case 'Queimadura': return 'queimadura';
      default: return 'outro';
    }
  }

  String _resolveBodyPartName(String view, String partId) {
    if (view == 'frente' && kIdToDefinitionFrontMap.containsKey(partId)) return kIdToDefinitionFrontMap[partId]!.name;
    if (view == 'costas' && kIdToDefinitionBackMap.containsKey(partId)) return kIdToDefinitionBackMap[partId]!.name;
    if (view == 'lateral_dir' && kIdToDefinitionLateralRightMap.containsKey(partId)) return kIdToDefinitionLateralRightMap[partId]!.name;
    if (view == 'lateral_esq' && kIdToDefinitionLateralLeftMap.containsKey(partId)) return kIdToDefinitionLateralLeftMap[partId]!.name;
    return partId.replaceAll('_', ' ').toUpperCase();
  }
}