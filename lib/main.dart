import 'package:flutter/material.dart';
import 'package:croqui_forense_mvp/core/security/secure_key_storage.dart';
import 'package:croqui_forense_mvp/data/local/database_helper.dart';
import 'package:croqui_forense_mvp/data/local/sqlcipher_database_factory.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Configuração de Dependências (Poderia usar GetIt ou Provider aqui)
  // Em produção, usamos as implementações reais:
  final dbFactory = SqlCipherDatabaseFactory();
  final keyStorage = SecureKeyStorage(); // Usa FlutterSecureStorage internamente

  // 2. Inicializa o Singleton do Helper com as dependências
  DatabaseHelper.init(dbFactory, keyStorage);

  // 3. (Opcional) Warm-up do banco para garantir que abre antes da UI
  try {
    await DatabaseHelper.instance.database;
    print("✅ Banco inicializado com sucesso.");
  } catch (e) {
    print("❌ Erro fatal ao abrir banco: $e");
    // TODO: Mostrar tela de erro fatal amigável
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Croqui Forense MVP',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const Scaffold(body: Center(child: Text("Sistema Pronto"))),
    );
  }
}