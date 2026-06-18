import "dart:math";

import "auth_error_messages.dart";

/// Client-side password rules for registration (Supabase may enforce additional checks).
class PasswordValidation {
  PasswordValidation._();

  static const int minLength = 8;
  static const int maxLength = 128;
  static const int suggestedPasswordLength = 16;

  static final RegExp _letterPattern = RegExp(r"[A-Za-z]");
  static final RegExp _digitPattern = RegExp(r"\d");
  static final RegExp _symbolPattern = RegExp(r"[^A-Za-z0-9]");

  static String? validate(String? value) {
    final password = value ?? "";
    if (password.isEmpty) {
      return "Enter a password.";
    }
    if (password.length < minLength) {
      return "Password must be at least $minLength characters.";
    }
    if (password.length > maxLength) {
      return "Password must be at most $maxLength characters.";
    }
    if (!_letterPattern.hasMatch(password)) {
      return "Password must include at least one letter.";
    }
    if (!_digitPattern.hasMatch(password)) {
      return "Password must include at least one number.";
    }
    if (!_symbolPattern.hasMatch(password)) {
      return "Password must include at least one symbol (e.g. ! @ #).";
    }
    return null;
  }

  static String? validateConfirmation(String? password, String? confirmation) {
    final passwordError = validate(password);
    if (passwordError != null) return passwordError;
    if ((confirmation ?? "") != (password ?? "")) {
      return "Passwords do not match.";
    }
    return null;
  }

  /// Fills registration fields with a random password meeting [validate] rules.
  static String generateStrongPassword({int length = suggestedPasswordLength}) {
    final safeLength = length.clamp(minLength, maxLength);
    const lower = "abcdefghijklmnopqrstuvwxyz";
    const upper = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    const digits = "0123456789";
    const symbols = "!@#\$%^&*-_+=";
    final random = Random.secure();

    final chars = <String>[
      lower[random.nextInt(lower.length)],
      upper[random.nextInt(upper.length)],
      digits[random.nextInt(digits.length)],
      symbols[random.nextInt(symbols.length)],
    ];
    const all = lower + upper + digits + symbols;
    while (chars.length < safeLength) {
      chars.add(all[random.nextInt(all.length)]);
    }
    chars.shuffle(random);
    return chars.join();
  }

  static String get requirementsHint => passwordRequirementsMessage;
}
