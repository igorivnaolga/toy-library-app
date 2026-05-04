/// Thrown when the backend returns a non-success status or malformed JSON.
final class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => "ApiException($statusCode): $message";
}
