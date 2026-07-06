import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:croqui_forense_mvp/core/network/api_client.dart';
import 'package:croqui_forense_mvp/core/security/secure_key_storage.dart';
import 'package:croqui_forense_mvp/domain/repositories/remote_data_source.dart';
import 'package:croqui_forense_mvp/data/datasources/remote_data_source_impl.dart';
import 'package:croqui_forense_mvp/data/local/database_factory_impl.dart';
import 'package:croqui_forense_mvp/data/local/database_helper.dart';
import 'package:croqui_forense_mvp/core/utils/globals.dart';

import 'package:croqui_forense_mvp/data/repositories/usuario_repository.dart';
import 'package:croqui_forense_mvp/data/repositories/caso_repository.dart';
import 'package:croqui_forense_mvp/data/repositories/achado_repository.dart';
import 'package:croqui_forense_mvp/data/repositories/diagrama_repository.dart';
import 'package:croqui_forense_mvp/data/repositories/injury_type_repository.dart';

import 'package:croqui_forense_mvp/domain/services/auth_service.dart';
import 'package:croqui_forense_mvp/domain/services/case_service.dart';
import 'package:croqui_forense_mvp/domain/services/achado_service.dart';
import 'package:croqui_forense_mvp/domain/services/domain_sync_service.dart';
import 'package:croqui_forense_mvp/domain/services/sync_service.dart';
import 'package:croqui_forense_mvp/domain/services/user_service.dart';

import 'package:croqui_forense_mvp/presentation/providers/auth_provider.dart';
import 'package:croqui_forense_mvp/presentation/providers/case_list_provider.dart';
import 'package:croqui_forense_mvp/presentation/providers/sync_provider.dart';
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
        Provider<AchadoRepository>(
          create: (_) => AchadoRepository(dbHelper),
        ),
        Provider<DiagramaRepository>(
          create: (_) => DiagramaRepository(dbHelper),
        ),
        Provider<InjuryTypeRepository>(
          create: (_) => InjuryTypeRepository(dbHelper),
        ),

        Provider<ApiClient>(
          create: (_) => ApiClient(keyStorage),
        ),
        Provider<IRemoteDataSource>(
          create: (ctx) => RemoteDataSourceImpl(ctx.read<ApiClient>()),
        ),

        ProxyProvider2<UsuarioRepository, IRemoteDataSource, AuthService>(
          update: (_, repo, remoteDS, prev) =>
              prev ?? AuthService(repo, keyStorage, remoteDS),
        ),
        ProxyProvider2<CasoRepository, UsuarioRepository, CaseService>(
          update: (_, casoRepo, usuarioRepo, __) => CaseService(casoRepo, usuarioRepo),
        ),
        ProxyProvider<UsuarioRepository, UserService>(
          update: (_, repo, __) => UserService(repo),
        ),
        ProxyProvider<AchadoRepository, AchadoService>(
          update: (_, achadoRepo, __) => AchadoService(achadoRepo),
        ),

        ProxyProvider2<IRemoteDataSource, InjuryTypeRepository, DomainSyncService>(
          update: (_, remoteDS, injuryTypeRepo, prev) =>
              prev ?? DomainSyncService(
                remoteDataSource: remoteDS,
                injuryTypeRepository: injuryTypeRepo,
              ),
        ),
        ProxyProvider2<IRemoteDataSource, CasoRepository, SyncService>(
          update: (_, remoteDS, casoRepo, __) => SyncService(
            remoteDataSource: remoteDS,
            repository: casoRepo,
          ),
        ),
        ChangeNotifierProxyProvider3<AuthService, ApiClient, DomainSyncService, AuthProvider>(
          create: (ctx) => AuthProvider(ctx.read<AuthService>()),
          update: (_, authService, apiClient, domainSync, previous) {
            previous!.updateService(authService);
            previous.updateDomainSyncService(domainSync);
            apiClient.onSessionExpired = () => previous.onSessionExpired();
            return previous;
          },
        ),

        ChangeNotifierProxyProvider<CaseService, CaseListProvider>(
          create: (ctx) => CaseListProvider(ctx.read<CaseService>()),
          update: (_, caseService, previous) => previous!..updateService(caseService),
        ),

        ChangeNotifierProxyProvider<UserService, UserManagementProvider>(
          create: (ctx) => UserManagementProvider(ctx.read<UserService>()),
          update: (_, userService, previous) => previous!..updateService(userService),
        ),

        ChangeNotifierProxyProvider<SyncService, SyncProvider>(
          create: (ctx) => SyncProvider(ctx.read<SyncService>()),
          update: (_, syncService, previous) => previous!..updateService(syncService),
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
      title: 'Necropsia Digital',
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