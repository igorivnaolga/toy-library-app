/// Flutter entrypoint.
library;

import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "app.dart";
import "core/push_notifications.dart";
import "core/reminder_notifications.dart";

Future<void> main() async {
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
}
