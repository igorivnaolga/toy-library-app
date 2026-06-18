/// User-facing auth errors (Supabase messages are mapped here on the client).
library;

/// Shown when the email is not registered in Supabase auth.
const signInNotMemberMessage =
    "Looks like you are not a member yet. Use Join the library above to register.";

/// Shown when the email exists but the password was rejected.
const signInWrongPasswordMessage =
    "Incorrect password. Please try again or use Forgot password? above to reset it.";

/// Maps Supabase sign-in failures to clear, non-technical copy.
String signInErrorMessage(Object error) {
  final raw = _rawMessage(error).toLowerCase();

  if (raw.contains("invalid login credentials") ||
      raw.contains("invalid credentials") ||
      raw.contains("wrong password") ||
      raw.contains("incorrect password")) {
    return signInWrongPasswordMessage;
  }

  if (raw.contains("email not confirmed") ||
      raw.contains("not confirmed")) {
    return "Please confirm your email first. "
        "Open the link we sent you, then sign in again.";
  }

  if (raw.contains("too many requests") || raw.contains("rate limit")) {
    return "Too many sign-in attempts. Please wait a few minutes and try again.";
  }

  if (raw.contains("network") || raw.contains("socket")) {
    return "Couldn't reach the sign-in service. Check your connection and try again.";
  }

  if (raw.contains("auth is not configured")) {
    return _rawMessage(error);
  }

  return "We couldn't sign you in. Check your email and password, reset your "
      "password, or join the library if you don't have an account yet.";
}

bool isInvalidSignInCredentials(
  Object error, {
  String? statusCode,
}) {
  final raw = _rawMessage(error).toLowerCase();
  if (raw.contains("invalid login credentials") ||
      raw.contains("invalid credentials") ||
      raw.contains("invalid_credentials") ||
      raw.contains("wrong password") ||
      raw.contains("incorrect password")) {
    return true;
  }
  // Supabase often returns HTTP 400 for bad email/password combinations.
  return statusCode == "400" && raw.isEmpty;
}

/// Maps sign-up failures (e.g. email already registered).
String signUpErrorMessage(Object error) {
  final raw = _rawMessage(error).toLowerCase();

  if (raw.contains("already registered") ||
      raw.contains("already exists") ||
      raw.contains("user already")) {
    return "An account with this email already exists. "
        "Sign in instead, or reset your password if you've forgotten it.";
  }

  if (raw.contains("weak password") || raw.contains("password")) {
    return passwordRequirementsMessage;
  }

  if (raw.contains("invalid email")) {
    return "Enter a valid email address.";
  }

  if (raw.contains("network") || raw.contains("socket")) {
    return "Couldn't reach the sign-in service. Check your connection and try again.";
  }

  return "We couldn't create your account. Please check your details and try again.";
}

String passwordResetRequestMessage({required String email}) =>
    "If an account exists for $email, we've sent password reset instructions. "
    "Open the link in that email to choose a new password.";

String passwordResetErrorMessage(Object error) {
  final raw = _rawMessage(error).toLowerCase();

  if (raw.contains("invalid email")) {
    return "Enter a valid email address.";
  }

  if (raw.contains("too many requests") || raw.contains("rate limit")) {
    return "Too many reset requests. Please wait a few minutes and try again.";
  }

  if (raw.contains("network") || raw.contains("socket")) {
    return "Couldn't send the reset email. Check your connection and try again.";
  }

  return "Couldn't send the reset email. Check the address and try again.";
}

const passwordRequirementsMessage =
    "Use at least 8 characters with at least one letter, one number, and one symbol.";

String _rawMessage(Object error) {
  if (error is String) return error.trim();
  return error.toString().trim();
}
