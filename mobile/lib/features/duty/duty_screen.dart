import "dart:async";

import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../core/toy_loading_indicator.dart";
import "../../core/app_text_styles.dart";
import "../../core/section_header.dart";
import "../../core/auth_store.dart";
import "../../core/brand_chip_button.dart";
import "duty_assign_sheet.dart";
import "duty_controller.dart";
import "duty_session_models.dart";
import "../bookings/booking_models.dart";
import "../events/event_scroll.dart";
import "../events/events_controller.dart";
import "../events/schedule_date_finder.dart";

/// Volunteer duty roster: Wed/Sat slots, book shifts, admin assign members.
class DutyScreen extends StatefulWidget {
  const DutyScreen({
    super.key,
    this.useTabs = false,
    this.hidePast = false,
    this.hideDateFinder = false,
  });

  /// When true, upcoming and past slots appear in separate tabs (admin sheet).
  final bool useTabs;

  /// When true, past slots are hidden (volunteer roster view).
  final bool hidePast;

  /// When true, the in-tab calendar picker is hidden (schedule sheet header).
  final bool hideDateFinder;

  @override
  State<DutyScreen> createState() => DutyScreenState();
}

class DutyScreenState extends State<DutyScreen> {
  final Map<String, GlobalKey> _tileKeys = {};
  final ScrollController upcomingScrollController = ScrollController();
  final ScrollController pastScrollController = ScrollController();
  String? _scrollInProgressFor;
  DutyController? _duty;

  GlobalKey _keyForSession(String sessionId) =>
      _tileKeys.putIfAbsent(sessionId, GlobalKey.new);

