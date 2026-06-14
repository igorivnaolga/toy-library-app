import "package:flutter/material.dart";

import "../../core/app_text_styles.dart";
import "../../core/section_header.dart";
import "duty_session_models.dart";

/// Collapsible upcoming/completed duty shift lists for volunteer profiles.
class VolunteerDutyShiftsBody extends StatefulWidget {
  const VolunteerDutyShiftsBody({
    super.key,
    required this.active,
    required this.loadSessions,
  });

  final bool active;
  final Future<VolunteerDutySessionGroups> Function() loadSessions;

  @override
  State<VolunteerDutyShiftsBody> createState() => _VolunteerDutyShiftsBodyState();
}

class _VolunteerDutyShiftsBodyState extends State<VolunteerDutyShiftsBody> {
  VolunteerDutySessionGroups? _groups;
  bool _loading = false;
  String? _error;
  bool _loaded = false;
  bool _upcomingExpanded = true;
  bool _completedExpanded = false;

  @override
  void didUpdateWidget(covariant VolunteerDutyShiftsBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _ensureLoaded();
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.active) {
      _ensureLoaded();
    }
  }

  Future<void> _ensureLoaded() async {
    if (_loaded || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final groups = await widget.loadSessions();
      if (!mounted) return;
      setState(() {
        _groups = groups;
        _loading = false;
        _loaded = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Text(
          "Could not load duty shifts.",
          style: context.listSubtitle,
        ),
      );
    }

    final groups = _groups ?? const VolunteerDutySessionGroups();
    if (groups.upcoming.isEmpty && groups.completed.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Text(
          "No duty shifts booked yet.",
          style: context.listSubtitle,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CollapsibleSection(
            title: groups.upcoming.isEmpty
                ? "Upcoming"
                : "Upcoming (${groups.upcoming.length})",
            expanded: _upcomingExpanded,
            onToggle: () =>
                setState(() => _upcomingExpanded = !_upcomingExpanded),
            children: [
              if (groups.upcoming.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: Text(
                    "No upcoming shifts.",
                    style: context.listSubtitle,
                  ),
                )
              else
                ...groups.upcoming.map(
                  (session) => _DutyShiftRow(
                    session: session,
                    completed: false,
                  ),
                ),
            ],
          ),
          if (groups.completed.isNotEmpty) ...[
            const SizedBox(height: 12),
            CollapsibleSection(
              title: "Completed (${groups.completed.length})",
              expanded: _completedExpanded,
              onToggle: () =>
                  setState(() => _completedExpanded = !_completedExpanded),
              children: groups.completed
                  .map(
                    (session) => _DutyShiftRow(
                      session: session,
                      completed: true,
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _DutyShiftRow extends StatelessWidget {
  const _DutyShiftRow({
    required this.session,
    required this.completed,
  });

  final DutySessionItem session;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = completed
        ? (session.adminConfirmed ? "Confirmed" : "Completed")
        : "Booked";

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            completed ? Icons.check_circle_outline : Icons.event_outlined,
            size: 20,
            color: completed
                ? theme.colorScheme.primary
                : theme.colorScheme.secondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(session.dateLabel, style: context.cardTitle),
                const SizedBox(height: 2),
                Text(
                  session.timeRangeLabel,
                  style: context.listSubtitle,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            status,
            style: theme.textTheme.labelSmall?.copyWith(
              color: completed
                  ? theme.colorScheme.primary
                  : theme.colorScheme.secondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
