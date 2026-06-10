import "package:flutter/foundation.dart";
import "package:image_picker/image_picker.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "../../core/api_client.dart";
import "../../core/auth_store.dart";
import "kid_profile.dart";
import "member_contact_info.dart";

/// Editable profile state backed by `/api/v1/auth/me/profile`.
class ProfileController extends ChangeNotifier {
  ProfileController(this._backend, this._auth);

  final BackendClient _backend;
  final AuthStore _auth;
  final ImagePicker _picker = ImagePicker();

  String fullName = "";
  List<KidProfile> kids = [];
  String? avatarPath;
  MemberContactInfo contact = const MemberContactInfo();
  bool saving = false;
  bool uploadingAvatar = false;
  String? error;

  void syncFromAuth() {
    fullName = _auth.fullName ?? "";
    kids = List<KidProfile>.from(_auth.kids);
    avatarPath = _auth.avatarPath;
    contact = _auth.contact;
    error = null;
    notifyListeners();
  }

  Future<bool> addKid(String name, {required DateTime birthDate}) async {
    final cleaned = name.trim();
    if (cleaned.isEmpty) return false;
    kids = [
      ...kids,
      KidProfile(
        name: cleaned,
        birthDate: DateTime(
          birthDate.year,
          birthDate.month,
          birthDate.day,
        ),
      ),
    ];
    notifyListeners();
    return saveKids();
  }

  Future<bool> removeKid(int index) async {
    if (index < 0 || index >= kids.length) return false;
    kids = [...kids.sublist(0, index), ...kids.sublist(index + 1)];
    notifyListeners();
    return saveKids();
  }

  Future<bool> saveKids() async {
    saving = true;
    error = null;
    notifyListeners();
    try {
      await _backend.patchJson("/api/v1/auth/me/profile", {
        "kids": kids.map((kid) => kid.toJson()).toList(),
      });
      await _auth.refreshProfile(silent: true);
      syncFromAuth();
      return true;
    } catch (e) {
      kids = List<KidProfile>.from(_auth.kids);
      error = e.toString();
      notifyListeners();
      return false;
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<bool> pickAndUploadAvatar(ImageSource source) async {
    final userId = _auth.userId;
    if (userId == null || userId.isEmpty) {
      error = "Sign in to upload an avatar.";
      notifyListeners();
      return false;
    }

    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null) return false;

    uploadingAvatar = true;
    error = null;
    notifyListeners();

    try {
      final supabase = Supabase.instance.client;
      final previousPath = avatarPath;
      // Unique filename per upload so the public URL changes and clients
      // don't show a cached copy of the previous avatar.
      final storagePath =
          "$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg";
      final bytes = await picked.readAsBytes();
      await supabase.storage.from("avatars").uploadBinary(
            storagePath,
            bytes,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: "image/jpeg",
            ),
          );

      await _backend.patchJson("/api/v1/auth/me/profile", {
        "avatar_path": storagePath,
      });
      avatarPath = storagePath;

      if (previousPath != null &&
          previousPath.isNotEmpty &&
          previousPath != storagePath &&
          !previousPath.startsWith("http")) {
        try {
          await supabase.storage.from("avatars").remove([previousPath]);
        } catch (_) {
          // Old avatar cleanup is best-effort; ignore failures.
        }
      }

      await _auth.refreshProfile(silent: true);
      syncFromAuth();
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    } finally {
      uploadingAvatar = false;
      notifyListeners();
    }
  }
}
