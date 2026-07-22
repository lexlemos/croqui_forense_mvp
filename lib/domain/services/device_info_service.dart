import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

/// Serviço de infraestrutura voltado para a "Rastreabilidade e Auditoria" do dispositivo.
///
/// Este serviço recupera ou gera um identificador único para o tablet ou smartphone utilizado,
/// fornecendo o ID físico do dispositivo. Esta informação é gravada nos logs de auditoria dos laudos
/// e envios de arquivos de modo a certificar a autoria, registrar a origem física do preenchimento e
/// compor de forma robusta e transparente a Cadeia de Custódia forense.
class DeviceInfoService {
  static const String _key = 'device_unique_id';
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static String? _cachedDeviceId;

  /// Obtém o identificador exclusivo do hardware deste dispositivo móvel de maneira persistente.
  ///
  /// Caso o ID ainda não tenha sido registrado na área de armazenamento criptográfico seguro,
  /// um novo UUID v4 é gerado e armazenado de forma persistente. A leitura inicial é mantida
  /// em cache de memória para acessos subsequentes de alta performance.
  ///
  /// Retorna uma [String] correspondente ao ID persistente do dispositivo.
  ///
  /// @throws Exception Se ocorrer uma falha física de acesso de I/O ao chaveiro seguro do sistema
  /// operacional (ex: Keystore no Android ou Keychain no iOS) impossibilitando a leitura ou gravação.
  static Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;

    String? stored = await _storage.read(key: _key);
    if (stored == null || stored.isEmpty) {
      stored = const Uuid().v4();
      await _storage.write(key: _key, value: stored);
    }
    _cachedDeviceId = stored;
    return stored;
  }
}
