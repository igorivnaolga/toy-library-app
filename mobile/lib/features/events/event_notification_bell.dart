import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../core/auth_store.dart";
import "../../core/notification_bell_ack.dart";
import "event_models.dart";
import "events_controller.dart";
import "schedule_sheet.dart";

/// Single schedule entry for members/volunteers — red dot when something new.
class ScheduleAppBarButton extends StatefulWidget {
  const ScheduleAppBarButton({super.key});

  @override
  State<ScheduleAppBarButton> createState() => _ScheduleAppBarButtonState();
}

class _ScheduleAppBarButtonState extends State<ScheduleAppBarButton> {
  EventsController? _eventsController;
  AuthStore? _authStore;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<EventsController>().refreshAvailability();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _eventsController?.removeListener(_reconcileAck);
    _authStore?.removeListener(_reconcileAck);
    _eventsController = context.read<EventsController>();
    _authStore = context.read<AuthStore>();
    _eventsController!.addListener(_reconcileAck);
    _authStore!.addListener(_reconcileAck);
  }

  @override
  void dispose() {
    _eventsController?.removeListener(_reconcileAck);
    _authStore?.removeListener(_reconcileAck);
    super.dispose();
  }

  void _reconcileAck() {
    if (!mounted) return;
    final ack = context.read<NotificationBellAckStore>();
    final auth = _authStore!;
    final availability = _eventsController!.availability;
    ack.reconcileMemberSchedule(
      availableSlots: availability.availableSlots,
      volunteerApprovalPending: auth.isVolunteerApprovalPending,
    );
  }

  Future<void> _openSchedule() async {
    final ack = context.read<NotificationBellAckStore>();
    final auth = context.read<AuthStore>();
    final availability = context.read<EventsController>().availability;

    await ack.markMemberScheduleSeen(
      availableSlots: availability.availableSlots,
      volunteerApprovalPending: auth.isVolunteerApprovalPending,
    );
    if (!mounted) return;

    await showScheduleSheet(context);

    if (!mounted) return;
    await context.read<EventsController>().refreshAvailability();
    if (!mounted) return;

    final updated = context.read<EventsController>().availability;
    await ack.markMemberScheduleSeen(
      availableSlots: updated.availableSlots,
      volunteerApprovalPending: auth.isVolunteerApprovalPending,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ack = context.watch<NotificationBellAckStore>();
    final auth = context.watch<AuthStore>();
    final availability = context.select<EventsController, EventAvailability>(
      (controller) => controller.availability,
    );

    final hasUnread = ack.memberScheduleHasUnread(
      availableSlots: availability.availableSlots,
      volunteerApprovalPending: auth.isVolunteerApprovalPending,
    );

    final scheduleLabel =
        auth.usesScheduleCalendar ? "Schedule" : "Library events";

    return IconButton(
      tooltip: hasUnread ? "$scheduleLabel — new updates" : scheduleLabel,
      onPressed: _openSchedule,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            auth.usesScheduleCalendar
                ? Icons.event_available_outlined
                : Icons.event_note_outlined,
          ),
          if (hasUnread)
            Positioned(
              right: -1,
              top: -1,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
