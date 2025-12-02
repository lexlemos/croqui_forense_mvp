import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:croqui_forense_mvp/presentation/providers/auth_provider.dart';
import 'package:croqui_forense_mvp/domain/services/case_service.dart';
import 'package:croqui_forense_mvp/data/models/caso_model.dart';

// Widgets Customizados
import 'package:croqui_forense_mvp/presentation/widgets/common/app_header.dart';
import 'package:croqui_forense_mvp/presentation/widgets/home/home_action_bar.dart';
import 'package:croqui_forense_mvp/presentation/widgets/home/case_card.dart';
import 'package:croqui_forense_mvp/presentation/widgets/home/case_filter_dialog.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Listas de dados
  List<Caso> _todosCasos = [];
  List<Caso> _casosFiltrados = [];
  
  // Estado da UI
  bool _isLoading = true;
  String? _erro;

  // Estado do Filtro e Busca
  final TextEditingController _searchController = TextEditingController();
  
  // Estado da Ordenação (Padrão: Data Decrescente - Mais novos primeiro)
  SortCriteria _sortCriteria = SortCriteria.data;
  SortOrder _sortOrder = SortOrder.desc;
  
  // Estado do Filtro de Status (Padrão: Mostrar Rascunho e Finalizado)
  List<StatusCaso> _statusFilter = [StatusCaso.rascunho, StatusCaso.finalizado];

  @override
  void initState() {
    super.initState();
    _carregarCasos();
    
    // Listener para busca em tempo real
    _searchController.addListener(_aplicarFiltrosOrdenacao);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _carregarCasos() async {
    setState(() => _isLoading = true);
    try {
      // 1. Busca dados brutos do serviço
      final casos = await context.read<CaseService>().listarCasos();
      
      if (mounted) {
        setState(() {
          _todosCasos = casos;
          _erro = null;
          _isLoading = false;
          
          // 2. Aplica a ordenação e filtro iniciais
          _aplicarFiltrosOrdenacao();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _erro = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _aplicarFiltrosOrdenacao() {
    List<Caso> temp = List.from(_todosCasos);

    // 1. Filtro de Texto (Busca)
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      temp = temp.where((c) => (c.numeroLaudoExterno ?? '').toLowerCase().contains(query)).toList();
    }

    // 2. Filtro de Status (Tags)
    if (_statusFilter.isNotEmpty) {
       temp = temp.where((c) => _statusFilter.contains(c.status)).toList();
    }

    // 3. Ordenação
    temp.sort((a, b) {
      int comparison = 0;
      
      if (_sortCriteria == SortCriteria.data) {
        // Compara datas
        comparison = a.criadoEmDispositivo.compareTo(b.criadoEmDispositivo);
      } else {
        // Compara strings (trata nulos)
        comparison = (a.numeroLaudoExterno ?? '').compareTo(b.numeroLaudoExterno ?? '');
      }

      // Inverte se for Decrescente
      return _sortOrder == SortOrder.asc ? comparison : -comparison;
    });

    setState(() {
      _casosFiltrados = temp;
    });
  }

  Future<void> _abrirFiltro() async {
    final result = await showDialog<FilterResult>(
      context: context,
      builder: (context) => CaseFilterDialog(
        currentCriteria: _sortCriteria,
        currentOrder: _sortOrder,
        currentStatuses: _statusFilter,
      ),
    );

    if (result != null) {
      setState(() {
        _sortCriteria = result.sortCriteria;
        _sortOrder = result.sortOrder;
        _statusFilter = result.selectedStatuses;
        _aplicarFiltrosOrdenacao();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Cabeçalho
            AppHeader(
              usuario: authProvider.usuario,
              title: 'Biblioteca de Casos',
              isHome: true,
            ),

            // 2. Barra de Ações (Busca e Botões)
            HomeActionBar(
              searchController: _searchController,
              onNovoCaso: () => _exibirDialogoNovoCaso(context),
              onFiltrar: _abrirFiltro, // Abre o Modal de Filtro
            ),

            const SizedBox(height: 24),

            // 3. Lista de Casos
            Expanded(
              child: Container(
                color: const Color(0xFFF5F5F5),
                // Lógica de Loading e Lista Vazia
                child: _isLoading 
                  ? const Center(child: CircularProgressIndicator())
                  : _casosFiltrados.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.all(24),
                          itemCount: _casosFiltrados.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            return CaseCard(
                              caso: _casosFiltrados[index],
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Abrindo caso ${_casosFiltrados[index].numeroLaudoExterno}...'),
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Nenhum caso encontrado.',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          if (_erro != null)
             Padding(
               padding: const EdgeInsets.all(16.0),
               child: Text(_erro!, style: const TextStyle(color: Colors.red)),
             )
        ],
      ),
    );
  }


  Future<void> _exibirDialogoNovoCaso(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Iniciar Novo Caso'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Número do Laudo',
              hintText: 'Ex: 2025/001',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
               Navigator.pop(context);
               _criarCaso(controller.text.trim());
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: const Text('Cancelar')
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF317FF5)),
              onPressed: () async {
                final numero = controller.text.trim();
                if (numero.isNotEmpty) {
                  Navigator.pop(context);
                  await _criarCaso(numero);
                }
              },
              child: const Text('CRIAR'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _criarCaso(String numeroLaudo) async {
    if (numeroLaudo.isEmpty) return;

    try {
      final usuario = context.read<AuthProvider>().usuario;
      if (usuario == null) return;

      await context.read<CaseService>().createNewCase(
        criador: usuario, 
        numeroLaudo: numeroLaudo
      );
      
      // Recarrega a lista para exibir o novo caso (os filtros serão reaplicados)
      _carregarCasos();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Caso criado com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao criar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}