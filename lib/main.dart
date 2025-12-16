import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:croqui_forense_mvp/core/security/secure_key_storage.dart';
import 'package:croqui_forense_mvp/data/local/database_factory_impl.dart';
import 'package:croqui_forense_mvp/data/local/database_helper.dart'; 

import 'package:croqui_forense_mvp/data/repositories/usuario_repository.dart';
import 'package:croqui_forense_mvp/data/repositories/caso_repository.dart';

import 'package:croqui_forense_mvp/domain/services/auth_service.dart';
import 'package:croqui_forense_mvp/domain/services/case_service.dart';
import 'package:croqui_forense_mvp/domain/services/user_service.dart';

import 'package:croqui_forense_mvp/presentation/providers/auth_provider.dart';
import 'package:croqui_forense_mvp/presentation/providers/case_list_provider.dart';
import 'package:croqui_forense_mvp/presentation/providers/user_management_provider.dart'; // Se existir

import 'package:croqui_forense_mvp/presentation/pages/login_page.dart';
import 'package:croqui_forense_mvp/presentation/pages/home_page.dart';
import 'package:croqui_forense_mvp/presentation/pages/force_change_pin_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final dbFactory = DatabaseFactoryImpl();
  final keyStorage = SecureKeyStorage();
  
  DatabaseHelper.init(dbFactory, keyStorage);
  
  try {
    await DatabaseHelper.instance.database;
    print("✅ Banco inicializado e pronto (Com migração v2 e UUIDs).");
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
    
    final dbHelper = DatabaseHelper.instance; 

    return MultiProvider(
      providers: [
        Provider<UsuarioRepository>(
          create: (_) => UsuarioRepository(dbHelper), 
        ),
        Provider<CasoRepository>(
          create: (_) => CasoRepository(dbHelper), 
        ),
        ProxyProvider<UsuarioRepository, AuthService>(
          update: (_, repo, __) => AuthService(repo, keyStorage),
        ),
        ProxyProvider<CasoRepository, CaseService>(
          update: (_, repo, __) => CaseService(repo),
        ),
        ProxyProvider<UsuarioRepository, UserService>(
          update: (_, repo, __) => UserService(repo),
        ),

        ChangeNotifierProxyProvider<AuthService, AuthProvider>(
          create: (ctx) => AuthProvider(ctx.read<AuthService>()),
          update: (_, authService, previous) => AuthProvider(authService),
        ),

        ChangeNotifierProxyProvider<CaseService, CaseListProvider>(
          create: (ctx) => CaseListProvider(ctx.read<CaseService>()),
          update: (_, caseService, previous) => CaseListProvider(caseService),
        ),
        
        ChangeNotifierProxyProvider<UserService, UserManagementProvider>(
          create: (ctx) => UserManagementProvider(ctx.read<UserService>()),
          update: (_, userService, previous) => UserManagementProvider(userService),
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
    final authProvider = context.watch<AuthProvider>();

    return MaterialApp(
      title: 'Croqui Forense',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF317FF5)),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Roboto',
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
        ),
      ),
      home: authProvider.isLoading 
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _decideHome(authProvider),
    );
  }

  Widget _decideHome(AuthProvider auth) {
    if (!auth.isLogged) {
      return const LoginPage();
    }
    if (auth.usuario?.deveAlterarPin == true) {
      return const ForceChangePinPage();
    }
    return const HomePage();
  }
}