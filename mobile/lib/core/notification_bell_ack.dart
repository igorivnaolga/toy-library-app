import "dart:async";
import "dart:math" as math;

import "package:flutter/foundation.dart";
import "package:shared_preferences/shared_preferences.dart";

import "../features/admin/admin_models.dart";

/// Tracks notification counts the user has already seen (persisted per user).
class NotificationBellAckStore extends ChangeNotifier {
  String? _userId;
  int _lastSeenAvailableSlots = 0;
  bool _lastSeenVolunteerApprovalPending = false;
  bool _memberAckLoaded = false;

  int _lastSeenPendingVolunteers = 0;
  int _lastSeenNewMembers = 0;
  bool _adminAckLoaded = false;

  bool get memberAckLoaded => _memberAckLoaded;
  bool get adminAckLoaded => _adminAckLoaded;

  static String _pendingKey(String userId) => "admin_ack_pending_$userId";
  static String _newMembersKey(String userId) => "admin_ack_new_members_$userId";
  static String _memberSlotsKey(String userId) => "member_ack_slots_$userId";
  static String _memberVolunteerPendingKey(String userId) =>
      "member_ack_vol_pending_$userId";

  void syncUser(String? userId) {
    final normalized = userId?.trim();
    if (normalized == _userId && _adminAckLoaded && _memberAckLoaded) return;

    if (normalized == null || normalized.isEmpty) {
      if (_userId == null && !_adminAckLoaded && !_memberAckLoaded) {
        return;
      }
      _userId = null;
      _adminAckLoaded = false;
      _memberAckLoaded = false;
      _lastSeenPendingVolunteers = 0;
      _lastSeenNewMembers = 0;
      _lastSeenAvailableSlots = 0;
      _lastSeenVolunteerApprovalPending = false;
      notifyListeners();
      return;
    }

    final switchedUser = _userId != null && _userId != normalized;
    _userId = normalized;
    if (switchedUser) {
      _lastSeenAvailableSlots = 0;
      _lastSeenVolunteerApprovalPending = false;
      _memberAckLoaded = false;
    }
    _adminAckLoaded = false;
    if (!_memberAckLoaded) {
      unawaited(_loadMemberAckFromPrefs());
    }
    unawaited(_loadAdminAckFromPrefs());
  }

  Future<void> _loadMemberAckFromPrefs() async {
    final userId = _userId;
    if (userId == null || userId.isEmpty) {
      _memberAckLoaded = false;
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    if (_userId != userId) return;
    _lastSeenAvailableSlots = prefs.getInt(_memberSlotsKey(userId)) ?? 0;
    _lastSeenVolunteerApprovalPending =
        prefs.getBool(_memberVolunteerPendingKey(userId)) ?? false;
    _memberAckLoaded = true;
    notifyListeners();
  }

  Future<void> _loadAdminAckFromPrefs() async {
    final userId = _userId;
    if (userId == null || userId.isEmpty) {
      _adminAckLoaded = false;
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    if (_userId != userId) return;
    _lastSeenPendingVolunteers = prefs.getInt(_pendingKey(userId)) ?? 0;
    _lastSeenNewMembers = prefs.getInt(_newMembersKey(userId)) ?? 0;
    _adminAckLoaded = true;
    notifyListeners();
  }

  bool memberScheduleHasUnread({
    required int availableSlots,
    required bool volunteerApprovalPending,
  }) {
    if (!_memberAckLoaded) return false;
    if (volunteerApprovalPending && !_lastSeenVolunteerApprovalPending) {
      return true;
    }
    return availableSlots > _lastSeenAvailableSlots;
  }

  Future<void> reconcileMemberSchedule({
    required int availableSlots,
    required bool volunteerApprovalPending,
  }) async {
    if (!_memberAckLoaded) return;
    var changed = false;
    if (_lastSeenAvailableSlots > availableSlots) {
      _lastSeenAvailableSlots = availableSlots;
      changed = true;
    }
    if (!volunteerApprovalPending && _lastSeenVolunteerApprovalPending) {
      _lastSeenVolunteerApprovalPending = false;
      changed = true;
    }
    if (!changed) return;
    await _persistMemberAck();
    notifyListeners();
  }

  Future<void> markMemberScheduleSeen({
    required int availableSlots,
    required bool volunteerApprovalPending,
  }) async {
    _lastSeenAvailableSlots = availableSlots;
    _lastSeenVolunteerApprovalPending = volunteerApprovalPending;
    if (!_memberAckLoaded) {
      _memberAckLoaded = true;
    }
    await _persistMemberAck();
    notifyListeners();
  }

  Future<void> _persistMemberAck() async {
    final userId = _userId;
    if (userId == null || userId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_memberSlotsKey(userId), _lastSeenAvailableSlots);
    await prefs.setBool(
      _memberVolunteerPendingKey(userId),
      _lastSeenVolunteerApprovalPending,
    );
  }

  /// Drop stored baselines when server counts fall (e.g. after an approval).
  Future<void> reconcileAdminSummary(AdminNotifications summary) async {
    if (!_adminAckLoaded) return;
    var changed = false;
    if (_lastSeenPendingVolunteers > summary.pendingVolunteerApprovals) {
      _lastSeenPendingVolunteers = summary.pendingVolunteerApprovals;
      changed = true;
    }
    if (_lastSeenNewMembers > summary.newMembersCount) {
      _lastSeenNewMembers = summary.newMembersCount;
      changed = true;
    }
    if (!changed) return;
    await _persistAdminAck();
    notifyListeners();
  }

  int adminUnreadCount(AdminNotifications summary) {
    if (!_adminAckLoaded) return 0;
    final pendingDelta = math.max(
      0,
      summary.pendingVolunteerApprovals - _lastSeenPendingVolunteers,
    );
    final newMembersDelta = math.max(
      0,
      summary.newMembersCount - _lastSeenNewMembers,
    );
    return pendingDelta + newMembersDelta;
  }

  Future<void> markAdminNotificationsSeen(AdminNotifications summary) async {
    _lastSeenPendingVolunteers = summary.pendingVolunteerApprovals;
    _lastSeenNewMembers = summary.newMembersCount;
    if (!_adminAckLoaded) {
      _adminAckLoaded = true;
    }
    await _persistAdminAck();
    notifyListeners();
  }

  Future<void> _persistAdminAck() async {
    final userId = _userId;
    if (userId == null || userId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_pendingKey(userId), _lastSeenPendingVolunteers);
    await prefs.setInt(_newMembersKey(userId), _lastSeenNewMembers);
  }
}
