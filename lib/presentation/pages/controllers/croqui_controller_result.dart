import 'dart:typed_data';

enum CroquiOperationStatus { success, readOnly, error }

class CroquiOperationResult {
  final CroquiOperationStatus status;
  final String? message;
  final Object? error;

  const CroquiOperationResult({required this.status, this.message, this.error});

  bool get succeeded => status == CroquiOperationStatus.success;
}

enum FinishCaseAction {
  confirmExam,
  chooseCompletion,
  keepDraft,
  complete,
  validationError,
  success,
  error,
}

class FinishCaseResult {
  final FinishCaseAction action;
  final String? message;
  final Object? error;

  const FinishCaseResult(this.action, {this.message, this.error});
}

class ExportedPdf {
  final Uint8List bytes;
  final String fileName;

  const ExportedPdf({required this.bytes, required this.fileName});
}
