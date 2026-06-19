import "dart:async";

import "package:flutter/foundation.dart";

import "../../core/api_client.dart";
import "../../core/api_exception.dart";
import "../bookings/booking_models.dart";
import "../loans/desk_member.dart";
import "event_models.dart";

/// Library events — list, book, and admin CRUD.
class EventsController extends ChangeNotifier {
  EventsController(this._client);

  final BackendClient _client;

  List<LibraryEventItem> events = [];
  EventAvailability availability = const EventAvailability(
    availableSlots: 0,
    bookableEvents: 0,
  );
  ScheduleDates scheduleDates = const ScheduleDates(
    dutyDates: [],
    eventDates: [],
  );

  bool loading = false;
  bool loadingMore = false;
  String? error;

  DateTime? _loadedFrom;
  DateTime? _loadedTo;
  bool _loadedAdmin = false;
  Future<void>? _loadInFlight;
  _LoadRequest? _loadInFlightRequest;
  int _loadGeneration = 0;

  static const _initialPastDays = 14;
  /// Match `/events/availability` so events like Halloween appear in the list.
  static const _initialFutureDays = 365;

  String? scrollToEventId;

  Future<void> loadEvents({bool admin = false}) async {
    final today = calendarDay(DateTime.now());
    final from = today.subtract(const Duration(days: _initialPastDays));
    final to = today.add(const Duration(days: _initialFutureDays));
    await _loadRange(from, to, admin: admin, replace: true);
  }

  Future<void> refreshAvailability() async {
    try {
      final json = await _client.getJson("/api/v1/events/availability");
      availability = EventAvailability.fromJson(json);
      notifyListeners();
    } catch (_) {
      availability = const EventAvailability(
        availableSlots: 0,
        bookableEvents: 0,
      );
      notifyListeners();
    }
  }

  Future<void> loadScheduleDates(DateTime from, DateTime to) async {
    try {
      final json = await _client.getJson(
        "/api/v1/events/dates",
        {
          "from": formatApiDate(from),
          "to": formatApiDate(to),
        },
      );
      scheduleDates = ScheduleDates.fromJson(json);
      notifyListeners();
    } catch (_) {
      scheduleDates = const ScheduleDates(dutyDates: [], eventDates: []);
    }
  }

  Future<void> _loadRange(
    DateTime from,
    DateTime to, {
    required bool admin,
    required bool replace,
  }) async {
    final request = _LoadRequest(
      from: calendarDay(from),
      to: calendarDay(to),
      admin: admin,
      replace: replace,
    );
    if (_loadInFlight != null &&
        _loadInFlightRequest != null &&
        _loadInFlightRequest == request) {
      return _loadInFlight!;
    }

    final future = _performLoadRange(from, to, admin: admin, replace: replace);
    _loadInFlight = future;
    _loadInFlightRequest = request;
    try {
      await future;
    } finally {
      if (_loadInFlight == future) {
        _loadInFlight = null;
        _loadInFlightRequest = null;
      }
    }
  }

  Future<void> _performLoadRange(
    DateTime from,
    DateTime to, {
    required bool admin,
    required bool replace,
  }) async {
    final generation = _loadGeneration;
    loading = true;
    if (replace || events.isEmpty) {
      error = null;
    }
    notifyListeners();
    try {
      final path = admin ? "/api/v1/admin/events" : "/api/v1/events";
      final json = await _client.getJson(
        path,
        {
          "from": formatApiDate(from),
          "to": formatApiDate(to),
        },
      );
      if (generation != _loadGeneration) return;

      final incoming = parseEventList(json);
      if (replace) {
        events = incoming;
      } else {
        final existing = events.map((e) => e.eventId).toSet();
        events = [
          ...events,
          ...incoming.where((e) => !existing.contains(e.eventId)),
        ];
      }
      _loadedFrom = calendarDay(from);
      _loadedTo = calendarDay(to);
      _loadedAdmin = admin;
      error = null;
    } on ApiException catch (e) {
      if (generation != _loadGeneration) return;
      error = e.message;
      if (replace && events.isEmpty) {
        events = [];
      }
    } catch (e) {
      if (generation != _loadGeneration) return;
      error = eventLoadErrorMessage(e);
      if (replace && events.isEmpty) {
        events = [];
      }
    } finally {
      if (generation == _loadGeneration) {
        loading = false;
        notifyListeners();
      }
    }
  }

  void _invalidateInFlightLoads() {
    _loadGeneration++;
    _loadInFlight = null;
    _loadInFlightRequest = null;
    loading = false;
  }

  void _ensureEventInLoadedRange(LibraryEventItem event) {
    final start = calendarDay(event.eventDate);
    final end = calendarDay(event.endDate);
    if (_loadedFrom == null || _loadedTo == null) {
      _loadedFrom = start.subtract(const Duration(days: _initialPastDays));
      _loadedTo = end.add(const Duration(days: _initialFutureDays));
      return;
    }
    if (start.isBefore(_loadedFrom!)) {
      _loadedFrom = start.subtract(const Duration(days: _initialPastDays));
    }
    if (end.isAfter(_loadedTo!)) {
      _loadedTo = end.add(const Duration(days: _initialFutureDays));
    }
  }

  void _refreshScheduleDatesInBackground() {
    final now = calendarDay(DateTime.now());
    unawaited(
      loadScheduleDates(
        now.subtract(const Duration(days: 45)),
        now.add(const Duration(days: _initialFutureDays)),
      ),
    );
  }

