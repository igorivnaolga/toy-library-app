import "dart:async";

import "package:firebase_core/firebase_core.dart";
import "package:firebase_messaging/firebase_messaging.dart";
import "package:flutter/foundation.dart";

import "api_client.dart";
import "reminder_notifications.dart";

/// Push reminders via Firebase Cloud Messaging (optional — needs Firebase project).
class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  static const _enabledFlag = bool.fromEnvironment(
    "FIREBASE_ENABLED",
    defaultValue: false,
  );

  FirebaseMessaging? _messaging;
  bool _initialized = false;
  String? _lastRegisteredToken;
  StreamSubscription<String>? _tokenRefreshSub;

  /// FCM token fetch can hang indefinitely on emulators without Google Play.
  static const _tokenTimeout = Duration(seconds: 8);

  bool get isAvailable => _initialized;

  Future<String?> _getTokenSafe() async {
    final messaging = _messaging;
    if (messaging == null) return null;
    try {
      return await messaging.getToken().timeout(_tokenTimeout);
    } on TimeoutException {
      debugPrint("FCM getToken timed out (common on emulators without Play Services).");
      return null;
    } catch (e) {
      debugPrint("FCM getToken failed: $e");
      return null;
    }
  }

  Future<bool> initialize() async {
    if (_initialized) return true;
    if (!_enabledFlag) {
      debugPrint("Firebase push disabled (FIREBASE_ENABLED=false).");
      return false;
    }

    try {
      await Firebase.initializeApp();
      _messaging = FirebaseMessaging.instance;
      FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
      _initialized = true;

      // Do not block app startup on notification permission (or slow emulators).
      unawaited(ReminderNotificationService.instance.ensurePermission());

      _tokenRefreshSub ??= _messaging!.onTokenRefresh.listen((token) {
        unawaited(_registerToken(token));
      });

      return true;
    } catch (e, stack) {
      debugPrint("Firebase init failed: $e\n$stack");
      _messaging = null;
      _initialized = false;
      return false;
    }
  }

  Future<void> syncWithBackend(
    BackendClient? client, {
    required bool remindersEnabled,
  }) async {
    if (!_initialized || client == null || _messaging == null) return;

    if (!remindersEnabled) {
      await unregisterFromBackend(client);
      return;
    }

    final token = await _getTokenSafe();
    if (token == null || token.isEmpty) return;
    await _registerToken(token, client: client);
  }

  Future<void> unregisterFromBackend(BackendClient client) async {
    if (_messaging == null) return;
    final token = _lastRegisteredToken ?? await _getTokenSafe();
    if (token == null || token.isEmpty) return;
    try {
      await client.postJson("/api/v1/notifications/device/unregister", {
        "token": token,
      });
    } catch (e) {
      debugPrint("FCM unregister failed: $e");
    } finally {
      _lastRegisteredToken = null;
    }
  }

  Future<void> dispose() async {
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
  }

  Future<void> _registerToken(
    String token, {
    BackendClient? client,
  }) async {
    final backend = client;
    if (backend == null || token.isEmpty) return;
    if (_lastRegisteredToken == token) return;

    try {
      await backend.postJson("/api/v1/notifications/device", {
        "token": token,
        "platform": defaultTargetPlatform.name,
      });
      _lastRegisteredToken = token;
    } catch (e) {
      debugPrint("FCM register failed: $e");
    }
  }
}

@pragma("vm:entry-point")
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}
