import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:croqui_forense_mvp/presentation/providers/auth_provider.dart';
import 'package:croqui_forense_mvp/presentation/providers/case_list_provider.dart';
import 'package:croqui_forense_mvp/domain/services/case_service.dart';
import 'package:croqui_forense_mvp/presentation/widgets/common/app_header.dart';
import 'package:croqui_forense_mvp/presentation/widgets/common/empty_state.dart';
import 'package:croqui_forense_mvp/presentation/widgets/home/home_action_bar.dart';
import 'package:croqui_forense_mvp/presentation/widgets/home/case_card.dart';
import 'package:croqui_forense_mvp/presentation/widgets/home/case_filter_dialog.dart';
import 'package:croqui_forense_mvp/presentation/widgets/home/new_case_dialog.dart';

import 'package:croqui_forense_mvp/presentation/pages/croqui_page.dart';
import 'package:croqui_forense_mvp/core/utils/globals.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CaseListProvider>().carregarCasos();
    });
    
    _searchController.addListener(() {
      context.read<CaseListProvider>().setSearchQuery(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usuario = context.select((AuthProvider p) => p.usuario);
    final caseList = context.watch<CaseListProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              usuario: usuario,
              title: 'Biblioteca de Casos',
              isHome: true,
            ),

            HomeActionBar(
              searchController: _searchController,
              onNovoCaso: () => _iniciarNovoCaso(context),
              onFiltrar: () => _abrirFiltro(context, caseList),
            ),

            const SizedBox(height: 24),
            Expanded(
              child: Container(
                color: const Color(0xFFF5F5F5),
                child: caseList.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : caseList.casos.isEmpty
                      ? EmptyState(
                          message: 'Nenhum caso encontrado.', 
                          errorDetails: caseList.erro
                        )
                      
                      : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 200, 
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.95, 
                        ),
                        itemCount: caseList.casos.length,
                          itemBuilder: (context, index) {
                            final casoExistente = caseList.casos[index];
                            return CaseCard(
                              caso: casoExistente,
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => CroquiPage(caso: casoExistente),
                                  ),
                                );
                                if (!context.mounted) return;
                                context.read<CaseListProvider>().carregarCasos();
                              },
                            );
                          },
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _iniciarNovoCaso(BuildContext context) async {
    final dadosRetornados = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const NewCaseDialog(),
    );

    if (dadosRetornados != null) {
      final String numero = dadosRetornados['numero_laudo'];
      final Map<String, dynamic> conteudoJson = dadosRetornados['dados_laudo'];

      if (context.mounted) {
        await _criarCaso(context, numero, conteudoJson);
      }
    }
  }

  Future<void> _abrirFiltro(BuildContext context, CaseListProvider provider) async {
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

  Future<void> _criarCaso(BuildContext context, String numeroLaudo, Map<String, dynamic> dadosLaudo) async {
    try {
      final usuario = context.read<AuthProvider>().usuario;
      if (usuario == null) return;

      final novoCaso = await context.read<CaseService>().createNewCase(
        criador: usuario, 
        numeroLaudo: numeroLaudo,
        dadosIniciais: dadosLaudo, 
      );
      
      if (!context.mounted) return;
      context.read<CaseListProvider>().carregarCasos(); 
      
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