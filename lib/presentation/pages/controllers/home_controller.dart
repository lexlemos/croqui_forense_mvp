import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:croqui_forense_mvp/presentation/providers/auth_provider.dart';
import 'package:croqui_forense_mvp/presentation/providers/case_list_provider.dart';
import 'package:croqui_forense_mvp/presentation/widgets/home/new_case_dialog.dart';
import 'package:croqui_forense_mvp/presentation/widgets/home/case_filter_dialog.dart';
import 'package:croqui_forense_mvp/presentation/pages/croqui_page.dart';
import 'package:croqui_forense_mvp/core/utils/globals.dart';

class HomeController {
  final searchController = TextEditingController();

  void init(BuildContext context) {
    searchController.addListener(() {
      context.read<CaseListProvider>().setSearchQuery(searchController.text);
    });
  }

  void dispose() {
    searchController.dispose();
  }

  Future<void> iniciarNovoCaso(BuildContext context) async {
    final dadosRetornados = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const NewCaseDialog(),
    );

    if (dadosRetornados != null) {
      final String numero = dadosRetornados['numero_laudo'] ?? '';
      final String numeroPic = dadosRetornados['numero_pic'] ?? '';
      final String numeroBo = dadosRetornados['numero_bo'] ?? '';
      final String numeroRequisicao = dadosRetornados['numero_requisicao'] ?? '';
      final String nomeVitima = dadosRetornados['nome_vitima'] ?? '';
      final String destino = dadosRetornados['destino'] ?? '';
      final String requisitante = dadosRetornados['requisitante'] ?? '';
      final Map<String, dynamic> conteudoJson = dadosRetornados['dados_laudo'] ?? {};
      final List<dynamic> fotosGerais = dadosRetornados['fotos_gerais'] ?? [];

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
          fotosGerais: fotosGerais,
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
    required List<dynamic> fotosGerais,
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
            fotosGerais: fotosGerais,
          );

      if (!context.mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CroquiPage(caso: novoCaso),
        ),
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