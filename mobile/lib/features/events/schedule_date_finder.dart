import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../core/app_theme.dart";
import "../../core/auth_store.dart";
import "../bookings/booking_models.dart";
import "../duty/duty_controller.dart";
import "event_scroll.dart";
import "events_controller.dart";
import "schedule_scroll_scope.dart";
import "schedule_tab_scope.dart";

/// Which schedule tab opened the calendar (controls tab switch after pick).
enum ScheduleDateSource { events, duty }

const scheduleDutyTabIndex = 0;

int scheduleEventsTabIndexFor({required bool showDutyTabs}) =>
    showDutyTabs ? 1 : 0;

class ScheduleDatePick {
  const ScheduleDatePick({
    required this.date,
    required this.hasEvent,
    required this.hasDuty,
  });

  final DateTime date;
  final bool hasEvent;
  final bool hasDuty;
}

/// Shows the calendar dialog and returns the chosen date, or null if cancelled.
Future<ScheduleDatePick?> pickScheduleDate(
  BuildContext context, {
  DateTime? initialDate,
}) async {
  final now = DateTime.now();
  final eventsController = context.read<EventsController>();
  final anchor = initialDate ?? now;
  await eventsController.loadScheduleDates(
    DateTime(anchor.year, anchor.month - 1, 1),
    DateTime(anchor.year, anchor.month + 2, 0),
  );

  if (!context.mounted) return null;

  final picked = await showDialog<DateTime>(
    context: context,
    builder: (dialogContext) {
      return _ScheduleCalendarDialog(
        initialDate: initialDate ?? now,
      );
    },
  );

  if (picked == null || !context.mounted) return null;

  final day = calendarDay(picked);
  final dates = eventsController.scheduleDates;
  final hasEvent = dates.hasEventOn(day);
  final hasDuty = dates.hasDutyOn(day);

  if (!context.mounted) return null;

  if (!hasEvent && !hasDuty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Nothing scheduled on that date.")),
    );
    return null;
  }

  return ScheduleDatePick(
    date: picked,
    hasEvent: hasEvent,
    hasDuty: hasDuty,
  );
}

