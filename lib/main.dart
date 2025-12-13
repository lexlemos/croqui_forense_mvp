import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:croqui_forense_mvp/core/security/secure_key_storage.dart';
import 'package:croqui_forense_mvp/data/local/database_factory_impl.dart';
import 'package:croqui_forense_mvp/data/local/database_helper.dart'; 

import 'package:croqui_forense_mvp/data/repositories/usuario_repository.dart';
import 'package:croqui_forense_mvp/data/repositories/caso_repository.dart';

import 'package:croqui_forense_mvp/domain/services/auth_service.dart';
import 'package:croqui_forense_mvp/domain/services/case_service.dart';

import 'package:croqui_forense_mvp/presentation/providers/auth_provider.dart';
import 'package:croqui_forense_mvp/presentation/providers/case_list_provider.dart';

import 'package:croqui_forense_mvp/presentation/pages/login_page.dart';
import 'package:croqui_forense_mvp/presentation/pages/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final dbFactory = DatabaseFactoryImpl();
  final keyStorage = SecureKeyStorage();
  
  await keyStorage.delete('user_session_id');

  DatabaseHelper.init(dbFactory, keyStorage);
  
  try {
    await DatabaseHelper.instance.database;
    print("✅ Banco inicializado e pronto.");
  } catch (e) {
    print("❌ Erro fatal ao abrir banco: $e");
  }

  runApp(const AppRoot());
}

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    final keyStorage = SecureKeyStorage();

    return MultiProvider(
      providers: [
        Provider<UsuarioRepository>(
          create: (_) => UsuarioRepository(),
        ),
        Provider<CasoRepository>(
          create: (_) => CasoRepository(),
        ),
        ProxyProvider<UsuarioRepository, AuthService>(
          update: (_, repo, __) => AuthService(repo, keyStorage),
        ),
        ProxyProvider<CasoRepository, CaseService>(
          update: (_, repo, __) => CaseService(repo),
        ),
        ChangeNotifierProxyProvider<AuthService, AuthProvider>(
          create: (_) => AuthProvider(AuthService(UsuarioRepository(), keyStorage)),
          update: (_, authService, previous) => AuthProvider(authService),
        ),

        ChangeNotifierProxyProvider<CaseService, CaseListProvider>(
          create: (_) => CaseListProvider(CaseService(CasoRepository())),
          update: (_, caseService, previous) {
             return previous ?? CaseListProvider(caseService);
          },
        ),
      ],
      child: const CroquiApp(),
    );
  }
}

class CroquiApp extends StatefulWidget {
  const CroquiApp({super.key});

  @override
  State<CroquiApp> createState() => _CroquiAppState();
}

class _CroquiAppState extends State<CroquiApp> {
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().checkLoginStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Croqui Forense MVP',
      debugShowCheckedModeBanner: false, // Remove a faixa de debug
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF317FF5)), // Azul Institucional
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
        ),
      ),
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          if (auth.isLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (auth.isLogged) {
            return const HomePage();
          }
          return const LoginPage();
        },
      ),
    );
  }
}