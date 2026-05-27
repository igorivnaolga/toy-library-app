import "package:flutter_test/flutter_test.dart";
import "package:toy_library_mobile/app.dart";
import "package:toy_library_mobile/core/api_client.dart";
import "package:toy_library_mobile/core/auth_store.dart";

class _FakeBackend implements BackendClient {
  @override
  Future<Map<String, dynamic>> getJson(String path,
      [Map<String, String>? query]) async {
    if (path == "/api/v1/categories") {
      return {
        "data": [
          {"code": "books", "label": "Books"},
        ],
      };
    }
    if (path == "/api/v1/toys/meta") {
      return {
        "age_ranges": ["5+", "3-5yrs"]
      };
    }
    if (path.startsWith("/api/v1/toys/")) {
      return {
        "toy_id": "t1",
        "name": "Robot",
        "category": "Books",
        "age_range": "5+",
        "status": "available",
        "availability": "available",
        "manufacturer": "Acme",
        "description": "A toy robot",
        "photo_file": null,
      };
    }
    if (path == "/api/v1/toys") {
      return {
        "data": [
          {
            "toy_id": "t1",
            "name": "Robot",
            "category": "Books",
            "age_range": "5+",
            "status": "available",
            "availability": "available",
            "manufacturer": null,
            "description": null,
            "photo_file": null,
          },
        ],
        "meta": {"page": 1, "limit": 20, "total": 1, "has_next": false},
      };
    }
    throw UnsupportedError(path);
  }

  @override
  Future<Map<String, dynamic>> patchJson(
      String path, Map<String, dynamic> body) {
    throw UnsupportedError(path);
  }

  @override
  Future<Map<String, dynamic>> postJson(String path,
      [Map<String, dynamic>? body]) {
    throw UnsupportedError(path);
  }

  @override
  Future<Map<String, dynamic>> deleteJson(String path) {
    throw UnsupportedError(path);
  }
}

void main() {
  testWidgets("ToyLibraryApp loads catalog from fake API",
      (WidgetTester tester) async {
    await tester.pumpWidget(
        ToyLibraryApp(backend: _FakeBackend(), authStore: AuthStore.guest()));
    expect(find.text("Toy catalog"), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text("Robot"), findsOneWidget);
  });
}
