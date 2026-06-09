import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:croqui_forense_mvp/presentation/providers/auth_provider.dart';
import 'package:croqui_forense_mvp/presentation/providers/case_list_provider.dart';
import 'package:croqui_forense_mvp/presentation/widgets/common/app_header.dart';
import 'package:croqui_forense_mvp/presentation/widgets/common/empty_state.dart';
import 'package:croqui_forense_mvp/presentation/widgets/home/home_action_bar.dart';
import 'package:croqui_forense_mvp/presentation/widgets/home/case_card.dart';
import 'package:croqui_forense_mvp/presentation/pages/croqui_page.dart';
import 'package:croqui_forense_mvp/presentation/pages/controllers/home_controller.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final HomeController _controller;

  @override
  void initState() {
    super.initState();
    _controller = HomeController();
    _controller.init(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CaseListProvider>().carregarCasos();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
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
              searchController: _controller.searchController,
              onNovoCaso: () => _controller.iniciarNovoCaso(context),
              onFiltrar: () => _controller.abrirFiltro(context),
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
  }}