/// Calendar picker with duty (yellow) and event (blue) markers.
Future<void> findScheduleDate(
  BuildContext context, {
  ScheduleDateSource? source,
  DateTime? initialDate,
}) async {
  final pick = await pickScheduleDate(context, initialDate: initialDate);
  if (pick == null || !context.mounted) return;

  final picked = pick.date;
  final hasEvent = pick.hasEvent;
  final hasDuty = pick.hasDuty;
  final eventsController = context.read<EventsController>();
  final dutyController = context.read<DutyController>();
  final auth = context.read<AuthStore>();

  Future<void> goToDuty() async {
    await switchScheduleTab(context, scheduleDutyTabIndex);
    if (!context.mounted) return;
    await switchDutySubTabForDate(context, picked);
    if (!context.mounted) return;
    await waitForScheduleTabLayout(frames: 4);
    if (!context.mounted) return;
    final found = await dutyController.jumpToDate(picked);
    if (!context.mounted) return;
    if (found) {
      await waitForScheduleTabLayout(frames: 3);
      if (!context.mounted) return;
      final scrolled =
          await ScheduleScrollScope.maybeOf(context)?.scrollToDutySession() ??
              false;
      if (!scrolled && context.mounted) {
        await waitForScheduleTabLayout(frames: 4);
        if (!context.mounted) return;
        await ScheduleScrollScope.maybeOf(context)?.scrollToDutySession();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No duty slots found on that date.")),
      );
    }
  }

  Future<void> goToEvents() async {
    final showDuty = auth.isVolunteer || auth.isAdmin;
    await switchScheduleTab(
      context,
      scheduleEventsTabIndexFor(showDutyTabs: showDuty),
    );
    if (!context.mounted) return;
    await waitForScheduleTabLayout(frames: 4);
    if (!context.mounted) return;
    final found = await eventsController.jumpToDate(
      picked,
      admin: auth.isAdmin,
    );
    if (!context.mounted) return;
    if (found) {
      await waitForScheduleTabLayout(frames: 3);
      if (!context.mounted) return;
      var scrolled = false;
      for (var retry = 0; retry < 4 && !scrolled; retry++) {
        if (!context.mounted) return;
        scrolled =
            await ScheduleScrollScope.maybeOf(context)?.scrollToPendingEvent() ??
                false;
        if (!scrolled) {
          await waitForScheduleTabLayout(frames: 3);
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No events found on that date.")),
      );
    }
  }

  if (source == ScheduleDateSource.events) {
    if (hasEvent) {
      await goToEvents();
    } else if (hasDuty) {
      await goToDuty();
    }
    return;
  }

  if (source == ScheduleDateSource.duty) {
    if (hasDuty) {
      await goToDuty();
    } else if (hasEvent) {
      await goToEvents();
    }
    return;
  }
  if (hasEvent) {
    await eventsController.jumpToDate(picked, admin: auth.isAdmin);
  }
  if (hasDuty) {
    await switchScheduleTab(context, scheduleDutyTabIndex);
    if (!context.mounted) return;
    await switchDutySubTabForDate(context, picked);
    if (!context.mounted) return;
    await dutyController.jumpToDate(picked);
  }
}

/// Admin duty roster uses a nested Upcoming / Past tab bar.
Future<void> switchDutySubTabForDate(BuildContext context, DateTime date) async {
  final innerTab = DefaultTabController.maybeOf(context);
  if (innerTab == null || innerTab.length < 2) return;
  final today = calendarDay(DateTime.now());
  final targetTab = calendarDay(date).isBefore(today) ? 1 : 0;
  if (innerTab.index == targetTab) return;
  innerTab.animateTo(targetTab);
  await Future<void>.delayed(const Duration(milliseconds: 280));
}

Future<void> switchScheduleTab(BuildContext context, int index) async {
  final controller =
      ScheduleTabScope.maybeOf(context) ?? DefaultTabController.maybeOf(context);
  if (controller == null || index >= controller.length) return;
  if (controller.index == index) {
    await waitForScheduleTabLayout(frames: 1);
    return;
  }
  controller.animateTo(index);
  await waitForScheduleTabLayout();
}

class _ScheduleCalendarDialog extends StatefulWidget {
  const _ScheduleCalendarDialog({
    required this.initialDate,
  });

  final DateTime initialDate;

  @override
  State<_ScheduleCalendarDialog> createState() => _ScheduleCalendarDialogState();
}

class _ScheduleCalendarDialogState extends State<_ScheduleCalendarDialog> {
  late DateTime _focusedMonth;
  DateTime? _selected;

  @override
  void initState() {
    super.initState();
    _focusedMonth = DateTime(widget.initialDate.year, widget.initialDate.month);
    _selected = calendarDay(widget.initialDate);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDatesForFocusedMonth());
  }

  Future<void> _loadDatesForFocusedMonth() async {
    await context.read<EventsController>().loadScheduleDates(
      DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1),
      DateTime(_focusedMonth.year, _focusedMonth.month + 2, 0),
    );
    if (mounted) setState(() {});
  }

  void _shiftMonth(int delta) {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + delta);
    });
    _loadDatesForFocusedMonth();
  }

  @override
  Widget build(BuildContext context) {
    final scheduleDates = context.watch<EventsController>().scheduleDates;
    final theme = Theme.of(context);
    final firstWeekday = DateTime(_focusedMonth.year, _focusedMonth.month, 1).weekday;
    final daysInMonth =
        DateUtils.getDaysInMonth(_focusedMonth.year, _focusedMonth.month);
    final leadingBlankDays = (firstWeekday + 6) % 7;
    final monthLabel =
        "${_monthNames[_focusedMonth.month - 1]} ${_focusedMonth.year}";

    return AlertDialog(
      title: const Text("Find a date"),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => _shiftMonth(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(monthLabel, style: theme.textTheme.titleSmall),
                IconButton(
                  onPressed: () => _shiftMonth(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (final label in const ["M", "T", "W", "T", "F", "S", "S"])
                  SizedBox(
                    width: 32,
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemCount: leadingBlankDays + daysInMonth,
              itemBuilder: (context, index) {
                if (index < leadingBlankDays) return const SizedBox.shrink();
                final day = index - leadingBlankDays + 1;
                final date = calendarDay(
                  DateTime(_focusedMonth.year, _focusedMonth.month, day),
                );
                final hasDuty = scheduleDates.hasDutyOn(date);
                final hasEvent = scheduleDates.hasEventOn(date);
                final selected = _selected != null && calendarDay(_selected!) == date;

                return InkWell(
                  onTap: () => setState(() => _selected = date),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: selected
                          ? kBrandYellow.withValues(alpha: 0.35)
                          : null,
                      borderRadius: BorderRadius.circular(8),
                      border: selected
                          ? Border.all(color: kBrandYellow, width: 1.5)
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("$day", style: theme.textTheme.bodySmall),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (hasDuty)
                              Container(
                                width: 5,
                                height: 5,
                                margin: const EdgeInsets.symmetric(horizontal: 1),
                                decoration: const BoxDecoration(
                                  color: kBrandYellow,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            if (hasEvent)
                              Container(
                                width: 5,
                                height: 5,
                                margin: const EdgeInsets.symmetric(horizontal: 1),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF5C6BC0),
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              children: const [
                _LegendDot(color: kBrandYellow, label: "Duty"),
                _LegendDot(color: Color(0xFF5C6BC0), label: "Event"),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("Cancel"),
        ),
        FilledButton(
          onPressed: _selected == null
              ? null
              : () => Navigator.of(context).pop(_selected),
          style: brandFilledButtonStyle(),
          child: const Text("Go to date"),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

const _monthNames = [
  "January",
  "February",
  "March",
  "April",
  "May",
  "June",
  "July",
  "August",
  "September",
  "October",
  "November",
  "December",
];
