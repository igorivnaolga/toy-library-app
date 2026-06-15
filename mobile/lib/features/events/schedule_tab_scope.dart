import "package:flutter/material.dart";

/// Outer Schedule sheet tab controller (Duty roster | Library events).
class ScheduleTabScope extends InheritedWidget {
  const ScheduleTabScope({
    required this.controller,
    required super.child,
  });

  final TabController controller;

  static TabController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ScheduleTabScope>()
        ?.controller;
  }

  @override
  bool updateShouldNotify(ScheduleTabScope oldWidget) =>
      oldWidget.controller != controller;
}
