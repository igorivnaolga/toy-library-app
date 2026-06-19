import "dart:async";

import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../core/app_text_styles.dart";
import "../../core/app_theme.dart";
import "../../core/auth_store.dart";
import "../../core/brand_chip_button.dart";
import "../../core/toy_loading_indicator.dart";
import "admin_event_edit_screen.dart";
import "event_assign_sheet.dart";
import "event_models.dart";
import "event_scroll.dart";
import "events_controller.dart";
import "schedule_date_finder.dart";
import "schedule_sheet.dart";

/// Library events list for the schedule sheet.
class EventsSection extends StatefulWidget {
  const EventsSection({
    super.key,
    this.adminMode = false,
    this.embeddedInSchedule = false,
    this.hideHeader = false,
    this.scrollable = false,
    this.scheduleHostContext,
    this.scrollController,
    this.eventKeyFor,
  });

  final bool adminMode;
  final bool embeddedInSchedule;
  final bool hideHeader;
  final bool scrollable;
  final BuildContext? scheduleHostContext;
  final ScrollController? scrollController;
  final GlobalKey Function(String eventId)? eventKeyFor;

  @override
  State<EventsSection> createState() => EventsSectionState();
}

class EventsSectionState extends State<EventsSection> {
  String? _actionSlotId;
  String? _scrollInProgressFor;
  EventsController? _eventsController;

