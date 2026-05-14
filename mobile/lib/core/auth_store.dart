import "dart:async";

import "package:flutter/foundation.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "api_client.dart";

/// App roles from backend `profiles.role`.
enum AppRole { guest, member, volunteer, admin }

AppRole parseRole(String? value) {
  switch ((value ?? "").toLowerCase().trim()) {
    case "member":
      return AppRole.member;
    case "volunteer":
      return AppRole.volunteer;
    case "admin":
      return AppRole.admin;
    default:
      return AppRole.guest;
  }
}

/// Session/auth state backed by Supabase + backend `/api/v1/auth/me` role lookup.
class AuthStore extends ChangeNotifier {
  AuthStore.supabase(this._backend, {SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client {
    _wireSupabaseListener();
    unawaited(refreshProfile());
  }

  /// Test/preview mode with no Supabase dependency.
  AuthStore.guest()
      : _backend = null,
        _supabase = null;

  final BackendClient? _backend;
  final SupabaseClient? _supabase;

  StreamSubscription<AuthState>? _authSub;

  bool loading = false;
  String? error;

  String? userId;
  String? email;
  String? fullName;
  AppRole role = AppRole.guest;

  bool get isLoggedIn => _supabase?.auth.currentSession != null;
  String? get accessToken => _supabase?.auth.currentSession?.accessToken;

  bool get isGuest => role == AppRole.guest;
  bool get isMember => role == AppRole.member;
  bool get isVolunteer => role == AppRole.volunteer;
  bool get isAdmin => role == AppRole.admin;

  Future<void> signIn({required String email, required String password}) async {
    final supa = _supabase;
    if (supa == null) {
      error =
          "Auth is not configured. Start the app with SUPABASE_URL and SUPABASE_ANON_KEY.";
      notifyListeners();
      return;
    }
    loading = true;
    error = null;
    notifyListeners();
    try {
      await supa.auth
          .signInWithPassword(email: email.trim(), password: password);
      await refreshProfile();
    } on AuthException catch (e) {
      error = e.message;
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> signUp({required String email, required String password}) async {
    final supa = _supabase;
    if (supa == null) {
      error =
          "Auth is not configured. Start the app with SUPABASE_URL and SUPABASE_ANON_KEY.";
      notifyListeners();
      return;
    }
    loading = true;
    error = null;
    notifyListeners();
    try {
      await supa.auth.signUp(email: email.trim(), password: password);
      await refreshProfile();
    } on AuthException catch (e) {
      error = e.message;
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    final supa = _supabase;
    if (supa != null) {
      await supa.auth.signOut();
    }
    _setGuest();
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    final supa = _supabase;
    final backend = _backend;
    if (supa == null || backend == null) return;
    final session = supa.auth.currentSession;
    if (session == null) {
      _setGuest();
      notifyListeners();
      return;
    }
    try {
      final me = await backend.getJson("/api/v1/auth/me");
      userId = me["user_id"]?.toString();
      email = me["email"]?.toString();
      fullName = me["full_name"]?.toString();
      role = parseRole(me["role"]?.toString());
      error = null;
    } catch (e) {
      // Keep user signed in but treat as guest if backend profile isn't ready yet.
      role = AppRole.guest;
      error = "Couldn't load profile role yet: $e";
    }
    notifyListeners();
  }

  void _wireSupabaseListener() {
    final supa = _supabase;
    if (supa == null) return;
    _authSub = supa.auth.onAuthStateChange.listen((_) {
      unawaited(refreshProfile());
    });
  }

  void _setGuest() {
    userId = null;
    email = null;
    fullName = null;
    role = AppRole.guest;
    error = null;
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
