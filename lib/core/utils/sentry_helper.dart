import 'package:sentry_flutter/sentry_flutter.dart';

class SentryHelper {
  /// Atrela o ID do Usuário (UUID) e o Device ID ao Sentry.
  /// NUNCA enviar nomes reais ou e-mails por questões de privacidade.
  static void setUser({required String userId, required String deviceId}) {
    Sentry.configureScope((scope) {
      scope.setUser(SentryUser(
        id: userId,
        data: {'device_id': deviceId},
      ));
    });
  }

  /// Limpa os dados do usuário no Sentry no momento do logout.
  static void clearUser() {
    Sentry.configureScope((scope) {
      scope.setUser(null);
    });
  }

  /// Adiciona uma tag para sabermos qual laudo quebrou a sincronização.
  static void setSyncErrorTag(String casoUuid) {
    Sentry.configureScope((scope) {
      scope.setTag('sync_caso_uuid', casoUuid);
    });
  }
}
