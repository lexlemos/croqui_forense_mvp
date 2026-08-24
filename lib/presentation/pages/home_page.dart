import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:croqui_forense_mvp/data/models/caso_model.dart';
import 'package:croqui_forense_mvp/presentation/providers/auth_provider.dart';
import 'package:croqui_forense_mvp/presentation/providers/case_list_provider.dart';
import 'package:croqui_forense_mvp/presentation/widgets/common/app_header.dart';
import 'package:croqui_forense_mvp/presentation/widgets/common/empty_state.dart';
import 'package:croqui_forense_mvp/presentation/widgets/home/home_action_bar.dart';
import 'package:croqui_forense_mvp/presentation/widgets/home/case_card.dart';
import 'package:croqui_forense_mvp/presentation/pages/croqui_page.dart';
import 'package:croqui_forense_mvp/presentation/pages/controllers/home_controller.dart';
import 'package:croqui_forense_mvp/core/theme/app_colors.dart';

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

    final currentCases = caseList.casos;

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

            const SizedBox(height: 12),

            // Contador de Casos
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      '${currentCases.length} ${currentCases.length == 1 ? 'caso' : 'casos'}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            Expanded(
              child: Container(
                color: AppColors.homeBackground,
                child: _buildCasesGrid(context, currentCases),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCasesGrid(BuildContext context, List<Caso> list) {
    final caseList = context.watch<CaseListProvider>();
    if (caseList.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (list.isEmpty) {
      return EmptyState(
        message: 'Nenhum caso encontrado.',
        errorDetails: caseList.erro,
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 480,
        mainAxisExtent: 140,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final casoExistente = list[index];
        return CaseCard(
          caso: casoExistente,
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CroquiPage(
                  caso: casoExistente,
                  isReadOnly: casoExistente.status == StatusCaso.sincronizado,
                ),
              ),
            );
            if (!context.mounted) return;
            context.read<CaseListProvider>().carregarCasos();
          },
        );
      },
    );
  }
}