  @override
  void initState() {
    super.initState();
    if (widget.embeddedInSchedule) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _eventsController = context.read<EventsController>();
        _eventsController!.addListener(_onEventsControllerChanged);
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final controller = context.read<EventsController>();
        if (controller.events.isEmpty && !controller.loading) {
          controller.loadEvents(admin: widget.adminMode);
        }
        controller.refreshAvailability();
      });
    }
  }

  @override
  void dispose() {
    _eventsController?.removeListener(_onEventsControllerChanged);
    super.dispose();
  }

  void _onEventsControllerChanged() {
    final eventId = _eventsController?.scrollToEventId;
    if (eventId == null ||
        widget.eventKeyFor == null ||
        widget.scrollController == null) {
      return;
    }
    if (eventId != _scrollInProgressFor) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(scrollToPendingEvent());
      });
    }
  }
  /// Scrolls the embedded schedule list to [EventsController.scrollToEventId].
  Future<bool> scrollToPendingEvent() async {
    if (widget.eventKeyFor == null || widget.scrollController == null) {
      return false;
    }
    final controller = context.read<EventsController>();
    final eventId = controller.scrollToEventId;
    if (eventId == null || eventId == _scrollInProgressFor) {
      return false;
    }
    if (controller.loading) {
      for (var attempt = 0;
          attempt < 30 && context.read<EventsController>().loading;
          attempt++) {
        await waitForScheduleTabLayout(frames: 1);
        if (!mounted) return false;
      }
    }
    _scrollInProgressFor = eventId;
    final upcoming = controller.events.where((e) => !e.isPast).toList();
    final past = controller.events.where((e) => e.isPast).toList();
    final listIndex = eventListIndexFor(
      eventId: eventId,
      controller: controller,
      upcoming: upcoming,
      past: past,
      hideHeader: widget.hideHeader,
      adminMode: widget.adminMode,
    );
    await waitForScrollController(
      widget.scrollController!,
      expectScrollableContent: listIndex != null && listIndex > 2,
    );
    if (!mounted) {
      _scrollInProgressFor = null;
      return false;
    }
    await waitForScheduleTabLayout(frames: 2);
    final scrolled = await scrollToEventCard(
      eventId: eventId,
      keyForEvent: widget.eventKeyFor!,
      scrollController: widget.scrollController,
      listIndex: listIndex,
      headerExtent: widget.hideHeader ? 0 : 110,
    );
    _scrollInProgressFor = null;
    if (!mounted) return scrolled;
    if (scrolled) {
      controller.clearScrollRequest();
    }
    return scrolled;
  }

  static int? eventListIndexFor({
    required String eventId,
    required EventsController controller,
    required List<LibraryEventItem> upcoming,
    required List<LibraryEventItem> past,
    required bool hideHeader,
    required bool adminMode,
  }) {
    var index = 0;
    if (!hideHeader) index += 1;
    if (controller.error != null) index += 1;

    final upcomingIndex =
        upcoming.indexWhere((event) => event.eventId == eventId);
    if (upcomingIndex >= 0) return index + upcomingIndex;

    index += upcoming.length;
    if (past.isEmpty || !adminMode) return null;

    index += 1;
    final pastIndex = past.indexWhere((event) => event.eventId == eventId);
    if (pastIndex >= 0) return index + pastIndex;
    return null;
  }

  Future<void> _openCalendar({DateTime? initialDate}) async {
    if (widget.embeddedInSchedule) {
      await findScheduleDate(
        context,
        source: ScheduleDateSource.events,
        initialDate: initialDate,
      );
      return;
    }

    final host = widget.scheduleHostContext ?? context;
    final pick = await pickScheduleDate(context, initialDate: initialDate);
    if (pick == null || !host.mounted) return;
    await openScheduleAtDate(
      host,
      pick.date,
      hasEvent: pick.hasEvent,
      hasDuty: pick.hasDuty,
      sheetContext: widget.scheduleHostContext != null ? context : null,
    );
  }

  Future<void> _openEventDate(LibraryEventItem event) async {
    if (widget.embeddedInSchedule) {
      final controller = context.read<EventsController>();
      final found = await controller.jumpToDate(
        event.eventDate,
        admin: widget.adminMode,
      );
      if (!mounted) return;
      if (!found) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No events found on that date.")),
        );
        return;
      }
      await waitForScheduleTabLayout(frames: 2);
      if (!mounted) return;
      var scrolled = await scrollToPendingEvent();
      for (var retry = 0; retry < 3 && !scrolled && mounted; retry++) {
        await waitForScheduleTabLayout(frames: 3);
        if (!mounted) return;
        scrolled = await scrollToPendingEvent();
      }
      return;
    }
    await _openCalendar(initialDate: event.eventDate);
  }

  Future<void> _book(EventSlotItem slot, LibraryEventItem event) async {
    setState(() => _actionSlotId = slot.slotId);
    final controller = context.read<EventsController>();
    try {
      await controller.bookSlot(slot.slotId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Booked ${event.name} · ${slot.timeRangeLabel}")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(eventActionErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _actionSlotId = null);
    }
  }

  Future<void> _cancel(EventSlotItem slot, LibraryEventItem event) async {
    setState(() => _actionSlotId = slot.slotId);
    final controller = context.read<EventsController>();
    try {
      await controller.cancelSlot(slot.slotId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Cancelled ${event.name} · ${slot.timeRangeLabel}")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(eventActionErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _actionSlotId = null);
    }
  }

  Future<void> _adminBook(EventSlotItem slot, LibraryEventItem event) async {
    await showEventAssignSheet(context, slot: slot, event: event);
  }

  Future<void> _adminRemoveBooking(
    EventSlotItem slot,
    EventBookingUser booking,
    LibraryEventItem event,
  ) async {
    final controller = context.read<EventsController>();
    setState(() => _actionSlotId = slot.slotId);
    try {
      await controller.adminCancelBooking(slot.slotId, booking.userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Removed ${booking.displayName} from ${event.name}",
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(eventActionErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _actionSlotId = null);
    }
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const AdminEventEditScreen(),
      ),
    );
    if (created != true) return;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Event added to schedule")),
    );
  }

  Future<void> _openEdit(LibraryEventItem event) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => AdminEventEditScreen(event: event),
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Event updated")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();

    return Consumer<EventsController>(
      builder: (context, controller, _) {
        final upcoming =
            controller.events.where((e) => !e.isPast).toList();
        final past = controller.events.where((e) => e.isPast).toList();

        if (controller.loading && controller.events.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: ToyLibraryLoadingIndicator.compact()),
          );
        }

        final children = _buildContentChildren(
          context: context,
          auth: auth,
          controller: controller,
          upcoming: upcoming,
          past: past,
        );

        if (widget.embeddedInSchedule || widget.scrollable) {
          return ListView(
            controller: widget.scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(
              bottom: widget.embeddedInSchedule ? 24 : 16,
            ),
            children: children,
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        );
      },
    );
  }

  List<Widget> _buildContentChildren({
    required BuildContext context,
    required AuthStore auth,
    required EventsController controller,
    required List<LibraryEventItem> upcoming,
    required List<LibraryEventItem> past,
  }) {
    return [
      if (!widget.hideHeader)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Library events",
                      style: widget.embeddedInSchedule
                          ? context.scheduleSectionTitle
                          : context.sectionHeader,
                    ),
                    Text(
                      widget.adminMode
                          ? "Create events and manage sign-ups."
                          : "Book a slot to help or attend.",
                      style: context.listSubtitle.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (!widget.embeddedInSchedule)
                IconButton(
                  tooltip: "Find date on calendar",
                  onPressed: () => _openCalendar(),
                  icon: const Icon(Icons.calendar_month_outlined),
                ),
              if (widget.adminMode)
                IconButton(
                  tooltip: "Create event",
                  onPressed: _openCreate,
                  icon: const Icon(Icons.add_circle_outline),
                ),
            ],
          ),
        ),
      if (controller.error != null)
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                controller.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: controller.loading
                      ? null
                      : () => controller.loadEvents(admin: widget.adminMode),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text("Try again"),
                ),
              ),
            ],
          ),
        ),
      if (upcoming.isEmpty && past.isEmpty && controller.error == null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Text(
            "No events scheduled yet.",
            style: context.emptyState,
          ),
        )
      else ...[
        for (final event in upcoming)
          _EventCard(
            key: widget.eventKeyFor?.call(event.eventId),
            event: event,
            auth: auth,
            adminMode: widget.adminMode,
            initialExpanded: controller.scrollToEventId == event.eventId,
            actionSlotId: _actionSlotId,
            onBook: _book,
            onCancel: _cancel,
            onAdminBook: widget.adminMode ? _adminBook : null,
            onAdminRemoveBooking:
                widget.adminMode ? _adminRemoveBooking : null,
            onEdit: widget.adminMode ? () => _openEdit(event) : null,
            onDateTap: () => _openEventDate(event),
          ),
        if (past.isNotEmpty && widget.adminMode) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text("Past events", style: context.sectionHeader),
          ),
          for (final event in past)
            _EventCard(
              key: widget.eventKeyFor?.call(event.eventId),
              event: event,
              auth: auth,
              adminMode: widget.adminMode,
              initialExpanded: controller.scrollToEventId == event.eventId,
              actionSlotId: _actionSlotId,
              onBook: _book,
              onCancel: _cancel,
              onAdminBook: widget.adminMode ? _adminBook : null,
              onAdminRemoveBooking:
                  widget.adminMode ? _adminRemoveBooking : null,
              onEdit: () => _openEdit(event),
              onDateTap: () => _openEventDate(event),
              isPast: true,
            ),
        ],
      ],
    ];
  }
}

