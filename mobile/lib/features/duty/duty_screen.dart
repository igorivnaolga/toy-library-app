import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../core/app_theme.dart";
import "../../core/auth_store.dart";
import "../../core/brand_chip_button.dart";
import "duty_controller.dart";
import "duty_session_models.dart";

/// Volunteer duty roster: view shifts, book open slots, admin manage slots.
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

  Future<void> _delete(DutySessionItem session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Remove duty slot?"),
        content: Text(
          "${session.dateLabel}\n${session.timeRangeLabel}",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Keep"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Remove"),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final controller = context.read<DutyController>();
    try {
      await controller.deleteSession(session.sessionId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Duty slot removed")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(dutyActionErrorMessage(e))),
      );
    }
  }

  Future<void> _addSlot() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 28)),
      selectableDayPredicate: LibrarySessionTimes.isSessionDay,
    );
    if (picked == null || !mounted) return;

    final times = LibrarySessionTimes.forDate(picked);
    if (times == null) return;

    final controller = context.read<DutyController>();
    try {
      await controller.createSession(
        sessionDate: picked,
        startTime: times.start,
        endTime: times.end,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Added ${formatSessionDate(picked)}")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(dutyActionErrorMessage(e))),
      );
    }
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
        return Scaffold(
          floatingActionButton: auth.isAdmin
              ? FloatingActionButton.extended(
                  onPressed: controller.loading ? null : _addSlot,
                  icon: const Icon(Icons.add),
                  label: const Text("Add slot"),
                )
              : null,
          body: RefreshIndicator(
            onRefresh: controller.loadRoster,
            child: _DutyBody(
              auth: auth,
              controller: controller,
              onBook: _book,
              onCancel: _cancel,
              onDelete: auth.isAdmin ? _delete : null,
            ),
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
    this.onDelete,
  });

  final AuthStore auth;
  final DutyController controller;
  final Future<void> Function(DutySessionItem session) onBook;
  final Future<void> Function(DutySessionItem session) onCancel;
  final Future<void> Function(DutySessionItem session)? onDelete;

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

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
      children: [
        _OnDutyBanner(status: controller.onDutyStatus),
        const SizedBox(height: 12),
        if (controller.sessions.isEmpty) ...[
          const SizedBox(height: 80),
          const Center(
            child: Text(
              "No duty slots in the next four weeks.\nPull down to refresh.",
              textAlign: TextAlign.center,
            ),
          ),
        ],
        for (final session in controller.sessions) ...[
          _DutySessionTile(
            session: session,
            currentUserId: auth.userId,
            isAdmin: auth.isAdmin,
            loading: controller.loading,
            isPast: session.sessionDate.isBefore(todayDate),
            onBook: () => onBook(session),
            onCancel: () => onCancel(session),
            onDelete: onDelete == null ? null : () => onDelete!(session),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _OnDutyBanner extends StatelessWidget {
  const _OnDutyBanner({required this.status});

  final OnDutyStatus status;

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
                      "Book a shift below to use the volunteer desk.",
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

class _DutySessionTile extends StatelessWidget {
  const _DutySessionTile({
    required this.session,
    required this.currentUserId,
    required this.isAdmin,
    required this.loading,
    required this.isPast,
    required this.onBook,
    required this.onCancel,
    this.onDelete,
  });

  final DutySessionItem session;
  final String? currentUserId;
  final bool isAdmin;
  final bool loading;
  final bool isPast;
  final VoidCallback onBook;
  final VoidCallback onCancel;
  final VoidCallback? onDelete;

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
    } else if (!isPast && _isMine) {
      trailing = BrandChipButton(
        label: "Cancel",
        variant: BrandChipButtonVariant.outlined,
        fixedWidth: 88,
        onPressed: loading ? null : onCancel,
      );
    } else if (isAdmin && onDelete != null) {
      trailing = IconButton(
        tooltip: "Remove slot",
        onPressed: loading ? null : onDelete,
        icon: Icon(Icons.delete_outline, color: colors.error),
      );
    }

    return Material(
      color: colors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
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
                      color: kBrandOnYellow,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    session.timeRangeLabel,
                    style: theme.textTheme.bodyMedium,
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
      ),
    );
  }
}
