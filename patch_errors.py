import sys
import os
import re

def replace_in_file(path, old, new):
    if not os.path.exists(path):
        print(f"File not found: {path}")
        return
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    if old in content:
        content = content.replace(old, new)
        with open(path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Replaced in {os.path.basename(path)}")
    else:
        print(f"FAILED to find in {os.path.basename(path)}:\n{old}")

def patch_controller():
    path = r'c:\dev\croqui_forense_mvp\lib\presentation\pages\controllers\croqui_controller.dart'
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # fix versao semicolon
    content = content.replace("versao: casoAtual.versao +1;", "versao: casoAtual.versao + 1,")

    # fix duplicated method. It was added near the bottom by my patch, but the user moved the code near line 251. 
    # Let's use regex to remove the duplicate `salvarExamesSolicitados` if it appears twice.
    # The first one is at line 251, the second one at 861. The one at 861 is the one with `await _bumpRootVersion()`.
    
    # Actually, we can just replace the 861 one completely with empty string.
    old_method = """  Future<void> salvarExamesSolicitados({
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
    await _bumpRootVersion();
    notifyListeners();
  }"""
    if old_method in content:
        content = content.replace(old_method, "")
        print("Removed duplicate method in croqui_controller.dart")
    
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

def patch_croqui_page():
    path = r'c:\dev\croqui_forense_mvp\lib\presentation\pages\croqui_page.dart'
    # 1. authService, syncService, etc.
    old1 = """        authService: ctx.read<AuthService?>(),
        syncService: ctx.read<SyncService?>(),
        pdfGenerationService: ctx.read<PdfGenerationService>(),
        laudoParserService: ctx.read<LaudoParserService>(),"""
    replace_in_file(path, old1, "")

    # 2. loadErrorMessage & recarregarDados
    old2 = """              Consumer<CroquiController>(
                builder: (context, c, _) {
                  final message = c.loadErrorMessage;
                  if (message == null) return const SizedBox.shrink();
                  return MaterialBanner(
                    backgroundColor: Colors.red.shade50,
                    leading: Icon(Icons.warning_amber_rounded, color: Colors.red.shade800),
                    content: Text(message),
                    actions: [
                      TextButton(
                        onPressed: () => c.recarregarDados(),
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  );
                },
              ),"""
    replace_in_file(path, old2, "")

    # 3. deleteAchado
    replace_in_file(path, "final result = await c.deleteAchado(uuid);", "await c.deleteAchado(context, uuid);")
    replace_in_file(path, "if (context.mounted) _showOperationResult(context, result);", "")
    
    # 4. _addAchado
    old4 = """    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => InjuryFormModal(
        bodyPartName: resolveBodyPartName(view, partId),
        injuryTypeRepository: context.read<InjuryTypeRepository>(),
        achadoRepository: context.read<AchadoRepository>(),
        casoUuid: controller.casoAtual.uuid,
      ),
    );
    if (result == null || !context.mounted) return;

    final operation = await controller.addAchado(view, partId, x, y, result);
    if (context.mounted) _showOperationResult(context, operation);"""
    new4 = "    await controller.addAchado(context, view, partId, x, y);"
    replace_in_file(path, old4, new4)

    # 5. reabrirCaso
    replace_in_file(path, "final result = await controller.reabrirCaso();", "await controller.reabrirCaso(context);")
    
    # 6. exportarCaso
    old6 = """  Future<void> _exportarCaso(BuildContext context, CroquiController controller) async {
    File? file;
    try {
      final exported = await controller.exportarCaso();
      if (!context.mounted) return;

      final tempDir = await getTemporaryDirectory();
      file = File('${tempDir.path}/${exported.fileName}');
      await file.writeAsBytes(exported.bytes, flush: true);
      // ignore: deprecated_member_use
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Laudo Pericial PDF - ${controller.casoAtual.numeroLaudoExterno}',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao gerar PDF: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      final fileToDelete = file;
      if (fileToDelete != null && fileToDelete.existsSync()) {
        try {
          await fileToDelete.delete();
        } catch (_) {}
      }
    }
  }"""
    new6 = """  Future<void> _exportarCaso(BuildContext context, CroquiController controller) async {
    await controller.exportarCaso(context);
  }"""
    replace_in_file(path, old6, new6)

    # 7. editAchado
    old7 = """              final result = await showModalBottomSheet<Map<String, dynamic>>(
                context: context,
                isScrollControlled: true,
                builder: (_) => InjuryFormModal(
                  bodyPartName: resolveBodyPartName(
                    achado.dadosPreenchidos['view']?.toString() ?? '',
                    achado.dadosPreenchidos['local_anatomico_id']?.toString() ?? '',
                  ),
                  injuryTypeRepository: context.read<InjuryTypeRepository>(),
                  achadoRepository: context.read<AchadoRepository>(),
                  casoUuid: controller.casoAtual.uuid,
                  achadoToEdit: achado,
                ),
              );
              if (result == null || !context.mounted) return;
              final operation = await controller.editAchado(achado, result);
              if (context.mounted && operation.message != null) {
                final color = operation.status == CroquiOperationStatus.success
                    ? Colors.green
                    : Colors.red;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(operation.message!), backgroundColor: color),
                );
              }"""
    new7 = "              await controller.editAchado(context, achado);"
    replace_in_file(path, old7, new7)

def patch_others():
    # case_info_tab.dart
    path = r'c:\dev\croqui_forense_mvp\lib\presentation\widgets\croqui\case_info_tab.dart'
    replace_in_file(path, "_croquiController.sincronizarDadosEmMemoria();", "_croquiController.sincronizarDadosEmMemoria(Provider.of<AuthProvider>(context, listen: false));")
    
    # croqui_finalization_flow.dart
    path = r'c:\dev\croqui_forense_mvp\lib\presentation\widgets\croqui\croqui_finalization_flow.dart'
    old_fin1 = """  var state = await controller.finalizarCasoDireto();"""
    new_fin1 = """  await controller.finalizarCasoDireto(context);
  return;"""
    replace_in_file(path, old_fin1, new_fin1)

    old_fin2 = """  state = await controller.finalizarCasoDireto(action: selectedAction);
  if (context.mounted) {
    if (state.action == FinishCaseAction.error || state.action == FinishCaseAction.validationError) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(state.message ?? 'Erro desconhecido'),
          backgroundColor: Colors.red,
        ));
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(state.message ?? 'Concluído'),
          backgroundColor: Colors.green,
        ));
      Navigator.of(context).pop();
    }
  }"""
    new_fin2 = """  await controller.finalizarCasoDireto(context);
  if (context.mounted) {
      Navigator.of(context).pop();
  }"""
    replace_in_file(path, old_fin2, new_fin2)

    # body_parts_tabs.dart
    path = r'c:\dev\croqui_forense_mvp\lib\presentation\widgets\croqui\tabs\body_parts_tabs.dart'
    replace_in_file(path, "controllerState.alterarSexoExaminado(newSelection.first);", "controllerState.alterarSexoExaminado(context, newSelection.first);")

if __name__ == '__main__':
    patch_controller()
    patch_croqui_page()
    patch_others()
    print("Done")
