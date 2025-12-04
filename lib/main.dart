import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:croqui_forense_mvp/core/security/secure_key_storage.dart';
import 'package:croqui_forense_mvp/data/local/sqlcipher_database_factory.dart';
import 'package:croqui_forense_mvp/data/local/database_helper.dart';

import 'package:croqui_forense_mvp/data/repositories/usuario_repository.dart';
import 'package:croqui_forense_mvp/data/repositories/caso_repository.dart';

import 'package:croqui_forense_mvp/domain/services/auth_service.dart';
import 'package:croqui_forense_mvp/domain/services/case_service.dart';

import 'package:croqui_forense_mvp/presentation/providers/auth_provider.dart';
import 'package:croqui_forense_mvp/presentation/pages/login_page.dart';
import 'package:croqui_forense_mvp/presentation/pages/home_page.dart';
import 'package:croqui_forense_mvp/presentation/providers/case_list_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final dbFactory = SqlCipherDatabaseFactory();
  final keyStorage = SecureKeyStorage();
  
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
    final dbHelper = DatabaseHelper.instance;
    final keyStorage = SecureKeyStorage();

    return MultiProvider(
      providers: [
        Provider<UsuarioRepository>(create: (_) => UsuarioRepository(dbHelper)),
        Provider<CasoRepository>(create: (_) => CasoRepository(dbHelper)),

        ProxyProvider<UsuarioRepository, AuthService>(
          update: (_, repo, __) => AuthService(repo, keyStorage),
        ),
        ProxyProvider<CasoRepository, CaseService>(
          update: (_, repo, __) => CaseService(repo),
        ),
        ChangeNotifierProxyProvider<AuthService, AuthProvider>(
          create: (_) => AuthProvider(AuthService(UsuarioRepository(dbHelper), keyStorage)),
          update: (_, authService, previous) => previous!..update(authService),
        ),
        ChangeNotifierProxyProvider<CaseService, CaseListProvider>(
          create: (_) => CaseListProvider(CaseService(CasoRepository(dbHelper))),

          update: (_, caseService, previous) {
             return previous ?? (CaseListProvider(caseService)..carregarCasos());
          },
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
      home: authProvider.isAuthenticated ? const HomePage() : const LoginPage(),
    );
  }
}