class _EventCard extends StatefulWidget {
  const _EventCard({
    super.key,
    required this.event,
    required this.auth,
    required this.adminMode,
    required this.onBook,
    required this.onCancel,
    this.initialExpanded = false,
    this.onAdminBook,
    this.onAdminRemoveBooking,
    this.onEdit,
    this.onDateTap,
    this.isPast = false,
    this.actionSlotId,
  });

  final LibraryEventItem event;
  final AuthStore auth;
  final bool adminMode;
  final bool initialExpanded;
  final String? actionSlotId;
  final Future<void> Function(EventSlotItem slot, LibraryEventItem event) onBook;
  final Future<void> Function(EventSlotItem slot, LibraryEventItem event) onCancel;
  final Future<void> Function(EventSlotItem slot, LibraryEventItem event)?
      onAdminBook;
  final Future<void> Function(
    EventSlotItem slot,
    EventBookingUser booking,
    LibraryEventItem event,
  )? onAdminRemoveBooking;
  final VoidCallback? onEdit;
  final VoidCallback? onDateTap;
  final bool isPast;

  @override
  State<_EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<_EventCard> {
  late bool _expanded = widget.initialExpanded;

  @override
  void didUpdateWidget(covariant _EventCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialExpanded && !_expanded) {
      _expanded = true;
    }
  }

  LibraryEventItem get event => widget.event;

  bool get _collapsible =>
      widget.adminMode ||
      (!widget.auth.isAdmin &&
          (widget.auth.isMember || widget.auth.isVolunteer));

