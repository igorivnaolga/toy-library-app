import "package:flutter/foundation.dart";

/// Tracks whether the user has opened the app-bar notification bell (per login).
class NotificationBellAckStore extends ChangeNotifier {
  String? _userId;
  bool _memberBellOpened = false;
  bool _adminBellOpened = false;

  void syncUser(String? userId) {
    if (_userId == userId) return;
    _userId = userId;
    _memberBellOpened = false;
    _adminBellOpened = false;
    notifyListeners();
  }

  bool get memberBellOpened => _memberBellOpened;
  bool get adminBellOpened => _adminBellOpened;

  void markMemberBellOpened() {
    if (_memberBellOpened) return;
    _memberBellOpened = true;
    notifyListeners();
  }

  void markAdminBellOpened() {
    if (_adminBellOpened) return;
    _adminBellOpened = true;
    notifyListeners();
  }
}
