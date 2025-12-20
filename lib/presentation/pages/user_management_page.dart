import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:croqui_forense_mvp/presentation/providers/auth_provider.dart';
import 'package:croqui_forense_mvp/presentation/providers/user_management_provider.dart';
import 'package:croqui_forense_mvp/domain/services/user_service.dart';
import 'package:croqui_forense_mvp/presentation/widgets/common/app_header.dart';
import 'package:croqui_forense_mvp/presentation/widgets/user_management/user_list_item.dart';
import 'package:croqui_forense_mvp/presentation/widgets/user_management/user_form_dialog.dart';

class UserManagementPage extends StatelessWidget {
  const UserManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => UserManagementProvider(context.read<UserService>()),
      child: const _UserManagementView(),
    );
  }
}

class _UserManagementView extends StatefulWidget {
  const _UserManagementView();

  @override
  State<_UserManagementView> createState() => _UserManagementViewState();
}

class _UserManagementViewState extends State<_UserManagementView> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserManagementProvider>().inicializar();
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        context.read<UserManagementProvider>().carregarMais();
      }
    });

    _searchController.addListener(() {
      context.read<UserManagementProvider>().setSearchQuery(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.select((AuthProvider p) => p.usuario);
    final userProvider = context.watch<UserManagementProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              usuario: currentUser,
              title: 'Gestão de Usuários',
              isHome: false,
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Buscar por nome ou matrícula...',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: const Color(0xFFF5F5F5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  FloatingActionButton.extended(
                    onPressed: () => _abrirCriacaoUsuario(context),
                    backgroundColor: const Color(0xFF317FF5),
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text('Novo Usuário', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Expanded(
              child: Container(
                color: const Color(0xFFFAFAFA),
                child: userProvider.isLoading && userProvider.usuarios.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : userProvider.erro != null
                        ? Center(child: Text('Erro: ${userProvider.erro}', style: const TextStyle(color: Colors.red)))
                        : ListView.separated(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(24),
                            itemCount: userProvider.usuarios.length + (userProvider.temMaisPaginas ? 1 : 0),
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              if (index == userProvider.usuarios.length) {
                                return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
                              }

                              final usuario = userProvider.usuarios[index];
                              return UserListItem(
                                usuario: usuario,
                                isCurrentUser: usuario.id == currentUser?.id,
                                onStatusChanged: (novoStatus) async {
                                  try {
                                    await userProvider.toggleStatusUsuario(usuario, currentUser!.id);
                                    if(mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Status de ${usuario.nomeCompleto} atualizado!')),
                                        );
                                    }
                                  } catch (e) {
                                    if(mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
                                        );
                                    }
                                  }
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

  Future<void> _abrirCriacaoUsuario(BuildContext context) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) {
        return ChangeNotifierProvider.value(
          value: context.read<UserManagementProvider>(),
          child: const UserFormDialog(),
        );
      },
    );

    if (result != null && context.mounted) {
      try {

        await context.read<UserManagementProvider>().criarUsuario(
          nome: result['nome'],
          matricula: result['matricula'],
          papelId: result['papelId'],
          pinInicial: result['pin'],
        );

        if(context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Usuário criado com sucesso!'),
                backgroundColor: Colors.green,
              ),
            );
        }
      } catch (e) {
        if(context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erro ao criar: $e'), backgroundColor: Colors.red),
            );
        }
      }
    }
  }
}