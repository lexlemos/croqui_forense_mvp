/// Indica que os dados locais não puderam ser lidos ou validados.
class DatabaseCorruptedException implements Exception {
  final String message;
  final Object? cause;

  const DatabaseCorruptedException(this.message, {this.cause});

  @override
  String toString() => cause == null
      ? 'DatabaseCorruptedException: $message'
      : 'DatabaseCorruptedException: $message ($cause)';
}
