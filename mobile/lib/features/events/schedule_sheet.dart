import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../core/app_text_styles.dart";
import "../../core/app_theme.dart";
import "../../core/auth_store.dart";
import "../bookings/booking_models.dart";
import "../duty/duty_controller.dart";
import "../duty/duty_screen.dart";
import "event_scroll.dart";
import "events_controller.dart";
import "events_section.dart";
import "schedule_date_finder.dart";
import "schedule_scroll_scope.dart";
import "schedule_tab_scope.dart";

/// Admin app-bar action: duty slots and library events in a sheet.
Future<void> showDutyRosterSheet(BuildContext context) {
  return showScheduleSheet(context);
}

Future<void> showScheduleSheet(
  BuildContext context, {
  DateTime? focusEventDate,
  DateTime? focusDutyDate,
  bool focusEventsFirst = true,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: kModalSurface,
    barrierColor: Colors.black54,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) {
      final height = MediaQuery.sizeOf(sheetContext).height * 0.85;
      return SizedBox(
        height: height,
        child: _ScheduleSheet(
          focusEventDate: focusEventDate,
          focusDutyDate: focusDutyDate,
          focusEventsFirst: focusEventsFirst,
        ),
      );
    },
  );
}

/// Close an overlay (e.g. notifications) and open schedule at a date.
Future<void> openScheduleAtDate(
  BuildContext hostContext,
  DateTime date, {
  required bool hasEvent,
  required bool hasDuty,
  BuildContext? sheetContext,
}) async {
  if (sheetContext != null && Navigator.of(sheetContext).canPop()) {
    Navigator.of(sheetContext).pop();
    if (!hostContext.mounted) return;
  }
  await showScheduleSheet(
    hostContext,
    focusEventDate: hasEvent ? date : null,
    focusDutyDate: hasDuty ? date : null,
    focusEventsFirst: hasEvent,
  );
}

class _ScheduleSheet extends StatefulWidget {
  const _ScheduleSheet({
    this.focusEventDate,
    this.focusDutyDate,
    this.focusEventsFirst = true,
  });

  final DateTime? focusEventDate;
  final DateTime? focusDutyDate;
  final bool focusEventsFirst;

  @override
  State<_ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends State<_ScheduleSheet>
    with SingleTickerProviderStateMixin {
  final Map<String, GlobalKey> _eventKeys = {};
  final ScrollController _eventsScrollController = ScrollController();
  final GlobalKey<EventsSectionState> _eventsSectionKey =
      GlobalKey<EventsSectionState>();
  final GlobalKey<DutyScreenState> _adminDutyKey = GlobalKey<DutyScreenState>();
  final GlobalKey<DutyScreenState> _volunteerDutyKey =
      GlobalKey<DutyScreenState>();
  TabController? _tabController;
  int? _tabCount;

  GlobalKey _keyForEvent(String eventId) =>
      _eventKeys.putIfAbsent(eventId, GlobalKey.new);

  Future<bool> _scrollToDutySession() async {
    final auth = context.read<AuthStore>();
    final key = auth.isAdmin ? _adminDutyKey : _volunteerDutyKey;
    return await key.currentState?.scrollToPendingSession() ?? false;
  }

  Future<bool> _scrollToPendingEvent() async {
    await waitForScrollController(
      _eventsScrollController,
      expectScrollableContent: true,
    );
    var scrolled =
        await _eventsSectionKey.currentState?.scrollToPendingEvent() ?? false;
    for (var retry = 0; retry < 6 && !scrolled; retry++) {
      await waitForScheduleTabLayout(frames: 4);
      if (!mounted) return scrolled;
      await waitForScrollController(
        _eventsScrollController,
        expectScrollableContent: retry < 4,
      );
      if (!mounted) return scrolled;
      scrolled =
          await _eventsSectionKey.currentState?.scrollToPendingEvent() ?? false;
    }
    return scrolled;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthStore>();
    final showDuty = auth.isVolunteer || auth.isAdmin;
    final tabCount = showDuty ? 2 : 1;
    if (_tabController == null || _tabCount != tabCount) {
      _tabController?.dispose();
      _tabCount = tabCount;
      final initialIndex = !showDuty
          ? 0
          : widget.focusEventDate != null
              ? scheduleEventsTabIndexFor(showDutyTabs: showDuty)
              : widget.focusDutyDate != null
                  ? scheduleDutyTabIndex
                  : 0;
      _tabController = TabController(
        length: tabCount,
        vsync: this,
        initialIndex: initialIndex.clamp(0, tabCount - 1),
      );
    }
  }

  @override
  void dispose() {
    _eventsScrollController.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reloadSchedule());
  }

  Future<void> _reloadSchedule() async {
    if (!mounted) return;
    final auth = context.read<AuthStore>();
    final events = context.read<EventsController>();
    final now = DateTime.now();
    final today = calendarDay(now);
    await Future.wait([
      events.loadEvents(admin: auth.isAdmin),
      events.refreshAvailability(),
      events.loadScheduleDates(
        today.subtract(const Duration(days: 45)),
        today.add(const Duration(days: 365)),
      ),
      if (auth.isVolunteer || auth.isAdmin)
        context.read<DutyController>().loadRoster(),
    ]);
    if (!mounted) return;
    await _applyFocusDate();
  }

