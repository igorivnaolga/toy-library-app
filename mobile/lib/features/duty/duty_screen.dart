import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../core/app_text_styles.dart";
import "../../core/app_theme.dart";
import "../../core/section_header.dart";
import "../../core/auth_store.dart";
import "../../core/brand_chip_button.dart";
import "duty_assign_sheet.dart";
import "duty_controller.dart";
import "duty_date_finder.dart";
import "duty_session_models.dart";

/// Volunteer duty roster: Wed/Sat slots, book shifts, admin assign members.
class DutyScreen extends StatefulWidget {
  const DutyScreen({super.key, this.useTabs = false});

  /// When true, upcoming and past slots appear in separate tabs (admin sheet).
  final bool useTabs;

  @override
  State<DutyScreen> createState() => _DutyScreenState();
}

/// Admin app-bar action: duty slots in a sheet matching other modals.
Future<void> showDutyRosterSheet(BuildContext context) {
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
        child: const _DutyRosterSheet(),
      );
    },
  );
}

/// Duty roster content for the admin bottom sheet (light background, no on-duty banner).
class _DutyRosterSheet extends StatelessWidget {
  const _DutyRosterSheet();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: DefaultTabController(
        length: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Text(
                "Duty roster",
                style: context.screenTitle,
              ),
            ),
            Material(
              color: Theme.of(context).colorScheme.surface,
              child: const TabBar(
                tabs: [
                  Tab(text: "Upcoming slots"),
                  Tab(text: "Past slots"),
                ],
              ),
            ),
            const Expanded(
              child: DutyScreen(useTabs: true),
            ),
          ],
        ),
      ),
    );
  }
}

class _DutyScreenState extends State<DutyScreen> {
  final Map<String, GlobalKey> _tileKeys = {};

