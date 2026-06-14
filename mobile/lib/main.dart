/// Flutter entrypoint.
library;

import "dart:async";

import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "app.dart";
import "core/push_notifications.dart";
import "core/reminder_notifications.dart";

Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Never block first frame on optional services — cap init time on slow emulators.
    try {
      await ReminderNotificationService.instance
          .initialize()
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
    try {
      await PushNotificationService.instance
          .initialize()
          .timeout(const Duration(seconds: 8));
    } catch (_) {}

    const supabaseUrl = String.fromEnvironment("SUPABASE_URL", defaultValue: "");
    const supabaseAnonKey =
        String.fromEnvironment("SUPABASE_ANON_KEY", defaultValue: "");

    if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
    }

    runApp(const ToyLibraryApp());
  }, _onUnhandledAsyncError);
}

/// Supabase may try to refresh a stored session on startup; treat network/DNS
/// failures as "signed out" instead of crashing the isolate.
Future<void> _onUnhandledAsyncError(Object error, StackTrace stack) async {
  if (!_isRecoverableSupabaseNetworkError(error)) {
    FlutterError.presentError(
      FlutterErrorDetails(exception: error, stack: stack),
    );
    return;
  }

  debugPrint("Supabase session refresh failed (offline?): $error");
  try {
    await Supabase.instance.client.auth.signOut();
  } catch (_) {}
}

bool _isRecoverableSupabaseNetworkError(Object error) {
  final type = error.runtimeType.toString();
  if (type.contains("AuthRetryableFetchException")) return true;
  final text = error.toString();
  return text.contains("Failed host lookup") ||
      text.contains("SocketException") ||
      text.contains("Network is unreachable");
}
