import "dart:async";

import "package:flutter/foundation.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "api_client.dart";
import "api_exception.dart";
import "../features/profile/kid_profile.dart";
import "../features/profile/member_contact_info.dart";

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
    profileLoading = true;
    _wireSupabaseListener();
    unawaited(refreshProfile());
  }

  /// Test/preview mode with no Supabase dependency.
  AuthStore.guest()
      : _backend = null,
        _supabase = null,
        profileLoading = false;

  final BackendClient? _backend;
  final SupabaseClient? _supabase;

  StreamSubscription<AuthState>? _authSub;

  bool loading = false;
  /// True until the first `/auth/me` fetch finishes after startup or sign-in.
  bool profileLoading = false;
  String? error;

  String? userId;
  String? email;
  String? fullName;
  AppRole role = AppRole.guest;
  String? membershipTier;
  bool volunteerConfirmed = false;
  List<String> kidsNames = const [];
  List<KidProfile> kids = const [];
  String? avatarPath;
  MemberContactInfo contact = const MemberContactInfo();

  bool get isAuthConfigured => _supabase != null;

  bool get isLoggedIn => _supabase?.auth.currentSession != null;
  String? get accessToken => _supabase?.auth.currentSession?.accessToken;

  bool get isGuest => role == AppRole.guest;
  bool get isMember => role == AppRole.member;
  bool get isVolunteer => role == AppRole.volunteer;
  bool get isAdmin => role == AppRole.admin;

  bool get canBookToys => isMember || isVolunteer;

  /// Logged-in non-admin still needs onboarding when the backend has no tier yet.
  bool get needsMembershipOnboarding {
    if (!isLoggedIn || isAdmin) return false;
    final t = membershipTier;
    return error == null && (t == null || t.trim().isEmpty);
  }

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
      await refreshProfile(silent: false);
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
      await refreshProfile(silent: false);
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

  Future<void> refreshProfile({bool silent = false}) async {
    final supa = _supabase;
    final backend = _backend;
    if (supa == null || backend == null) return;
    final session = supa.auth.currentSession;
    if (session == null) {
      _setGuest();
      notifyListeners();
      return;
    }
    if (!silent) {
      profileLoading = true;
      notifyListeners();
    }
    try {
      await _fetchProfileFromBackend(backend);
      error = null;
    } catch (e) {
      // Keep user signed in but treat as guest if backend profile isn't ready yet.
      role = AppRole.guest;
      membershipTier = null;
      volunteerConfirmed = false;
      kidsNames = const [];
      kids = const [];
      avatarPath = null;
      contact = const MemberContactInfo();
      error = authProfileErrorMessage(e);
    } finally {
      if (!silent) {
        profileLoading = false;
      }
      notifyListeners();
    }
  }

  Future<void> _fetchProfileFromBackend(BackendClient backend) async {
    const maxAttempts = 3;
    Object? lastError;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
      }
      try {
        final me = await backend.getJson("/api/v1/auth/me");
        userId = me["user_id"]?.toString();
        email = me["email"]?.toString();
        fullName = me["full_name"]?.toString();
        role = parseRole(me["role"]?.toString());
        membershipTier = me["membership_tier"]?.toString();
        volunteerConfirmed = me["volunteer_confirmed"] == true;
        kids = _parseKids(me);
        kidsNames = kids.map((kid) => kid.name).toList();
        avatarPath = me["avatar_path"]?.toString();
        contact = MemberContactInfo.fromJson(me);
        return;
      } catch (e) {
        lastError = e;
        if (attempt < maxAttempts - 1 && isJwtClockSkewError(e)) continue;
        throw lastError!;
      }
    }
  }

  void _wireSupabaseListener() {
    final supa = _supabase;
    if (supa == null) return;
    _authSub = supa.auth.onAuthStateChange.listen((_) {
      unawaited(refreshProfile(silent: true));
    });
  }

  void _setGuest() {
    userId = null;
    email = null;
    fullName = null;
    role = AppRole.guest;
    membershipTier = null;
    volunteerConfirmed = false;
    kidsNames = const [];
    kids = const [];
    avatarPath = null;
    contact = const MemberContactInfo();
    error = null;
    profileLoading = false;
  }

  static List<KidProfile> _parseKids(Map<String, dynamic> me) {
    final structured = parseKidsList(me["kids"]);
    if (structured.isNotEmpty) return structured;
    return _parseKidsNames(me["kids_names"])
        .map((name) => KidProfile(name: name))
        .toList();
  }

  static List<String> _parseKidsNames(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .map((item) => item?.toString().trim() ?? "")
        .where((name) => name.isNotEmpty)
        .toList();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}

/// True when the backend rejects the token because `iat`/`nbf` is in the future.
bool isJwtClockSkewError(Object error) {
  final text = error.toString().toLowerCase();
  return text.contains("not yet valid") &&
      (text.contains("iat") || text.contains("nbf"));
}

String authProfileErrorMessage(Object error) {
  if (isJwtClockSkewError(error)) {
    return "Couldn't load your profile: your device clock may be ahead of the "
        "server. Check date & time settings (use automatic time) and try again.";
  }
  if (error is ApiException) {
    return "Couldn't load your profile: ${error.message}";
  }
  return "Couldn't load your profile: $error";
}
