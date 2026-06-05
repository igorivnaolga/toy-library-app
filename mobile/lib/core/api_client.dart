import "dart:convert";

import "package:http/http.dart" as http;

import "api_base_url.dart";
import "api_exception.dart";

/// Minimal contract for backend JSON calls.
abstract class BackendClient {
  Future<Map<String, dynamic>> getJson(String path,
      [Map<String, String>? query]);

  Future<Map<String, dynamic>> patchJson(
      String path, Map<String, dynamic> body);

  Future<Map<String, dynamic>> postJson(String path,
      [Map<String, dynamic>? body]);

  Future<Map<String, dynamic>> postMultipartImage(
    String path, {
    required String fileField,
    required String filePath,
    Map<String, String>? fields,
  });

  Future<Map<String, dynamic>> deleteJson(String path);
}

/// Returns a Bearer token used by [ApiClient] (or null for guest requests).
typedef TokenProvider = String? Function();

/// HTTP client for the Toy Library FastAPI service.
class ApiClient implements BackendClient {
  ApiClient(
      {http.Client? httpClient, String? baseUrl, TokenProvider? tokenProvider})
      : _http = httpClient ?? http.Client(),
        _baseUrl = baseUrl ?? resolveApiBaseUrl(),
        _tokenProvider = tokenProvider;

  final http.Client _http;
  final String _baseUrl;
  final TokenProvider? _tokenProvider;

  Uri _uri(String path, Map<String, String>? query) {
    final normalized = path.startsWith("/") ? path : "/$path";
    final base = _baseUrl.endsWith("/")
        ? _baseUrl.substring(0, _baseUrl.length - 1)
        : _baseUrl;
    return Uri.parse("$base$normalized").replace(queryParameters: query);
  }

  Map<String, String> _headers() {
    final token = _tokenProvider?.call();
    if (token == null || token.isEmpty) return const {};
    return {"Authorization": "Bearer $token"};
  }

  @override
  Future<Map<String, dynamic>> getJson(String path,
      [Map<String, String>? query]) async {
    final uri = _uri(path, query);
    final response = await _http
        .get(uri, headers: _headers())
        .timeout(const Duration(seconds: 20));
    return _decodeObject(response);
  }

  Map<String, dynamic> _decodeObject(http.Response response) {
    final code = response.statusCode;
    if (code < 200 || code >= 300) {
      final body = response.body;
      final snippet = body.length > 200 ? "${body.substring(0, 200)}…" : body;
      throw ApiException("Request failed: $snippet", statusCode: code);
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw ApiException("Expected JSON object, got ${decoded.runtimeType}",
          statusCode: code);
    }
    return decoded;
  }

  @override
  Future<Map<String, dynamic>> patchJson(
      String path, Map<String, dynamic> body) async {
    final uri = _uri(path, null);
    final response = await _http
        .patch(
          uri,
          headers: {
            ..._headers(),
            "Content-Type": "application/json; charset=utf-8",
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));
    return _decodeObject(response);
  }

  @override
  Future<Map<String, dynamic>> postJson(String path,
      [Map<String, dynamic>? body]) async {
    final uri = _uri(path, null);
    final response = await _http
        .post(
          uri,
          headers: {
            ..._headers(),
            "Content-Type": "application/json; charset=utf-8",
          },
          body: body == null || body.isEmpty ? "{}" : jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));
    return _decodeObject(response);
  }

  @override
  Future<Map<String, dynamic>> postMultipartImage(
    String path, {
    required String fileField,
    required String filePath,
    Map<String, String>? fields,
  }) async {
    final uri = _uri(path, null);
    final request = http.MultipartRequest("POST", uri);
    request.headers.addAll(_headers());
    if (fields != null) {
      request.fields.addAll(fields);
    }
    request.files.add(await http.MultipartFile.fromPath(fileField, filePath));
    final streamed =
        await _http.send(request).timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamed);
    return _decodeObject(response);
  }

  @override
  Future<Map<String, dynamic>> deleteJson(String path) async {
    final uri = _uri(path, null);
    final response = await _http
        .delete(uri, headers: _headers())
        .timeout(const Duration(seconds: 20));
    return _decodeObject(response);
  }

  void close() {
    _http.close();
  }
}