  Future<void> _focusDutyDate(DateTime date) async {
    final duty = context.read<DutyController>();
    await switchScheduleTab(context, scheduleDutyTabIndex);
    if (!mounted) return;
    await waitForScheduleTabLayout(frames: 4);
    if (!mounted) return;
    final found = await duty.jumpToDate(date);
    if (!mounted) return;
    if (found) {
      await waitForScheduleTabLayout(frames: 3);
      if (!mounted) return;
      await _scrollToDutySession();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No duty slots found on that date.")),
      );
    }
  }

  Future<void> _focusEventDate(DateTime date) async {
    final auth = context.read<AuthStore>();
    final events = context.read<EventsController>();
    final showDuty = auth.isVolunteer || auth.isAdmin;
    if (showDuty) {
      await switchScheduleTab(
        context,
        scheduleEventsTabIndexFor(showDutyTabs: showDuty),
      );
    }
    if (!mounted) return;
    await waitForScheduleTabLayout(frames: 4);
    if (!mounted) return;
    final found = await events.jumpToDate(
      date,
      admin: auth.isAdmin,
    );
    if (!mounted) return;
    if (found) {
      await waitForScheduleTabLayout(frames: 3);
      if (!mounted) return;
      await _scrollToPendingEvent();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No events found on that date.")),
      );
    }
  }

  Future<void> _applyFocusDate() async {
    final auth = context.read<AuthStore>();
    final showDuty = auth.isVolunteer || auth.isAdmin;
    final eventDate = widget.focusEventDate;
    final dutyDate = widget.focusDutyDate;

    if (eventDate != null && dutyDate != null) {
      if (widget.focusEventsFirst) {
        await _focusEventDate(eventDate);
        if (!mounted) return;
        await _focusDutyDate(dutyDate);
      } else {
        await _focusDutyDate(dutyDate);
        if (!mounted) return;
        await _focusEventDate(eventDate);
      }
      return;
    }

    if (eventDate != null) {
      await _focusEventDate(eventDate);
      return;
    }

    if (dutyDate != null && showDuty) {
      await _focusDutyDate(dutyDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();
    final showDuty = auth.isVolunteer || auth.isAdmin;
    final showCalendar = auth.usesScheduleCalendar;
    final tabController = _tabController;
    if (tabController == null) {
      return const SizedBox.shrink();
    }

    return ColoredBox(
      color: Colors.white,
      child: ScheduleScrollScope(
        scrollToPendingEvent: _scrollToPendingEvent,
        scrollToDutySession: _scrollToDutySession,
        child: ScheduleTabScope(
          controller: tabController,
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        showDuty ? "Schedule" : "Library events",
                        style: context.screenTitle,
                      ),
                    ),
                  ),
                  if (showCalendar)
                    IconButton(
                      tooltip: "Calendar",
                      onPressed: () => findScheduleDate(context),
                      icon: const Icon(Icons.calendar_month_outlined),
                    ),
                ],
              ),
            ),
            if (auth.isVolunteerApprovalPending)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _VolunteerApprovalBanner(),
              ),
            if (showDuty)
              Material(
                color: Theme.of(context).colorScheme.surface,
                child: TabBar(
                  controller: tabController,
                  labelStyle: context.scheduleMainTabSelected,
                  unselectedLabelStyle: context.scheduleMainTabUnselected,
                  tabs: [
                    Tab(text: auth.isAdmin ? "Duty roster" : "Duty"),
                    const Tab(text: "Library events"),
                  ],
                ),
              ),
            Expanded(
              child: TabBarView(
                controller: tabController,
                children: [
                  if (showDuty)
                    auth.isAdmin
                        ? DefaultTabController(
                            length: 2,
                            child: Column(
                              children: [
                                Material(
                                  color: Theme.of(context).colorScheme.surface,
                                  child: TabBar(
                                    labelStyle: context.scheduleSubTabSelected,
                                    unselectedLabelStyle:
                                        context.scheduleSubTabUnselected,
                                    tabs: const [
                                      Tab(text: "Upcoming"),
                                      Tab(text: "Past"),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: DutyScreen(
                                    key: _adminDutyKey,
                                    useTabs: true,
                                    hideDateFinder: true,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : DutyScreen(
                            key: _volunteerDutyKey,
                            hidePast: true,
                            hideDateFinder: true,
                          ),
                  _KeepAliveTab(
                    child: RefreshIndicator(
                      onRefresh: _reloadSchedule,
                      child: EventsSection(
                        key: _eventsSectionKey,
                        adminMode: auth.isAdmin,
                        embeddedInSchedule: true,
                        scrollController: _eventsScrollController,
                        eventKeyFor: _keyForEvent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _KeepAliveTab extends StatefulWidget {
  const _KeepAliveTab({required this.child});

  final Widget child;

  @override
  State<_KeepAliveTab> createState() => _KeepAliveTabState();
}

class _KeepAliveTabState extends State<_KeepAliveTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _VolunteerApprovalBanner extends StatelessWidget {
  const _VolunteerApprovalBanner();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFF8E1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF8D6E00)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.hourglass_top, color: Color(0xFF8D6E00)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Volunteer access pending approval",
                    style: context.cardTitle.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "An admin will confirm your volunteer membership soon. "
                    "You can browse and book toys as a member in the meantime.",
                    style: context.listSubtitle.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
