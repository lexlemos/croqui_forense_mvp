import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Imports de Infraestrutura
import 'package:croqui_forense_mvp/core/security/secure_key_storage.dart';
import 'package:croqui_forense_mvp/data/local/sqlcipher_database_factory.dart';
import 'package:croqui_forense_mvp/data/local/database_helper.dart';

// Imports de Dados (Repos)
import 'package:croqui_forense_mvp/data/repositories/usuario_repository.dart';
import 'package:croqui_forense_mvp/data/repositories/caso_repository.dart';

// Imports de Domínio (Services)
import 'package:croqui_forense_mvp/domain/services/auth_service.dart';
import 'package:croqui_forense_mvp/domain/services/case_service.dart';

// Imports de Apresentação (Providers e Pages)
import 'package:croqui_forense_mvp/presentation/providers/auth_provider.dart';
import 'package:croqui_forense_mvp/presentation/pages/login_page.dart';
import 'package:croqui_forense_mvp/presentation/pages/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Configuração da Infraestrutura (DB e Segurança)
  final dbFactory = SqlCipherDatabaseFactory();
  final keyStorage = SecureKeyStorage();
  
  // Inicializa o Singleton do Banco
  DatabaseHelper.init(dbFactory, keyStorage);
  
  // Warm-up do banco (garante que está aberto antes do app subir)
  try {
    await DatabaseHelper.instance.database;
    print("✅ Banco inicializado e pronto.");
  } catch (e) {
    print("❌ Erro fatal ao abrir banco: $e");
    // Em um app real, mostraríamos uma tela de erro fatal aqui
  }

  runApp(const AppRoot());
}

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    // A instância do Helper já foi inicializada no main
    final dbHelper = DatabaseHelper.instance;
    final keyStorage = SecureKeyStorage();

    // 2. Injeção de Dependências (Hierarquia)
    return MultiProvider(
      providers: [
        // Camada 1: Repositórios (Acesso a Dados)
        Provider<UsuarioRepository>(
          create: (_) => UsuarioRepository(dbHelper),
        ),
        Provider<CasoRepository>(
          create: (_) => CasoRepository(dbHelper),
        ),

        // Camada 2: Serviços de Domínio (Regras de Negócio)
        // Dependem dos Repositórios
        ProxyProvider<UsuarioRepository, AuthService>(
          update: (_, repo, __) => AuthService(repo, keyStorage),
        ),
        ProxyProvider<CasoRepository, CaseService>(
          update: (_, repo, __) => CaseService(repo),
        ),

        // Camada 3: State Management (Para a UI)
        // Depende do AuthService
        ChangeNotifierProxyProvider<AuthService, AuthProvider>(
          create: (_) => AuthProvider(
             // Hack temporário: o create precisa de uma instância inicial, 
             // mas o update vai injetar a correta.
             AuthService(UsuarioRepository(dbHelper), keyStorage)
          ),
          update: (_, authService, previous) => AuthProvider(authService),
        ),
      ],
      child: const CroquiApp(),
    );
  }
}

class CroquiApp extends StatelessWidget {
  const CroquiApp({super.key});

  @override
  Widget build(BuildContext context) {
    // O Consumer ou Provider.of escuta mudanças na autenticação
    final authProvider = Provider.of<AuthProvider>(context);

    return MaterialApp(
      title: 'Croqui Forense MVP',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
        ),
      ),
      // Roteamento Simples baseado no estado de Login
      home: authProvider.isAuthenticated ? const HomePage() : const LoginPage(),
    );
  }
}