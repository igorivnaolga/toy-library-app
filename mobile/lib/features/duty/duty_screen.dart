import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../core/app_theme.dart";
import "../../core/auth_store.dart";
import "../../core/brand_chip_button.dart";
import "../bookings/booking_models.dart";
import "duty_assign_sheet.dart";
import "duty_controller.dart";
import "duty_session_models.dart";

/// Volunteer duty roster: Wed/Sat slots, book shifts, admin assign members.
class DutyScreen extends StatefulWidget {
  const DutyScreen({super.key});

  @override
  State<DutyScreen> createState() => _DutyScreenState();
}

class _DutyScreenState extends State<DutyScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<DutyController>().loadRoster();
    });
  }

  Future<void> _book(DutySessionItem session) async {
    final controller = context.read<DutyController>();
    try {
      await controller.bookSession(session.sessionId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Booked ${session.dateLabel}")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(dutyActionErrorMessage(e))),
      );
    }
  }

  Future<void> _cancel(DutySessionItem session) async {
    final controller = context.read<DutyController>();
    try {
      await controller.cancelBooking(session.sessionId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Cancelled ${session.dateLabel}")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(dutyActionErrorMessage(e))),
      );
    }
  }

  Future<void> _openAssign(DutySessionItem session) async {
    await showDutyAssignSheet(context, session.sessionId);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();

    if (!auth.isLoggedIn) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            "Sign in to view and book volunteer duty shifts.",
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (!auth.isVolunteer && !auth.isAdmin) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            "Duty roster is available to volunteers and admins.",
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Consumer<DutyController>(
      builder: (context, controller, _) {
        return RefreshIndicator(
          onRefresh: controller.loadRoster,
          child: _DutyBody(
            auth: auth,
            controller: controller,
            onBook: _book,
            onCancel: _cancel,
            onAssign: auth.isAdmin ? _openAssign : null,
          ),
        );
      },
    );
  }
}

class _DutyBody extends StatelessWidget {
  const _DutyBody({
    required this.auth,
    required this.controller,
    required this.onBook,
    required this.onCancel,
    this.onAssign,
  });

  final AuthStore auth;
  final DutyController controller;
  final Future<void> Function(DutySessionItem session) onBook;
  final Future<void> Function(DutySessionItem session) onCancel;
  final Future<void> Function(DutySessionItem session)? onAssign;

  @override
  Widget build(BuildContext context) {
    if (controller.loading && controller.sessions.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 160),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (controller.error != null && controller.sessions.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          Text(controller.error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Center(
            child: FilledButton.icon(
              onPressed: controller.loading ? null : controller.loadRoster,
              icon: const Icon(Icons.refresh),
              label: const Text("Retry"),
            ),
          ),
        ],
      );
    }

    final sections = splitDutySessions(controller.sessions);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      children: [
        _OnDutyBanner(
          status: controller.onDutyStatus,
          isAdmin: auth.isAdmin,
        ),
        const SizedBox(height: 12),
        if (sections.upcoming.isNotEmpty) ...[
          const _SectionHeader(title: "Upcoming slots"),
          for (var i = 0; i < sections.upcoming.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _DutySessionTile(
              session: sections.upcoming[i],
              currentUserId: auth.userId,
              isAdmin: auth.isAdmin,
              isPast: false,
              loading: controller.loading,
              onBook: () => onBook(sections.upcoming[i]),
              onCancel: () => onCancel(sections.upcoming[i]),
              onTap: onAssign == null
                  ? null
                  : () => onAssign!(sections.upcoming[i]),
            ),
          ],
        ],
        if (sections.upcoming.isNotEmpty && sections.past.isNotEmpty)
          const SizedBox(height: 20),
        if (sections.past.isNotEmpty) ...[
          const _SectionHeader(title: "Past slots"),
          for (var i = 0; i < sections.past.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _DutySessionTile(
              session: sections.past[i],
              currentUserId: auth.userId,
              isAdmin: auth.isAdmin,
              isPast: true,
              loading: controller.loading,
              onBook: () => onBook(sections.past[i]),
              onCancel: () => onCancel(sections.past[i]),
              onTap: onAssign == null
                  ? null
                  : () => onAssign!(sections.past[i]),
            ),
          ],
        ],
      ],
    );
  }
}

class _OnDutyBanner extends StatelessWidget {
  const _OnDutyBanner({required this.status, required this.isAdmin});

  final OnDutyStatus status;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onDuty = status.onDuty;
    final session = status.session;

    return Material(
      color: onDuty
          ? kBrandYellow.withValues(alpha: 0.18)
          : theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(
              onDuty ? Icons.check_circle : Icons.schedule,
              color: onDuty ? kBrandOnYellow : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    onDuty ? "You are on duty now" : "You are not on duty",
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: onDuty ? kBrandOnYellow : null,
                    ),
                  ),
                  if (session != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      "${session.timeRangeLabel} today",
                      style: theme.textTheme.bodySmall,
                    ),
                  ] else if (!onDuty) ...[
                    const SizedBox(height: 2),
                    Text(
                      isAdmin
                          ? "Tap a slot to assign a volunteer."
                          : "Book an upcoming shift to use the volunteer desk.",
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: kBrandOnYellow,
            ),
      ),
    );
  }
}

class _DutySessionTile extends StatelessWidget {
  const _DutySessionTile({
    required this.session,
    required this.currentUserId,
    required this.isAdmin,
    required this.isPast,
    required this.loading,
    required this.onBook,
    required this.onCancel,
    this.onTap,
  });

  final DutySessionItem session;
  final String? currentUserId;
  final bool isAdmin;
  final bool isPast;
  final bool loading;
  final VoidCallback onBook;
  final VoidCallback onCancel;
  final VoidCallback? onTap;

  bool get _isMine =>
      currentUserId != null &&
      currentUserId!.isNotEmpty &&
      session.volunteerId == currentUserId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final status = session.statusLabel(currentUserId: currentUserId);

    Widget? trailing;
    if (!isPast && !isAdmin && session.isOpen) {
      trailing = BrandChipButton(
        label: "Book",
        fixedWidth: 88,
        onPressed: loading ? null : onBook,
      );
    } else if (!isPast && _isMine && !isAdmin) {
      trailing = BrandChipButton(
        label: "Cancel",
        variant: BrandChipButtonVariant.outlined,
        fixedWidth: 88,
        onPressed: loading ? null : onCancel,
      );
    } else if (isAdmin && !isPast) {
      trailing = Icon(Icons.chevron_right, color: colors.onSurfaceVariant);
    }

    final child = Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.dateLabel,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isPast
                        ? colors.onSurface.withValues(alpha: 0.55)
                        : kBrandOnYellow,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  session.timeRangeLabel,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isPast
                        ? colors.onSurface.withValues(alpha: 0.55)
                        : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  status,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _isMine
                        ? colors.primary
                        : colors.onSurface.withValues(alpha: 0.62),
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );

    return Material(
      color: colors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? child
          : InkWell(
              onTap: loading ? null : onTap,
              child: child,
            ),
    );
  }
}
