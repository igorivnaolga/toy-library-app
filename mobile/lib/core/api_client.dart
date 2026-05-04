import "dart:convert";

import "package:http/http.dart" as http;

import "api_base_url.dart";
import "api_exception.dart";

/// Minimal contract for JSON GET calls used by the catalog feature.
///
/// Implemented by [ApiClient]; tests can supply a fake implementation.
abstract class BackendClient {
  Future<Map<String, dynamic>> getJson(String path, [Map<String, String>? query]);
}

/// HTTP client for the Toy Library FastAPI service.
class ApiClient implements BackendClient {
  ApiClient({http.Client? httpClient, String? baseUrl})
      : _http = httpClient ?? http.Client(),
        _baseUrl = baseUrl ?? resolveApiBaseUrl();

  final http.Client _http;
  final String _baseUrl;

  Uri _uri(String path, Map<String, String>? query) {
    final normalized = path.startsWith("/") ? path : "/$path";
    final base = _baseUrl.endsWith("/") ? _baseUrl.substring(0, _baseUrl.length - 1) : _baseUrl;
    return Uri.parse("$base$normalized").replace(queryParameters: query);
  }

  @override
  Future<Map<String, dynamic>> getJson(String path, [Map<String, String>? query]) async {
    final uri = _uri(path, query);
    final response = await _http.get(uri).timeout(const Duration(seconds: 20));
    final code = response.statusCode;
    if (code < 200 || code >= 300) {
      final body = response.body;
      final snippet = body.length > 200 ? "${body.substring(0, 200)}…" : body;
      throw ApiException("Request failed: $snippet", statusCode: code);
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw ApiException("Expected JSON object, got ${decoded.runtimeType}", statusCode: code);
    }
    return decoded;
  }

  void close() {
    _http.close();
  }
}
