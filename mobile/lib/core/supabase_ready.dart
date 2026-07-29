/// Tracks whether [Supabase.initialize] completed successfully.
/// Prefer this over [Supabase.instance] on web — the latter asserts / throws
/// when auth was never configured.
bool supabaseInitialized = false;
