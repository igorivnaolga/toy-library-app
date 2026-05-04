/// Holds authentication/session state for the mobile app.
///
/// Typical responsibilities:
/// - store access token + refresh token (secure storage on device)
/// - expose `isLoggedIn`, `role`, `userId`
/// - notify listeners when auth changes (via ChangeNotifier/Riverpod/etc.)
///
/// Guest mode can be represented as "no token" + UI that only enables catalog routes.
class AuthStore {}
