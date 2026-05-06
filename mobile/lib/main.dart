/// Flutter entrypoint.
library;

import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "app.dart";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = String.fromEnvironment("SUPABASE_URL", defaultValue: "");
  const supabaseAnonKey =
      String.fromEnvironment("SUPABASE_ANON_KEY", defaultValue: "");

  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }

  runApp(const ToyLibraryApp());
}