  ScrollController _scrollControllerFor(bool isPast) =>
      isPast ? pastScrollController : upcomingScrollController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _duty = context.read<DutyController>();
      _duty!.addListener(_onDutyControllerChanged);
      if (_duty!.sessions.isEmpty && !_duty!.loading) {
        _duty!.loadRoster();
      }
    });
  }

  @override
  void dispose() {
    _duty?.removeListener(_onDutyControllerChanged);
    upcomingScrollController.dispose();
    pastScrollController.dispose();
    super.dispose();
  }

  void _onDutyControllerChanged() {
    final sessionId = _duty?.scrollToSessionId;
    if (sessionId == null || sessionId == _scrollInProgressFor || !mounted) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      scrollToPendingSession();
    });
  }

  Future<bool> scrollToPendingSession() async {
    final controller = context.read<DutyController>();
    if (controller.scrollToSessionId == null) return false;
    await _scrollToRequestedSession(context, controller);
    return controller.scrollToSessionId == null;
  }

  Future<void> _switchSubTabForSession(DutySessionItem session) async {
    if (!widget.useTabs) return;
    final innerTab = DefaultTabController.maybeOf(context);
    if (innerTab == null || innerTab.length < 2) return;
    await switchDutySubTabForDate(context, session.sessionDate);
  }

  Future<void> _scrollToRequestedSession(
    BuildContext context,
    DutyController controller,
  ) async {
    final sessionId = controller.scrollToSessionId;
    if (sessionId == null || sessionId == _scrollInProgressFor) return;
    _scrollInProgressFor = sessionId;

    try {
      DutySessionItem? session;
      for (final item in controller.sessions) {
        if (item.sessionId == sessionId) {
          session = item;
          break;
        }
      }
      if (session != null) {
        await _switchSubTabForSession(session);
        await waitForScheduleTabLayout(frames: 4);
      }
      if (!mounted) return;

      final isPast = session != null &&
          calendarDay(session.sessionDate).isBefore(calendarDay(DateTime.now()));

      List<DutySessionItem> listItems;
      if (widget.useTabs) {
        listItems = isPast
            ? splitDutySessions(controller.sessions).past
            : splitDutySessions(controller.sessions).upcoming;
      } else {
        listItems = splitDutySessions(
          controller.sessions,
          pastForVolunteerId: context.read<AuthStore>().isAdmin
              ? null
              : context.read<AuthStore>().userId,
        ).upcoming;
      }
      final listIndex = listItems.indexWhere((s) => s.sessionId == sessionId);
      final scrolled = await scrollToSessionCard(
        sessionId: sessionId,
        keyForSession: _keyForSession,
        scrollController: _scrollControllerFor(widget.useTabs ? isPast : false),
        listIndex: listIndex >= 0 ? listIndex : null,
      );
      if (!mounted) return;
      if (scrolled) {
        controller.clearScrollRequest();
      }
    } finally {
      if (_scrollInProgressFor == sessionId) {
        _scrollInProgressFor = null;
      }
    }
  }

  Future<void> _book(DutySessionItem session) async {
    final controller = context.read<DutyController>();
    try {
      final result = await controller.bookSession(session.sessionId);
      if (!mounted) return;
      if (result.milestoneMessage != null &&
          result.milestoneMessage!.trim().isNotEmpty) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text("Thank you for volunteering"),
            content: Text(result.milestoneMessage!),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text("Got it"),
              ),
            ],
          ),
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Booked ${session.dateLabel}")),
      );
      final now = DateTime.now();
      unawaited(
        context.read<EventsController>().loadScheduleDates(
          DateTime(now.year, now.month - 1, 1),
          DateTime(now.year, now.month + 2, 0),
        ),
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
                  hideDateFinder: widget.hideDateFinder,
                  showFindDate: !widget.hideDateFinder,
                  scrollController: upcomingScrollController,
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
                  hideDateFinder: widget.hideDateFinder,
                  showFindDate: !widget.hideDateFinder,
                  pastSectionTitle: "Past slots",
                  scrollController: pastScrollController,
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
            hidePast: widget.hidePast,
            hideDateFinder: widget.hideDateFinder,
            scrollController: upcomingScrollController,
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
    this.hidePast = false,
    this.hideDateFinder = false,
    this.showFindDate = false,
    this.pastSectionTitle,
    this.onAssign,
    this.sessionKeyFor,
    this.scrollController,
  });

  final AuthStore auth;
  final DutyController controller;
  final Future<void> Function(DutySessionItem session) onBook;
  final Future<void> Function(DutySessionItem session) onCancel;
  final Future<void> Function(DutySessionItem session)? onAssign;
  final List<DutySessionItem>? sessions;
  final bool isPast;
  final bool hidePast;
  final bool hideDateFinder;
  final bool showFindDate;
  final String? pastSectionTitle;
  final GlobalKey Function(String sessionId)? sessionKeyFor;
  final ScrollController? scrollController;

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
          Center(child: ToyLibraryLoadingIndicator()),
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

    return _dutyScrollLayout(
      context,
      loadPast: false,
      pinnedHeader: hideDateFinder
          ? null
          : _DutySlotsSectionHeader(
              title: "Upcoming slots",
              onFindDate: () =>
                  findScheduleDate(context, source: ScheduleDateSource.duty),
            ),
      children: [
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
        if (!hidePast) ...[
          if (sections.upcoming.isNotEmpty && sections.past.isNotEmpty)
            const SizedBox(height: 20),
          if (sections.past.isNotEmpty) ...[
            const SectionHeader("Past slots"),
            ..._slotTiles(context, sections.past, isPast: true),
          ],
        ],
      ],
    );
  }

  Widget _dutyScrollLayout(
    BuildContext context, {
    required List<Widget> children,
    Widget? pinnedHeader,
    Widget? scrollHeader,
    bool loadPast = false,
  }) {
    final listPadding = const EdgeInsets.fromLTRB(12, 0, 12, 12);
    final canLoadMore =
        loadPast ? controller.canLoadMorePast : controller.canLoadMoreFuture;
    final listChildren = [
      if (scrollHeader != null) scrollHeader,
      ...children,
      if (canLoadMore || controller.loadingMore) _LoadMoreFooter(loading: controller.loadingMore),
    ];

    final scrollArea = _DutyScrollArea(
      scrollController: scrollController,
      padding: pinnedHeader == null
          ? const EdgeInsets.fromLTRB(12, 8, 12, 12)
          : listPadding,
      enabled: canLoadMore && !controller.loadingMore && !controller.loading,
      onNearEnd: () {
        if (loadPast) {
          controller.loadMorePast();
        } else {
          controller.loadMoreFuture();
        }
      },
      children: listChildren,
    );

    if (pinnedHeader == null) {
      return scrollArea;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 12, 0),
                child: pinnedHeader,
              ),
              Divider(
                height: 1,
                color: Theme.of(context)
                    .colorScheme
                    .outlineVariant
                    .withValues(alpha: 0.65),
              ),
            ],
          ),
        ),
        Expanded(child: scrollArea),
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
      return _dutyScrollLayout(
        context,
        loadPast: isPast,
        pinnedHeader: showFindDate
            ? _DutySlotsSectionHeader(
                title: isPast
                    ? (pastSectionTitle ?? "Past slots")
                    : "Upcoming slots",
                onFindDate: () =>
                    findScheduleDate(context, source: ScheduleDateSource.duty),
              )
            : null,
        scrollHeader: pastSectionTitle != null && !showFindDate
            ? SectionHeader(pastSectionTitle)
            : null,
        children: [
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

    return _dutyScrollLayout(
      context,
      loadPast: isPast,
      pinnedHeader: showFindDate
          ? _DutySlotsSectionHeader(
              title: isPast
                  ? (pastSectionTitle ?? "Past slots")
                  : "Upcoming slots",
              onFindDate: () =>
                  findScheduleDate(context, source: ScheduleDateSource.duty),
            )
          : null,
      scrollHeader: pastSectionTitle != null && !showFindDate
          ? SectionHeader(pastSectionTitle)
          : null,
      children: _slotTiles(context, items, isPast: isPast),
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

class _LoadMoreFooter extends StatelessWidget {
  const _LoadMoreFooter({required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: ToyLibraryLoadingIndicator.compact(),
              )
            : const SizedBox(height: 8),
      ),
    );
  }
}

class _DutyScrollArea extends StatefulWidget {
  const _DutyScrollArea({
    required this.children,
    required this.padding,
    required this.onNearEnd,
    this.scrollController,
    this.enabled = true,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final VoidCallback onNearEnd;
  final ScrollController? scrollController;
  final bool enabled;

  @override
  State<_DutyScrollArea> createState() => _DutyScrollAreaState();
}

class _DutyScrollAreaState extends State<_DutyScrollArea> {
  ScrollController? _ownedController;
  bool _nearEndHandled = false;

  ScrollController get _controller =>
      widget.scrollController ?? _ownedController!;

  @override
  void initState() {
    super.initState();
    if (widget.scrollController == null) {
      _ownedController = ScrollController();
    }
    _controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant _DutyScrollArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !oldWidget.enabled) {
      _nearEndHandled = false;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _ownedController?.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!widget.enabled || !_controller.hasClients) return;
    final position = _controller.position;
    if (position.maxScrollExtent <= 0) return;
    if (position.pixels >= position.maxScrollExtent - 240) {
      if (_nearEndHandled) return;
      _nearEndHandled = true;
      widget.onNearEnd();
    } else if (position.pixels < position.maxScrollExtent - 320) {
      _nearEndHandled = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: _controller,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: widget.padding,
      children: widget.children,
    );
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

class _MyShiftStatusBadge extends StatelessWidget {
  const _MyShiftStatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF43A047)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: const Color(0xFF1B5E20),
          fontWeight: FontWeight.w700,
        ),
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
    final status = session.statusLabel(
      currentUserId: currentUserId,
      isAdmin: isAdmin,
    );
    final showMyShiftBadge =
        !isAdmin && _isMine && !session.isOpen && !isPast;

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
                const SizedBox(height: 6),
                if (showMyShiftBadge)
                  _MyShiftStatusBadge(label: status)
                else
                  Text(
                    status,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _isMine
                          ? colors.primary
                          : colors.onSurface.withValues(alpha: kTextMutedAlpha),
                      fontWeight: _isMine ? FontWeight.w600 : FontWeight.w400,
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
