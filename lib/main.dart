import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:croqui_forense_mvp/core/network/api_client.dart';
import 'package:croqui_forense_mvp/core/security/secure_key_storage.dart';
import 'package:croqui_forense_mvp/domain/repositories/remote_data_source.dart';
import 'package:croqui_forense_mvp/data/datasources/remote_data_source_impl.dart';
import 'package:croqui_forense_mvp/data/local/database_factory_impl.dart';
import 'package:croqui_forense_mvp/data/local/database_helper.dart';
import 'package:croqui_forense_mvp/core/utils/globals.dart';
import 'package:croqui_forense_mvp/domain/services/local_storage_gc_service.dart';

import 'package:croqui_forense_mvp/data/repositories/usuario_repository.dart';
import 'package:croqui_forense_mvp/data/repositories/caso_repository.dart';
import 'package:croqui_forense_mvp/data/repositories/achado_repository.dart';
import 'package:croqui_forense_mvp/data/repositories/diagrama_repository.dart';
import 'package:croqui_forense_mvp/data/repositories/injury_type_repository.dart';
import 'package:croqui_forense_mvp/data/repositories/atn_repository.dart';

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
import 'package:croqui_forense_mvp/core/theme/app_colors.dart';import 'package:sentry_flutter/sentry_flutter.dart';


import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  await dotenv.load(fileName: ".env");
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    Sentry.captureException(details.exception, stackTrace: details.stack);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    Sentry.captureException(error, stackTrace: stack);
    return true;
  };

  final dbFactory = DatabaseFactoryImpl();
  final keyStorage = SecureKeyStorage();

  DatabaseHelper.init(dbFactory, keyStorage);

  // Garbage Collection: expurga arquivos físicos e registros SQLite de laudos
  // finalizados, sincronizados na nuvem e com mais de 30 dias.
  // O bloco try/catch garante que uma falha na limpeza nunca impeça o app de abrir.
  try {
    await LocalStorageGcService(
      dbHelper: DatabaseHelper.instance,
    ).executarLimpezaDeRotina();
  } catch (e) {
    debugPrint('[GC] ⚠️ Falha silenciosa na rotina de Garbage Collection: $e');
  }

  await SentryFlutter.init(
    (options) {
      options.dsn = dotenv.env['SENTRY_DSN'];
      // Set tracesSampleRate to 1.0 to capture 100% of transactions for tracing.
      // We recommend adjusting this value in production.
      options.tracesSampleRate = 1.0;
      // The sampling rate for profiling is relative to tracesSampleRate
      // Setting to 1.0 will profile 100% of sampled transactions:
      options.profilesSampleRate = 1.0;
      
      options.beforeSend = (event, hint) {
        try {
          final bool isConnectivityError = event.exceptions?.any((e) {
            final type = e.type?.toLowerCase() ?? '';
            return type.contains('socketexception') ||
                   type.contains('handshakeexception') ||
                   type.contains('timeoutexception');
          }) ?? false;

          if (isConnectivityError) {
            return null; 
          }

          final cpfRegex = RegExp(r'\b\d{3}\.\d{3}\.\d{3}-\d{2}\b|\b\d{11}\b');
          final laudoRegex = RegExp(r'"dados_laudo"\s*:\s*\{.*?\}', dotAll: true);

          String maskData(String? input) {
            if (input == null) return '';
            var masked = input.replaceAll(cpfRegex, '[CPF_MASCARADO]');
            masked = masked.replaceAll(laudoRegex, '"dados_laudo": "[DADOS_MASCARADOS]"');
            return masked;
          }

          if (event.message != null) {
            event.message!.formatted = maskData(event.message!.formatted);
          }

          event.exceptions?.forEach((e) {
            e.value = maskData(e.value);
            e.type = maskData(e.type);
          });

          event.breadcrumbs?.forEach((b) {
            b.message = maskData(b.message);
            if (b.data != null) {
              final newData = <String, dynamic>{};
              b.data!.forEach((key, value) {
                if (value is String) {
                  newData[key] = maskData(value);
                } else {
                  newData[key] = value;
                }
              });
              b.data!.clear();
              b.data!.addAll(newData);
            }
          });

          return event;
        } catch (e) {
          debugPrint('Sentry beforeSend falhou ao mascarar dados: $e');
          return null; 
        }
      };
    },
    appRunner: () => runApp(SentryWidget(child: const AppRoot())),
  );
  // TODO: Remove this line after sending the first sample event to sentry.
  await Sentry.captureException(Exception('This is a sample exception.'));
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
        Provider<AtnRepository>(
          create: (_) => AtnRepository(dbHelper),
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

        ProxyProvider3<IRemoteDataSource, InjuryTypeRepository, AtnRepository, DomainSyncService>(
          update: (_, remoteDS, injuryTypeRepo, atnRepo, prev) =>
              prev ?? DomainSyncService(
                remoteDataSource: remoteDS,
                injuryTypeRepository: injuryTypeRepo,
                atnRepository: atnRepo,
              ),
        ),
        ProxyProvider4<IRemoteDataSource, CasoRepository, DomainSyncService, AuthService, SyncService>(
          update: (_, remoteDS, casoRepo, domainSync, authService, __) => SyncService(
            remoteDataSource: remoteDS,
            repository: casoRepo,
            authService: authService,
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

        ChangeNotifierProxyProvider3<CaseService, SyncService, AuthService, CaseListProvider>(
          create: (ctx) => CaseListProvider(
            ctx.read<CaseService>(),
            syncService: ctx.read<SyncService>(),
            authService: ctx.read<AuthService>(),
          ),
          update: (_, caseService, syncService, authService, previous) =>
              previous!..updateServices(
                caseService: caseService,
                syncService: syncService,
                authService: authService,
              ),
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
      navigatorKey: globalNavigatorKey,
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
      routes: {
        '/login': (context) => const AuthWrapper(),
      },
    );
  }
}