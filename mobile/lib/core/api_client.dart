/// HTTP wrapper for talking to the FastAPI backend.
///
/// Typical responsibilities:
/// - base URL selection (dev vs prod)
/// - JSON encode/decode
/// - attaching `Authorization: Bearer ...` when logged in
/// - consistent error mapping (401/403/500 -> UI-friendly exceptions)
///
/// This is intentionally empty right now; it exists as a folder-level contract so
/// features don't import `http` directly everywhere.
class ApiClient {}
