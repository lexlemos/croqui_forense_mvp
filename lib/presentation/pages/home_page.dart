import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:croqui_forense_mvp/presentation/providers/auth_provider.dart';
import 'package:croqui_forense_mvp/presentation/providers/case_list_provider.dart';
import 'package:croqui_forense_mvp/domain/services/case_service.dart';
import 'package:croqui_forense_mvp/data/models/caso_model.dart';


import 'package:croqui_forense_mvp/presentation/widgets/common/app_header.dart';
import 'package:croqui_forense_mvp/presentation/widgets/common/empty_state.dart';
import 'package:croqui_forense_mvp/presentation/widgets/home/home_action_bar.dart';
import 'package:croqui_forense_mvp/presentation/widgets/home/case_card.dart';
import 'package:croqui_forense_mvp/presentation/widgets/home/case_filter_dialog.dart';
import 'package:croqui_forense_mvp/presentation/widgets/home/new_case_dialog.dart';

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
    final authProvider = context.watch<AuthProvider>();
    final caseList = context.watch<CaseListProvider>(); 
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              usuario: authProvider.usuario,
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
                      : ListView.separated(
                          padding: const EdgeInsets.all(24),
                          itemCount: caseList.casos.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            return CaseCard(
                              caso: caseList.casos[index],
                              onTap: () {
                                // TODO: Navegar para detalhes
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

      await context.read<CaseService>().createNewCase(
        criador: usuario, 
        numeroLaudo: numeroLaudo,
        dadosIniciais: dadosLaudo, // <--- Passamos o JSON completo
      );
      
      if (context.mounted) {
        context.read<CaseListProvider>().carregarCasos(); 
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Caso criado e dados iniciais salvos!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}