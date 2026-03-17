import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:croqui_forense_mvp/core/security/secure_key_storage.dart';
import 'package:croqui_forense_mvp/data/local/database_factory_impl.dart';
import 'package:croqui_forense_mvp/data/local/database_helper.dart'; 
import 'package:croqui_forense_mvp/core/utils/globals.dart';

import 'package:croqui_forense_mvp/data/repositories/usuario_repository.dart';
import 'package:croqui_forense_mvp/data/repositories/caso_repository.dart';

import 'package:croqui_forense_mvp/domain/services/auth_service.dart';
import 'package:croqui_forense_mvp/domain/services/case_service.dart';
import 'package:croqui_forense_mvp/domain/services/user_service.dart';

import 'package:croqui_forense_mvp/presentation/providers/auth_provider.dart';
import 'package:croqui_forense_mvp/presentation/providers/case_list_provider.dart';
import 'package:croqui_forense_mvp/presentation/providers/user_management_provider.dart';

import 'package:croqui_forense_mvp/presentation/widgets/common/auth_wrapper.dart';
import 'package:croqui_forense_mvp/core/theme/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final dbFactory = DatabaseFactoryImpl();
  final keyStorage = SecureKeyStorage();
  
  DatabaseHelper.init(dbFactory, keyStorage);

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
        ProxyProvider2<CasoRepository, UsuarioRepository, CaseService>(
          update: (context, casoRepo, usuarioRepo, previousService) => CaseService(casoRepo, usuarioRepo),
        ),
        ProxyProvider<UsuarioRepository, UserService>(
          update: (_, repo, __) => UserService(repo),
        ),
        ChangeNotifierProxyProvider<AuthService, AuthProvider>(
          create: (ctx) => AuthProvider(ctx.read<AuthService>()),
          update: (_, authService, previous) => previous!..updateService(authService),
        ),

        ChangeNotifierProxyProvider<CaseService, CaseListProvider>(
          create: (ctx) => CaseListProvider(ctx.read<CaseService>()),
          update: (_, caseService, previous) => previous!..updateService(caseService),
        ),
        
        ChangeNotifierProxyProvider<UserService, UserManagementProvider>(
          create: (ctx) => UserManagementProvider(ctx.read<UserService>()),
          update: (_, userService, previous) => previous!..updateService(userService),
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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<AuthProvider>().checkLoginStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Croqui Forense',
      scaffoldMessengerKey: globalMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Roboto',
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}