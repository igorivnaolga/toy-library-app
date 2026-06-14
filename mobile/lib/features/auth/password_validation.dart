import "auth_error_messages.dart";

/// Client-side password rules aligned with common auth provider minimums.
class PasswordValidation {
  PasswordValidation._();

  static const int minLength = 8;
  static const int maxLength = 128;

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
    if (!RegExp(r"[A-Za-z]").hasMatch(password)) {
      return "Password must include at least one letter.";
    }
    if (!RegExp(r"\d").hasMatch(password)) {
      return "Password must include at least one number.";
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

  static String get requirementsHint => passwordRequirementsMessage;
}
