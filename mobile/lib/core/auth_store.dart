import "dart:async";

import "package:flutter/foundation.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "api_client.dart";
import "api_exception.dart";
import "push_notifications.dart";
import "reminder_sync.dart";
import "../features/auth/auth_error_messages.dart";
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
  int membershipDueCents = 0;
  bool membershipFeesPaid = true;
  int balanceDueCents = 0;
  int creditBalanceCents = 0;
  bool showPostRegistrationWelcome = false;
  bool _freshAuthAttempt = false;

  bool get isAuthConfigured => _supabase != null;

  bool get isLoggedIn => _supabase?.auth.currentSession != null;
  String? get accessToken => _supabase?.auth.currentSession?.accessToken;

  bool get isGuest => role == AppRole.guest;
  bool get isMember => role == AppRole.member;
  bool get isVolunteer => role == AppRole.volunteer;
  bool get isAdmin => role == AppRole.admin;

  /// Duty-tier member waiting for admin to confirm volunteer access.
  bool get isVolunteerApprovalPending =>
      membershipTier == "duty" && !volunteerConfirmed && role == AppRole.member;

  bool get canBookToys => isMember || isVolunteer;

  bool get hasPendingMembershipFees =>
      (isMember || isVolunteer) && !membershipFeesPaid;

  void markPostRegistrationWelcome() {
    showPostRegistrationWelcome = true;
    notifyListeners();
  }

  void dismissPostRegistrationWelcome() {
    if (!showPostRegistrationWelcome) return;
    showPostRegistrationWelcome = false;
    notifyListeners();
  }

  void clearError() {
    if (error == null) return;
    error = null;
    notifyListeners();
  }

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
    _freshAuthAttempt = true;
    notifyListeners();
    try {
      await supa.auth
          .signInWithPassword(email: email.trim(), password: password);
      await refreshProfile(silent: false);
    } on AuthException catch (e) {
      error = await _resolveSignInError(e, email.trim());
    } catch (e) {
      error = signInErrorMessage(e);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<String> _resolveSignInError(AuthException exception, String email) async {
    if (!isInvalidSignInCredentials(
      exception.message,
      statusCode: exception.statusCode,
    )) {
      return signInErrorMessage(exception.message);
    }
    final registered = await _lookupEmailRegistered(email);
    if (registered == false) {
      return signInNotMemberMessage;
    }
    return signInWrongPasswordMessage;
  }

  Future<bool?> _lookupEmailRegistered(String email) async {
    final backend = _backend;
    if (backend == null || email.isEmpty) return null;
    try {
      final json = await backend.getJson(
        "/api/v1/auth/email-registered",
        {"email": email},
      );
      return json["registered"] as bool?;
    } catch (_) {
      return null;
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
    _freshAuthAttempt = true;
    notifyListeners();
    try {
      await supa.auth.signUp(email: email.trim(), password: password);
      await refreshProfile(silent: false);
    } on AuthException catch (e) {
      error = signUpErrorMessage(e.message);
    } catch (e) {
      error = signUpErrorMessage(e);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Drops stale Supabase sessions that never finished membership setup so the
  /// app opens on the public catalog with Sign in (not the membership picker).
  Future<void> handleIncompleteRestoredSession() async {
    if (profileLoading || !isLoggedIn || isAdmin) return;
    if (_freshAuthAttempt) {
      _freshAuthAttempt = false;
      return;
    }
    if (!needsMembershipOnboarding) return;
    await signOut();
  }

  /// Sends a password-reset email via Supabase. Always returns true on success;
  /// the UI uses generic copy so callers cannot infer whether the email exists.
  Future<bool> requestPasswordReset({required String email}) async {
    final supa = _supabase;
    if (supa == null) {
      error =
          "Auth is not configured. Start the app with SUPABASE_URL and SUPABASE_ANON_KEY.";
      notifyListeners();
      return false;
    }
    loading = true;
    error = null;
    notifyListeners();
    try {
      await supa.auth.resetPasswordForEmail(email.trim());
      return true;
    } on AuthException catch (e) {
      error = passwordResetErrorMessage(e.message);
      return false;
    } catch (e) {
      error = passwordResetErrorMessage(e);
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    final backend = _backend;
    if (backend != null) {
      await PushNotificationService.instance.unregisterFromBackend(backend);
    }
    final supa = _supabase;
    if (supa != null) {
      await supa.auth.signOut();
    }
    await ReminderSync.clear();
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
    const maxAttempts = 2;
    Object? lastError;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      try {
        final me = await backend
            .getJson("/api/v1/auth/me")
            .timeout(const Duration(seconds: 12));
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
        membershipDueCents = (me["membership_due_cents"] as num?)?.toInt() ?? 0;
        membershipFeesPaid = me["membership_fees_paid"] != false;
        balanceDueCents = (me["balance_due_cents"] as num?)?.toInt() ?? 0;
        creditBalanceCents = (me["credit_balance_cents"] as num?)?.toInt() ?? 0;
        unawaited(
          PushNotificationService.instance.syncWithBackend(
            backend,
            remindersEnabled:
                canBookToys && contact.textRemindersConsent == true,
          ),
        );
        return;
      } catch (e) {
        lastError = e;
        if (attempt < maxAttempts - 1 && isJwtClockSkewError(e)) continue;
        throw lastError;
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
    membershipDueCents = 0;
    membershipFeesPaid = true;
    balanceDueCents = 0;
    creditBalanceCents = 0;
    showPostRegistrationWelcome = false;
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