  GlobalKey _keyForSession(String sessionId) =>
      _tileKeys.putIfAbsent(sessionId, GlobalKey.new);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<DutyController>().loadRoster();
    });
  }

  void _scrollToSession(BuildContext context, DutyController controller) {
    final sessionId = controller.scrollToSessionId;
    if (sessionId == null) return;
    final key = _tileKeys[sessionId];
    final target = key?.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        alignment: 0.15,
      );
    }
    controller.clearScrollRequest();
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
        if (controller.scrollToSessionId != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _scrollToSession(context, controller);
          });
        }

        if (widget.useTabs) {
          return TabBarView(
            children: [
              RefreshIndicator(
                onRefresh: controller.loadRoster,
                child: _DutyBody(
                  auth: auth,
                  controller: controller,
                  sessions: splitDutySessions(controller.sessions).upcoming,
                  isPast: false,
                  showFindDate: true,
                  onBook: _book,
                  onCancel: _cancel,
                  onAssign: auth.isAdmin ? _openAssign : null,
                  sessionKeyFor: _keyForSession,
                ),
              ),
              RefreshIndicator(
                onRefresh: controller.loadRoster,
                child: _DutyBody(
                  auth: auth,
                  controller: controller,
                  sessions: splitDutySessions(controller.sessions).past,
                  isPast: true,
                  pastSectionTitle: "Past slots",
                  onBook: _book,
                  onCancel: _cancel,
                  onAssign: auth.isAdmin ? _openAssign : null,
                  sessionKeyFor: _keyForSession,
                ),
              ),
            ],
          );
        }

        return RefreshIndicator(
          onRefresh: controller.loadRoster,
          child: _DutyBody(
            auth: auth,
            controller: controller,
            onBook: _book,
            onCancel: _cancel,
            onAssign: auth.isAdmin ? _openAssign : null,
            sessionKeyFor: _keyForSession,
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
    this.sessions,
    this.isPast = false,
    this.showFindDate = false,
    this.pastSectionTitle,
    this.onAssign,
    this.sessionKeyFor,
  });

  final AuthStore auth;
  final DutyController controller;
  final Future<void> Function(DutySessionItem session) onBook;
  final Future<void> Function(DutySessionItem session) onCancel;
  final Future<void> Function(DutySessionItem session)? onAssign;
  final List<DutySessionItem>? sessions;
  final bool isPast;
  final bool showFindDate;
  final String? pastSectionTitle;
  final GlobalKey Function(String sessionId)? sessionKeyFor;

  DutySessionSections _sections() => splitDutySessions(
        controller.sessions,
        pastForVolunteerId: auth.isAdmin ? null : auth.userId,
      );

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

    if (sessions != null) {
      return _buildSlotList(
        context,
        sessions!,
        isPast: isPast,
        showFindDate: showFindDate,
        pastSectionTitle: pastSectionTitle,
      );
    }

    final sections = _sections();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      children: [
        _DutySlotsSectionHeader(
          title: "Upcoming slots",
          onFindDate: () => findDutyDate(context),
        ),
        if (sections.upcoming.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              "No upcoming duty slots.",
              style: context.emptyState,
            ),
          )
        else
          ..._slotTiles(context, sections.upcoming, isPast: false),
        if (sections.upcoming.isNotEmpty && sections.past.isNotEmpty)
          const SizedBox(height: 20),
        if (sections.past.isNotEmpty) ...[
          const SectionHeader("Past slots"),
          ..._slotTiles(context, sections.past, isPast: true),
        ],
      ],
    );
  }

  Widget _buildSlotList(
    BuildContext context,
    List<DutySessionItem> items, {
    required bool isPast,
    bool showFindDate = false,
    String? pastSectionTitle,
  }) {
    if (items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        children: [
          if (showFindDate)
            _DutySlotsSectionHeader(
              title: "Upcoming slots",
              onFindDate: () => findDutyDate(context),
            ),
          if (pastSectionTitle != null)
            SectionHeader(pastSectionTitle),
          const SizedBox(height: 80),
          Center(
            child: Text(
              isPast ? "No past duty slots." : "No upcoming duty slots.",
              textAlign: TextAlign.center,
              style: context.emptyState,
            ),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      children: [
        if (showFindDate)
          _DutySlotsSectionHeader(
            title: "Upcoming slots",
            onFindDate: () => findDutyDate(context),
          ),
        if (pastSectionTitle != null) SectionHeader(pastSectionTitle),
        ..._slotTiles(context, items, isPast: isPast),
      ],
    );
  }

  List<Widget> _slotTiles(
    BuildContext context,
    List<DutySessionItem> items, {
    required bool isPast,
  }) {
    return [
      for (var i = 0; i < items.length; i++) ...[
        if (i > 0) const SizedBox(height: 8),
        _DutySessionTile(
          key: sessionKeyFor?.call(items[i].sessionId),
          session: items[i],
          currentUserId: auth.userId,
          isAdmin: auth.isAdmin,
          isPast: isPast,
          loading: controller.loading,
          onBook: () => onBook(items[i]),
          onCancel: () => onCancel(items[i]),
          onTap: onAssign == null ? null : () => onAssign!(items[i]),
        ),
      ],
    ];
  }
}

class _DutySlotsSectionHeader extends StatelessWidget {
  const _DutySlotsSectionHeader({
    required this.title,
    this.onFindDate,
  });

  final String title;
  final VoidCallback? onFindDate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 0, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: context.sectionHeader),
          ),
          if (onFindDate != null)
            IconButton(
              tooltip: "Find duty date",
              icon: const Icon(Icons.calendar_month_outlined),
              visualDensity: VisualDensity.compact,
              onPressed: onFindDate,
            ),
        ],
      ),
    );
  }
}

class _DutySessionTile extends StatelessWidget {
  const _DutySessionTile({
    super.key,
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
                  style: isPast ? context.cardTitleMuted : context.cardTitle,
                ),
                const SizedBox(height: 4),
                Text(
                  session.timeRangeLabel,
                  style: context.listSecondary(muted: isPast),
                ),
                const SizedBox(height: 2),
                Text(
                  status,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _isMine
                        ? colors.primary
                        : colors.onSurface.withValues(alpha: kTextMutedAlpha),
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
