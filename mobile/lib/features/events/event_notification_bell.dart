import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../core/app_text_styles.dart";
import "../../core/app_theme.dart";
import "../../core/auth_store.dart";
import "../../core/notification_bell_ack.dart";
import "events_controller.dart";
import "events_section.dart";

/// Member/volunteer bell badge until first open; includes pending volunteer approval.
int memberNotificationBadgeCount({
  required NotificationBellAckStore ack,
  required int availableEventSlots,
  required bool volunteerApprovalPending,
}) {
  if (ack.memberBellOpened) return 0;
  var count = availableEventSlots;
  if (volunteerApprovalPending) count += 1;
  return count;
}

/// Bell for library events and member notification messages.
class EventNotificationBell extends StatefulWidget {
  const EventNotificationBell({super.key});

  @override
  State<EventNotificationBell> createState() => _EventNotificationBellState();
}

class _EventNotificationBellState extends State<EventNotificationBell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<EventsController>().refreshAvailability();
    });
  }

  Future<void> _openNotifications() async {
    context.read<NotificationBellAckStore>().markMemberBellOpened();
    await showModalBottomSheet<void>(
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
          child: const _MemberNotificationsSheet(),
        );
      },
    );
    if (!mounted) return;
    await context.read<EventsController>().refreshAvailability();
  }

  @override
  Widget build(BuildContext context) {
    final ack = context.watch<NotificationBellAckStore>();
    final auth = context.watch<AuthStore>();
    final availability = context.watch<EventsController>().availability;
    final count = memberNotificationBadgeCount(
      ack: ack,
      availableEventSlots: availability.availableSlots,
      volunteerApprovalPending: auth.isVolunteerApprovalPending,
    );

    return IconButton(
      tooltip: count > 0 ? "Notifications" : "Notifications",
      onPressed: _openNotifications,
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text(count > 9 ? "9+" : "$count"),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}

class _MemberNotificationsSheet extends StatelessWidget {
  const _MemberNotificationsSheet();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();
    final pendingVolunteer = auth.isVolunteerApprovalPending;

    return ColoredBox(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Text(
              "Notifications",
              style: context.screenTitle,
            ),
          ),
          if (pendingVolunteer)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Material(
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
                              "An admin will confirm your volunteer membership "
                              "soon. You can browse and book toys as a member "
                              "in the meantime.",
                              style: context.listSubtitle.copyWith(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              "Library events",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: EventsSection(
              hideHeader: true,
              scrollable: true,
              scheduleHostContext: context,
            ),
          ),
        ],
      ),
    );
  }
}
