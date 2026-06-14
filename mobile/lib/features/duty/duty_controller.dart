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
  bool loadingMore = false;
  String? error;

  static const _initialPastDays = 28;
  static const _initialFutureDays = 42;
  static const _loadMoreChunkDays = 56;
  static const _maxPastHorizonDays = 365;
  static const _maxFutureHorizonDays = 365 * 2;

  DateTime? _loadedFrom;
  DateTime? _loadedTo;

  /// Set after [jumpToDate]; consumed by [DutyScreen] to scroll the roster.
  String? scrollToSessionId;

  bool get canLoadMoreFuture {
    if (_loadedTo == null) return false;
    final cap = calendarDay(DateTime.now())
        .add(const Duration(days: _maxFutureHorizonDays));
    return _loadedTo!.isBefore(cap);
  }

  bool get canLoadMorePast {
    if (_loadedFrom == null) return false;
    final cap = calendarDay(DateTime.now())
        .subtract(const Duration(days: _maxPastHorizonDays));
    return _loadedFrom!.isAfter(cap);
  }

  Future<void> loadRoster() async {
    final today = calendarDay(DateTime.now());
    final from = today.subtract(const Duration(days: _initialPastDays));
    final to = today.add(const Duration(days: _initialFutureDays));
    await _loadRange(from, to, replace: true);
  }

  Future<void> loadMoreFuture() async {
    if (loading || loadingMore || !canLoadMoreFuture || _loadedTo == null) {
      return;
    }
    final today = calendarDay(DateTime.now());
    final cap = today.add(const Duration(days: _maxFutureHorizonDays));
    var newTo = _loadedTo!.add(const Duration(days: _loadMoreChunkDays));
    if (newTo.isAfter(cap)) {
      newTo = cap;
    }
    if (!newTo.isAfter(_loadedTo!)) {
      return;
    }

    loadingMore = true;
    notifyListeners();
    try {
      final from = _loadedTo!.add(const Duration(days: 1));
      await _fetchSessions(from, newTo, replace: false);
      _loadedTo = newTo;
    } on ApiException catch (e) {
      error = _friendlyLoadMessage(e);
    } catch (e) {
      error = e.toString();
    } finally {
      loadingMore = false;
      notifyListeners();
    }
  }

  Future<void> loadMorePast() async {
    if (loading || loadingMore || !canLoadMorePast || _loadedFrom == null) {
      return;
    }
    final today = calendarDay(DateTime.now());
    final cap = today.subtract(const Duration(days: _maxPastHorizonDays));
    var newFrom = _loadedFrom!.subtract(const Duration(days: _loadMoreChunkDays));
    if (newFrom.isBefore(cap)) {
      newFrom = cap;
    }
    if (!newFrom.isBefore(_loadedFrom!)) {
      return;
    }

    loadingMore = true;
    notifyListeners();
    try {
      final to = _loadedFrom!.subtract(const Duration(days: 1));
      await _fetchSessions(newFrom, to, replace: false);
      _loadedFrom = newFrom;
    } on ApiException catch (e) {
      error = _friendlyLoadMessage(e);
    } catch (e) {
      error = e.toString();
    } finally {
      loadingMore = false;
      notifyListeners();
    }
  }

  Future<void> _loadRange(
    DateTime from,
    DateTime to, {
    required bool replace,
  }) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await _fetchSessions(from, to, replace: replace);
      final onDutyJson = await _client.getJson("/api/v1/duty/me/on-duty");
      onDutyStatus = OnDutyStatus.fromJson(onDutyJson);
      _loadedFrom = calendarDay(from);
      _loadedTo = calendarDay(to);
      error = null;
    } on ApiException catch (e) {
      error = _friendlyLoadMessage(e);
      if (replace) {
        sessions = [];
        onDutyStatus = const OnDutyStatus(onDuty: false);
        _loadedFrom = null;
        _loadedTo = null;
      }
    } catch (e) {
      error = e.toString();
      if (replace) {
        sessions = [];
        onDutyStatus = const OnDutyStatus(onDuty: false);
        _loadedFrom = null;
        _loadedTo = null;
      }
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchSessions(
    DateTime from,
    DateTime to, {
    required bool replace,
  }) async {
    final sessionsJson = await _client.getJson(
      "/api/v1/duty/sessions",
      {
        "from": formatApiDate(from),
        "to": formatApiDate(to),
      },
    );
    final incoming = parseDutySessionList(sessionsJson);
    if (replace) {
      sessions = incoming;
    } else {
      final existingIds = sessions.map((s) => s.sessionId).toSet();
      sessions = [
        ...sessions,
        ...incoming.where((s) => !existingIds.contains(s.sessionId)),
      ];
      sortDutySessions(sessions);
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
    final from = day.subtract(const Duration(days: _initialPastDays));
    final to = day.add(const Duration(days: _initialFutureDays));
    loadingMore = true;
    notifyListeners();
    try {
      await _fetchSessions(from, to, replace: false);
      final fromDay = calendarDay(from);
      final toDay = calendarDay(to);
      _loadedFrom =
          _loadedFrom == null || fromDay.isBefore(_loadedFrom!) ? fromDay : _loadedFrom;
      _loadedTo = _loadedTo == null || toDay.isAfter(_loadedTo!) ? toDay : _loadedTo;
    } finally {
      loadingMore = false;
      notifyListeners();
    }
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

  Future<DutyBookResult> bookSession(String sessionId) async {
    final json =
        await _client.postJson("/api/v1/duty/sessions/$sessionId/book");
    final result = DutyBookResult.fromJson(json);
    final updated = result.session;
    _replaceSession(updated);
    onDutyStatus = await _fetchOnDutyStatus();
    notifyListeners();
    return result;
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

  Future<OnDutyStatus> refreshOnDutyStatus() async {
    onDutyStatus = await _fetchOnDutyStatus();
    notifyListeners();
    return onDutyStatus;
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
