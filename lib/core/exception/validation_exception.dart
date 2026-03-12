class ValidationException implements Exception {
  final List<String> erros;

  ValidationException({required this.erros});
}
