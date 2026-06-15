import "package:flutter/foundation.dart";
import "package:flutter_local_notifications/flutter_local_notifications.dart";
import "package:timezone/data/latest.dart" as tz_data;
import "package:timezone/timezone.dart" as tz;

import "../features/bookings/booking_models.dart";
import "../features/loans/loan_models.dart";
import "reminder_scheduler.dart";

/// Schedules booking pickup and loan return/overdue alerts on the device.
class ReminderNotificationService {
  ReminderNotificationService._();

  static final ReminderNotificationService instance =
      ReminderNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _available = true;
  bool _permissionRequested = false;

  static const _channelId = "toy_library_reminders";
  static const _channelName = "Toy library reminders";
  static const _channelDescription =
      "Pickup, return, and overdue reminders for your toys.";

  Future<void> initialize() async {
    if (_initialized || !_available) return;

    try {
      tz_data.initializeTimeZones();
      try {
        tz.setLocalLocation(tz.getLocation("Pacific/Auckland"));
      } catch (_) {
        tz.setLocalLocation(tz.local);
      }

      const android = AndroidInitializationSettings("@mipmap/ic_launcher");
      const settings = InitializationSettings(android: android);
      await _plugin.initialize(settings);

      const channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
      );
      final androidPlugin =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(channel);

      _initialized = true;
    } catch (e, stack) {
      _available = false;
      debugPrint("Local notifications unavailable: $e\n$stack");
    }
  }

  Future<bool> ensurePermission() async {
    await initialize();
    if (_permissionRequested) return true;
    _permissionRequested = true;

    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    final granted = await androidPlugin?.requestNotificationsPermission();
    return granted ?? true;
  }

  NotificationDetails _details() {
    const android = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );
    return const NotificationDetails(android: android);
  }

  tz.TZDateTime _toTz(DateTime local) {
    return tz.TZDateTime.from(local, tz.local);
  }

  Future<void> cancelAll() async {
    await initialize();
    if (!_initialized) return;
    await _plugin.cancelAll();
  }

  Future<void> syncMemberReminders({
    required List<BookingItem> bookings,
    required List<LoanItem> loans,
    required bool enabled,
  }) async {
    await initialize();
    if (!_initialized) return;
    await cancelAll();
    if (!enabled) return;

    await ensurePermission();

    final reminders = buildMemberReminders(bookings: bookings, loans: loans);
    final details = _details();

    for (final reminder in reminders) {
      try {
        await _plugin.zonedSchedule(
          reminder.id,
          reminder.title,
          reminder.body,
          _toTz(reminder.when),
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (e, stack) {
        debugPrint("Reminder schedule failed (${reminder.id}): $e\n$stack");
      }
    }
  }
}
