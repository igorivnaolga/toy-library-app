import "dart:convert";
import "dart:io";

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
    Duration? timeout,
  });

  Future<Map<String, dynamic>> postMultipartBytes(
    String path, {
    required String fileField,
    required List<int> bytes,
    Map<String, String>? fields,
    Duration? timeout,
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

  String _errorMessageFromBody(String body) {
    if (body.isEmpty) return "Request failed (empty response).";
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded["detail"];
        if (detail is String && detail.isNotEmpty) return detail;
        if (detail is List && detail.isNotEmpty) {
          return detail.map((item) => item.toString()).join("; ");
        }
      }
    } catch (_) {
      // Fall back to raw body below.
    }
    return body.length > 200 ? "${body.substring(0, 200)}…" : body;
  }

  Map<String, dynamic> _decodeObject(http.Response response) {
    final code = response.statusCode;
    if (code < 200 || code >= 300) {
      final body = response.body;
      final message = _errorMessageFromBody(body);
      throw ApiException(message, statusCode: code);
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
    Duration? timeout,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw ApiException("Photo file not found on device.", statusCode: 0);
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw ApiException("Photo file is empty.", statusCode: 0);
    }
    return postMultipartBytes(
      path,
      fileField: fileField,
      bytes: bytes,
      fields: fields,
      timeout: timeout,
    );
  }

  @override
  Future<Map<String, dynamic>> postMultipartBytes(
    String path, {
    required String fileField,
    required List<int> bytes,
    Map<String, String>? fields,
    Duration? timeout,
  }) async {
    final uri = _uri(path, null);
    final request = http.MultipartRequest("POST", uri);
    request.headers.addAll(_headers());
    if (fields != null) {
      request.fields.addAll(fields);
    }
    request.files.add(
      http.MultipartFile.fromBytes(
        fileField,
        bytes,
        filename: "desk_photo.jpg",
      ),
    );
    final effectiveTimeout = timeout ?? const Duration(seconds: 60);
    final streamed = await _http.send(request).timeout(effectiveTimeout);
    final response =
        await http.Response.fromStream(streamed).timeout(effectiveTimeout);
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
