import "package:flutter/material.dart";

/// Scroll helpers for the schedule bottom sheet (events list + duty roster).
class ScheduleScrollScope extends InheritedWidget {
  const ScheduleScrollScope({
    required this.scrollToPendingEvent,
    required this.scrollToDutySession,
    required super.child,
  });

  final Future<bool> Function() scrollToPendingEvent;
  final Future<bool> Function() scrollToDutySession;

  static ScheduleScrollScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ScheduleScrollScope>();
  }

  @override
  bool updateShouldNotify(ScheduleScrollScope oldWidget) => false;
}