  String get _slotSummary {
    final count = event.slots.length;
    if (count == 0) return "No slots";
    final booked = event.slots.fold<int>(0, (sum, slot) => sum + slot.bookedCount);
    return count == 1
        ? "1 slot · $booked booked"
        : "$count slots · $booked booked";
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final eventColor = const Color(0xFF5C6BC0);
    final showDetails = !_collapsible || _expanded;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Material(
        color: eventColor.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: eventColor.withValues(alpha: widget.isPast ? 0.25 : 0.45),
            width: 1.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: _collapsible
                    ? () => setState(() => _expanded = !_expanded)
                    : null,
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_collapsible)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          _expanded
                              ? Icons.expand_less
                              : Icons.expand_more,
                          color: eventColor,
                          size: 22,
                        ),
                      )
                    else
                      Icon(Icons.celebration_outlined, color: eventColor, size: 20),
                    SizedBox(width: _collapsible ? 4 : 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.name,
                            style: context.cardTitle.copyWith(fontSize: 15),
                          ),
                          InkWell(
                            onTap: widget.onDateTap,
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      event.dateLabel,
                                      style: context.listSubtitle.copyWith(
                                        fontSize: 12,
                                        color: colors.onSurface.withValues(
                                          alpha: 0.78,
                                        ),
                                        fontWeight: FontWeight.w600,
                                        decoration: widget.onDateTap != null
                                            ? TextDecoration.underline
                                            : null,
                                      ),
                                    ),
                                  ),
                                  if (widget.onDateTap != null) ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.calendar_month_outlined,
                                      size: 14,
                                      color: colors.onSurface.withValues(
                                        alpha: 0.55,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          if (!event.isPublished)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF8E1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFF8D6E00),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  "Draft — not visible to members",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colors.onSurface.withValues(
                                      alpha: 0.88,
                                    ),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          if (_collapsible && !showDetails) ...[
                            const SizedBox(height: 4),
                            Text(
                              _slotSummary,
                              style: context.listSubtitle.copyWith(fontSize: 11),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (widget.onEdit != null)
                      IconButton(
                        tooltip: "Edit event",
                        onPressed: widget.onEdit,
                        icon: const Icon(Icons.edit_outlined, size: 20),
                      ),
                  ],
                ),
              ),
              if (showDetails) ...[
                if (event.description != null &&
                    event.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(event.description!.trim(), style: context.listSubtitle),
                ],
                const SizedBox(height: 10),
                for (final slot in event.slots) ...[
                  _EventSlotRow(
                    key: ValueKey(
                      "${slot.slotId}:${slot.bookedCount}:"
                      "${slot.bookings.map((b) => b.userId).join(',')}",
                    ),
                    slot: slot,
                    event: event,
                    auth: widget.auth,
                    adminMode: widget.adminMode,
                    isPast: widget.isPast,
                    actionInProgress: widget.actionSlotId == slot.slotId,
                    onBook: () => widget.onBook(slot, event),
                    onCancel: () => widget.onCancel(slot, event),
                    onAdminBook: widget.onAdminBook,
                    onAdminRemoveBooking: widget.onAdminRemoveBooking,
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EventSlotRow extends StatelessWidget {
  const _EventSlotRow({
    super.key,
    required this.slot,
    required this.event,
    required this.auth,
    required this.adminMode,
    required this.isPast,
    required this.onBook,
    required this.onCancel,
    this.actionInProgress = false,
    this.onAdminBook,
    this.onAdminRemoveBooking,
  });

  final EventSlotItem slot;
  final LibraryEventItem event;
  final AuthStore auth;
  final bool adminMode;
  final bool isPast;
  final bool actionInProgress;
  final VoidCallback onBook;
  final VoidCallback onCancel;
  final Future<void> Function(EventSlotItem slot, LibraryEventItem event)?
      onAdminBook;
  final Future<void> Function(
    EventSlotItem slot,
    EventBookingUser booking,
    LibraryEventItem event,
  )? onAdminRemoveBooking;

  String get _adminBookLabel =>
      slot.audience == "volunteer" ? "Book volunteer" : "Book member";

  @override
  Widget build(BuildContext context) {
    final canSelfBook = !adminMode &&
        !isPast &&
        !auth.isAdmin &&
        ((slot.audience == "volunteer" && auth.isVolunteer) ||
            (slot.audience == "member" &&
                (auth.isMember || auth.isVolunteer)));

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: slot.userBooked
              ? kBrandYellow
              : Theme.of(context).colorScheme.outlineVariant,
          width: slot.userBooked ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(slot.timeRangeLabel, style: context.cardTitle.copyWith(fontSize: 14)),
                    Text(
                      "${slot.audienceLabel} · "
                      "${slot.bookedCount}/${slot.capacity} booked",
                      style: context.listSubtitle.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (slot.userBooked)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: kBrandYellow.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "Booked",
                    style: context.listSubtitle.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
          if (adminMode && slot.bookings.isNotEmpty) ...[
            const SizedBox(height: 6),
            for (final booking in slot.bookings)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "• ${booking.displayName}",
                      style: context.listSubtitle.copyWith(fontSize: 11),
                    ),
                  ),
                  if (!isPast && onAdminRemoveBooking != null)
                    IconButton(
                      tooltip: "Remove booking",
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      onPressed: () =>
                          onAdminRemoveBooking!(slot, booking, event),
                      icon: Icon(
                        Icons.close,
                        size: 18,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
          ],
          if (adminMode && !isPast && onAdminBook != null && slot.canBook) ...[
            const SizedBox(height: 8),
            BrandChipButton(
              label: _adminBookLabel,
              variant: BrandChipButtonVariant.outlined,
              onPressed: () => onAdminBook!(slot, event),
            ),
          ],
          if (canSelfBook) ...[
            const SizedBox(height: 8),
            if (actionInProgress)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: ToyLibraryLoadingIndicator.compact(),
                  ),
                ),
              )
            else if (slot.userBooked)
              BrandChipButton(
                label: "Cancel booking",
                variant: BrandChipButtonVariant.outlined,
                onPressed: onCancel,
              )
            else if (slot.canBook)
              BrandChipButton(
                label: "Book this slot",
                onPressed: onBook,
              )
            else
              Text(
                "Fully booked",
                style: context.listSubtitle.copyWith(fontSize: 11),
              ),
          ],
        ],
      ),
    );
  }
}
