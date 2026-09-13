import 'package:flutter/material.dart';

import 'package:croqui_forense_mvp/presentation/pages/controllers/croqui_controller.dart';
import 'package:croqui_forense_mvp/presentation/pages/controllers/croqui_controller_result.dart';

/// Orquestra os diálogos e a navegação da finalização sem contaminar o controller.
Future<void> handleCroquiFinalization(
  BuildContext context,
  CroquiController controller,
) async {
  await controller.finalizarCasoDireto(context);
}