  Future<bool> jumpToDate(DateTime date, {bool? admin}) async {
    final day = calendarDay(date);
    final useAdmin = admin ?? _loadedAdmin;
    if (_loadedFrom == null ||
        _loadedTo == null ||
        day.isBefore(_loadedFrom!) ||
        day.isAfter(_loadedTo!)) {
      await _loadRange(
        day.subtract(const Duration(days: _initialPastDays)),
        day.add(const Duration(days: _initialFutureDays)),
        admin: useAdmin,
        replace: false,
      );
    }
    var match = events.where((e) => eventIncludesDay(e, day)).toList();
    if (match.isEmpty) {
      await _loadRange(
        day.subtract(const Duration(days: _initialPastDays)),
        day.add(const Duration(days: _initialFutureDays)),
        admin: useAdmin,
        replace: false,
      );
      match = events.where((e) => eventIncludesDay(e, day)).toList();
    }
    if (match.isEmpty) {
      scrollToEventId = null;
      notifyListeners();
      return false;
    }
    scrollToEventId = match.first.eventId;
    notifyListeners();
    return true;
  }

  void clearScrollRequest() {
    scrollToEventId = null;
  }

  Future<LibraryEventItem> bookSlot(String slotId) async {
    _invalidateInFlightLoads();
    final json =
        await _client.postJson("/api/v1/events/slots/$slotId/book");
    final event = LibraryEventItem.fromJson(json["event"] as Map<String, dynamic>);
    _replaceEvent(event);
    unawaited(refreshAvailability());
    return event;
  }

  Future<LibraryEventItem> cancelSlot(String slotId) async {
    _invalidateInFlightLoads();
    final json =
        await _client.deleteJson("/api/v1/events/slots/$slotId/book");
    final event = LibraryEventItem.fromJson(json["event"] as Map<String, dynamic>);
    _replaceEvent(event);
    unawaited(refreshAvailability());
    return event;
  }

  Future<List<DeskMember>> searchEventAssignees(
    String audience,
    String query,
  ) async {
    final trimmed = query.trim();
    final json = await _client.getJson(
      "/api/v1/admin/events/assignees",
      {
        "audience": audience,
        if (trimmed.isNotEmpty) "q": trimmed,
      },
    );
    return parseDeskMemberList(json);
  }

  Future<LibraryEventItem> adminBookSlot(
    String slotId,
    DeskMember member,
  ) async {
    _invalidateInFlightLoads();
    final json = await _client.postJson(
      "/api/v1/admin/events/slots/$slotId/book",
      {"user_id": member.userId},
    );
    final event = LibraryEventItem.fromJson(json);
    _replaceEvent(event);
    unawaited(refreshAvailability());
    return event;
  }

  Future<LibraryEventItem> adminCancelBooking(
    String slotId,
    String userId,
  ) async {
    _invalidateInFlightLoads();
    final json = await _client.deleteJson(
      "/api/v1/admin/events/slots/$slotId/book/$userId",
    );
    final event = LibraryEventItem.fromJson(json);
    _replaceEvent(event);
    unawaited(refreshAvailability());
    return event;
  }

  Future<LibraryEventItem> createEvent(Map<String, dynamic> body) async {
    final json = await _client.postJson("/api/v1/admin/events", body);
    final event = LibraryEventItem.fromJson(json);
    _invalidateInFlightLoads();
    final existing = events.where((e) => e.eventId != event.eventId).toList();
    events = [...existing, event]..sort(_sortEvents);
    _ensureEventInLoadedRange(event);
    _loadedAdmin = true;
    scrollToEventId = event.eventId;
    notifyListeners();
    _refreshScheduleDatesInBackground();
    return event;
  }

  Future<LibraryEventItem> updateEvent(
    String eventId,
    Map<String, dynamic> body,
  ) async {
    final json = await _client.patchJson("/api/v1/admin/events/$eventId", body);
    final event = LibraryEventItem.fromJson(json);
    _invalidateInFlightLoads();
    _ensureEventInLoadedRange(event);
    scrollToEventId = event.eventId;
    _replaceEvent(event);
    _refreshScheduleDatesInBackground();
    return event;
  }

  Future<void> deleteEvent(String eventId) async {
    await _client.deleteJson("/api/v1/admin/events/$eventId");
    _invalidateInFlightLoads();
    events = events.where((e) => e.eventId != eventId).toList();
    notifyListeners();
    _refreshScheduleDatesInBackground();
  }

  void _replaceEvent(LibraryEventItem updated) {
    events = [
      for (final item in events)
        if (item.eventId == updated.eventId) updated else item,
    ]..sort(_sortEvents);
    notifyListeners();
  }

  static int _sortEvents(LibraryEventItem a, LibraryEventItem b) {
    final dateCmp = a.eventDate.compareTo(b.eventDate);
    if (dateCmp != 0) return dateCmp;
    return a.name.compareTo(b.name);
  }
}

class _LoadRequest {
  const _LoadRequest({
    required this.from,
    required this.to,
    required this.admin,
    required this.replace,
  });

  final DateTime from;
  final DateTime to;
  final bool admin;
  final bool replace;

  @override
  bool operator ==(Object other) {
    return other is _LoadRequest &&
        other.from == from &&
        other.to == to &&
        other.admin == admin &&
        other.replace == replace;
  }

  @override
  int get hashCode => Object.hash(from, to, admin, replace);
}
