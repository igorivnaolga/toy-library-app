import "package:flutter/foundation.dart";

import "../../core/api_client.dart";
import "../../core/api_exception.dart";
import "../bookings/booking_models.dart";
import "../loans/desk_member.dart";
import "duty_session_models.dart";

/// Loads and mutates duty roster via `/api/v1/duty`.
class DutyController extends ChangeNotifier {
  DutyController(this._client);

  final BackendClient _client;

  List<DutySessionItem> sessions = [];
  OnDutyStatus onDutyStatus = const OnDutyStatus(onDuty: false);

  bool loading = false;
  String? error;

  static const _pastHorizonDays = 28;
  static const _futureHorizonDays = 28;

  DateTime? _loadedFrom;
  DateTime? _loadedTo;

  /// Set after [jumpToDate]; consumed by [DutyScreen] to scroll the roster.
  String? scrollToSessionId;

  Future<void> loadRoster() async {
    final today = calendarDay(DateTime.now());
    final from = today.subtract(const Duration(days: _pastHorizonDays));
    final to = today.add(const Duration(days: _futureHorizonDays));
    await _loadRange(from, to);
  }

  Future<void> _loadRange(DateTime from, DateTime to) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final sessionsJson = await _client.getJson(
        "/api/v1/duty/sessions",
        {
          "from": formatApiDate(from),
          "to": formatApiDate(to),
        },
      );
      final onDutyJson = await _client.getJson("/api/v1/duty/me/on-duty");
      sessions = parseDutySessionList(sessionsJson);
      onDutyStatus = OnDutyStatus.fromJson(onDutyJson);
      _loadedFrom = calendarDay(from);
      _loadedTo = calendarDay(to);
      error = null;
    } on ApiException catch (e) {
      error = _friendlyLoadMessage(e);
      sessions = [];
      onDutyStatus = const OnDutyStatus(onDuty: false);
    } catch (e) {
      error = e.toString();
      sessions = [];
      onDutyStatus = const OnDutyStatus(onDuty: false);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _ensureDateLoaded(DateTime date) async {
    final day = calendarDay(date);
    if (_loadedFrom != null &&
        _loadedTo != null &&
        !day.isBefore(_loadedFrom!) &&
        !day.isAfter(_loadedTo!)) {
      return;
    }
    final from = day.subtract(const Duration(days: _pastHorizonDays));
    final to = day.add(const Duration(days: _futureHorizonDays));
    await _loadRange(from, to);
  }

  /// Loads roster if needed and requests scroll to the first slot on [date].
  Future<bool> jumpToDate(DateTime date) async {
    await _ensureDateLoaded(date);
    final day = calendarDay(date);
    final match = sessions.where((s) => calendarDay(s.sessionDate) == day);
    if (match.isEmpty) {
      scrollToSessionId = null;
      notifyListeners();
      return false;
    }
    scrollToSessionId = match.first.sessionId;
    notifyListeners();
    return true;
  }

  void clearScrollRequest() {
    scrollToSessionId = null;
  }

  Future<List<DeskMember>> searchRosterMembers(String query) async {
    final trimmed = query.trim();
    final json = await _client.getJson(
      "/api/v1/duty/members",
      trimmed.isEmpty ? null : {"q": trimmed},
    );
    return parseDeskMemberList(json);
  }

  Future<DutySessionItem> assignMember(
    String sessionId,
    DeskMember member,
  ) async {
    final json = await _client.patchJson(
      "/api/v1/duty/sessions/$sessionId/assign",
      {"user_id": member.userId},
    );
    var updated = DutySessionItem.fromJson(json);
    if (updated.isOpen ||
        ((updated.volunteerName == null || updated.volunteerName!.isEmpty) &&
            (updated.volunteerEmail == null || updated.volunteerEmail!.isEmpty))) {
      updated = DutySessionItem(
        sessionId: updated.sessionId,
        sessionDate: updated.sessionDate,
        startTime: updated.startTime,
        endTime: updated.endTime,
        createdAt: updated.createdAt,
        volunteerId: member.userId,
        volunteerName:
            member.fullName.isNotEmpty ? member.fullName : null,
        volunteerEmail: member.email.isNotEmpty ? member.email : null,
      );
    }
    _replaceSession(updated);
    onDutyStatus = await _fetchOnDutyStatus();
    notifyListeners();
    return updated;
  }

  Future<DutySessionItem> clearAssignment(String sessionId) async {
    final json =
        await _client.deleteJson("/api/v1/duty/sessions/$sessionId/assign");
    final updated = DutySessionItem.fromJson(json);
    _replaceSession(updated);
    onDutyStatus = await _fetchOnDutyStatus();
    notifyListeners();
    return updated;
  }

  Future<DutySessionItem> bookSession(String sessionId) async {
    final json =
        await _client.postJson("/api/v1/duty/sessions/$sessionId/book");
    final updated = DutySessionItem.fromJson(json);
    _replaceSession(updated);
    onDutyStatus = await _fetchOnDutyStatus();
    notifyListeners();
    return updated;
  }

  Future<DutySessionItem> cancelBooking(String sessionId) async {
    final json =
        await _client.deleteJson("/api/v1/duty/sessions/$sessionId/book");
    final updated = DutySessionItem.fromJson(json);
    _replaceSession(updated);
    onDutyStatus = await _fetchOnDutyStatus();
    notifyListeners();
    return updated;
  }

  void _replaceSession(DutySessionItem updated) {
    sessions = [
      for (final item in sessions)
        if (item.sessionId == updated.sessionId) updated else item,
    ];
    sortDutySessions(sessions);
  }

  Future<OnDutyStatus> _fetchOnDutyStatus() async {
    final json = await _client.getJson("/api/v1/duty/me/on-duty");
    return OnDutyStatus.fromJson(json);
  }

  String _friendlyLoadMessage(ApiException e) {
    if (e.statusCode == 401) {
      return "Please sign in again to view the duty roster.";
    }
    if (e.statusCode == 403) {
      return "Volunteer access is required for the duty roster.";
    }
    return e.message;
  }
}
