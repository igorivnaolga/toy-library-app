import "api_exception.dart";

/// User-facing text for errors — avoids raw exceptions and HTTP jargon.
String friendlyErrorMessage(
  Object error, {
  String fallback = "Something went wrong. Please try again.",
  Map<int, String>? statusMessages,
}) {
  if (error is ApiException) {
    final custom = statusMessages?[error.statusCode];
    if (custom != null && custom.isNotEmpty) return custom;

    final message = error.message.trim();
    if (message.isNotEmpty && !_looksTechnical(message)) {
      return message;
    }

    final byStatus = _defaultStatusMessage(error.statusCode);
    if (byStatus != null) return byStatus;
    if (message.isNotEmpty) return message;
    return fallback;
  }

  if (error is Exception) {
    final text = error.toString().replaceFirst("Exception: ", "").trim();
    if (text.isNotEmpty && !_looksTechnical(text)) {
      return _networkMessage(text) ?? text;
    }
  }

  final raw = error.toString().trim();
  return _networkMessage(raw) ?? (raw.isNotEmpty && !_looksTechnical(raw) ? raw : fallback);
}

String? _networkMessage(String text) {
  final lower = text.toLowerCase();
  if (lower.contains("socketexception") ||
      lower.contains("connection refused") ||
      lower.contains("connection closed") ||
      lower.contains("connection reset") ||
      lower.contains("failed host lookup") ||
      lower.contains("network is unreachable") ||
      lower.contains("no route to host")) {
    return "Can't reach the library server. Check your connection and that "
        "the app is pointed at the right address, then try again.";
  }
  if (lower.contains("timeout") || lower.contains("timed out")) {
    return "That took too long. Check your connection and try again.";
  }
  return null;
}

String? _defaultStatusMessage(int? statusCode) {
  switch (statusCode) {
    case 400:
      return "We couldn't complete that request. Please check and try again.";
    case 401:
      return "Please sign in again.";
    case 403:
      return "You don't have permission to do that.";
    case 404:
      return "We couldn't find what you were looking for.";
    case 409:
      return "That isn't available right now. Please try again.";
    case 422:
      return null;
    case 500:
      return "Something went wrong on our side. Please try again in a moment.";
    case 502:
    case 503:
    case 504:
      return "The library server isn't responding. Please try again shortly.";
    default:
      return null;
  }
}

bool _looksTechnical(String message) {
  final trimmed = message.trim();
  if (trimmed.startsWith("ApiException(")) return true;
  if (trimmed.startsWith("Instance of ")) return true;
  if (trimmed.contains("Stack trace:")) return true;
  return false;
}
