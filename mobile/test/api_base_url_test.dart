import "package:flutter/foundation.dart";
import "package:flutter_test/flutter_test.dart";
import "package:toy_library_mobile/core/api_base_url.dart";

String _resolve({
  String apiBase = "",
  bool useAdbReverse = false,
  bool isRelease = false,
  bool isWeb = false,
  TargetPlatform platform = TargetPlatform.android,
}) =>
    resolveApiBaseUrlFor(
      apiBase: apiBase,
      useAdbReverse: useAdbReverse,
      isRelease: isRelease,
      isWeb: isWeb,
      platform: platform,
    );

void main() {
  group("release builds", () {
    test("use the configured https API_BASE without trailing slash", () {
      expect(
        _resolve(apiBase: "https://api.example.org/", isRelease: true),
        "https://api.example.org",
      );
    });

    test("fail fast when API_BASE is missing", () {
      expect(() => _resolve(isRelease: true), throwsStateError);
    });

    test("reject plain http", () {
      expect(
        () => _resolve(apiBase: "http://192.168.1.8:8000", isRelease: true),
        throwsStateError,
      );
    });

    test("ignore USE_ADB_REVERSE", () {
      expect(
        _resolve(apiBase: "https://api.example.org", useAdbReverse: true, isRelease: true),
        "https://api.example.org",
      );
    });
  });

  group("debug builds", () {
    test("adb reverse wins on Android", () {
      expect(
        _resolve(apiBase: "http://192.168.1.8:8000", useAdbReverse: true),
        "http://127.0.0.1:8000",
      );
    });

    test("fall back to the emulator host", () {
      expect(_resolve(), "http://10.0.2.2:8000");
    });
  });
}
