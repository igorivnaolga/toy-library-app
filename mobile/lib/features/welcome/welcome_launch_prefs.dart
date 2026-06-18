import "package:shared_preferences/shared_preferences.dart";

/// Persists whether the one-time app welcome screen has been shown.
abstract final class WelcomeLaunchPrefs {
  static const _key = "welcome_screen_seen_v1";

  static Future<bool> hasSeenWelcome() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  static Future<void> markWelcomeSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }
}
