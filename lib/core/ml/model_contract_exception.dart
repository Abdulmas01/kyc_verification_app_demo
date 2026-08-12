class ModelContractException implements Exception {
  const ModelContractException(this.message);

  final String message;

  @override
  String toString() => 'ModelContractException: $message';
}
