import "package:flutter/foundation.dart";

import "../../core/api_client.dart";
import "../../core/api_exception.dart";
import "../bookings/booking_models.dart";
import "duty_session_models.dart";

/// Loads and mutates duty roster via `/api/v1/duty`.
class DutyController extends ChangeNotifier {
  DutyController(this._client);

  final BackendClient _client;

  List<DutySessionItem> sessions = [];
  OnDutyStatus onDutyStatus = const OnDutyStatus(onDuty: false);

  bool loading = false;
  String? error;

  static const _horizonDays = 28;

  Future<void> loadRoster() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final today = DateTime.now();
      final end = today.add(const Duration(days: _horizonDays));
      final sessionsJson = await _client.getJson(
        "/api/v1/duty/sessions",
        {
          "from": formatApiDate(today),
          "to": formatApiDate(end),
        },
      );
      final onDutyJson = await _client.getJson("/api/v1/duty/me/on-duty");
      sessions = parseDutySessionList(sessionsJson);
      onDutyStatus = OnDutyStatus.fromJson(onDutyJson);
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

  Future<DutySessionItem> createSession({
    required DateTime sessionDate,
    required String startTime,
    required String endTime,
  }) async {
    final json = await _client.postJson("/api/v1/duty/sessions", {
      "session_date": formatApiDate(sessionDate),
      "start_time": startTime,
      "end_time": endTime,
    });
    final created = DutySessionItem.fromJson(json);
    sessions = [...sessions, created];
    sortDutySessions(sessions);
    notifyListeners();
    return created;
  }

  Future<void> deleteSession(String sessionId) async {
    await _client.deleteJson("/api/v1/duty/sessions/$sessionId");
    sessions = sessions.where((s) => s.sessionId != sessionId).toList();
    notifyListeners();
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
