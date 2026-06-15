import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../core/toy_loading_indicator.dart";
import "../../core/app_input_field.dart";
import "../../core/app_text_styles.dart";
import "../../core/app_theme.dart";
import "../../core/loan_due_status.dart";
import "../../core/section_header.dart";
import "../../core/brand_chip_button.dart";
import "../bookings/booking_checkout_sync.dart";
import "../bookings/booking_models.dart";
import "../duty/duty_session_models.dart";
import "../catalog/catalog_provider.dart";
import "../catalog/toy_detail_screen.dart";
import "../catalog/toy_photo_tile.dart";
import "../loans/desk_check_in_dialog.dart";
import "../loans/desk_checkout_dialog.dart";
import "../loans/desk_walk_in_panel.dart";
import "../loans/loan_due_date_header.dart";
import "../loans/loan_desk_summary.dart";
import "../loans/loan_models.dart";
import "../loans/loans_controller.dart";
import "admin_controller.dart";
import "admin_cv_scan_panel.dart";

/// Admin desk: separate check-out and check-in flows (CV-ready check-in).
class AdminLoansScreen extends StatefulWidget {
  const AdminLoansScreen({
    super.key,
    this.volunteerDeskMode = false,
    this.refreshOnMainTabIndex,
  });

  /// When true, desk access requires an admin-confirmed duty shift today.
  final bool volunteerDeskMode;

  /// When set, reload desk data each time this bottom-nav tab is selected.
  final int? refreshOnMainTabIndex;

  @override
  State<AdminLoansScreen> createState() => _AdminLoansScreenState();
}

/// Check-in desk filtered to one member and due date (from member profile).
class AdminMemberCheckInScreen extends StatefulWidget {
  const AdminMemberCheckInScreen({
    super.key,
    required this.memberUserId,
    required this.memberName,
    required this.dueDate,
    required this.initialLoans,
  });

  final String memberUserId;
  final String memberName;
  final DateTime dueDate;
  final List<LoanItem> initialLoans;

  @override
  State<AdminMemberCheckInScreen> createState() =>
      _AdminMemberCheckInScreenState();
}

class _AdminMemberCheckInScreenState extends State<AdminMemberCheckInScreen> {
  late List<LoanItem> _loans;
  String? _checkingInLoanId;
  bool _refreshing = false;
  final TextEditingController _searchController = TextEditingController();
  String _query = "";

  @override
  void initState() {
    super.initState();
    _loans = List<LoanItem>.from(widget.initialLoans);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<LoanItem> get _visibleLoans => filterCheckInLoans(
        _loans,
        query: _query,
        memberUserId: widget.memberUserId,
        dueDate: widget.dueDate,
        includeMemberInSearch: false,
      );

  Future<void> _refreshLoans() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      final all = await context
          .read<AdminController>()
          .loadMemberLoans(widget.memberUserId);
      if (!mounted) return;
      setState(() {
        _loans = all
            .where(
              (loan) =>
                  loan.isActive &&
                  _sameDay(loan.returnSessionDate, widget.dueDate),
            )
            .toList();
      });
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _checkIn(LoanItem loan) async {
    if (_checkingInLoanId != null) return;
    final result = await showDeskCheckInDialog(context, loan);
    if (result == null || !mounted) return;

    setState(() => _checkingInLoanId = loan.loanId);
    final controller = context.read<LoansController>();
    final catalog = context.read<CatalogController>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await controller.checkIn(
        loan.loanId,
        missingPieces: result.missingPieces,
        missingPiecesDetail: result.missingPiecesDetail,
      );
      await catalog.refresh();
      if (!mounted) return;
      setState(() {
        _checkingInLoanId = null;
        _loans = _loans.where((item) => item.loanId != loan.loanId).toList();
      });
      messenger.showSnackBar(
        SnackBar(content: Text("Checked in ${loan.toyName ?? loan.toyId}")),
      );
      if (kDeskCheckInCvEnabled) {
        final photoLearn = result.photoLearn;
        if (photoLearn != null) {
          runDeskPhotoLearnInBackground(controller, messenger, photoLearn);
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _checkingInLoanId = null);
      messenger.showSnackBar(
        SnackBar(content: Text(loanActionErrorMessage(e))),
      );
    }
  }

  void _openToy(String toyId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ToyDetailScreen(toyId: toyId),
      ),
    );
  }

  Future<void> _handleScannedToyId(String toyId) async {
    LoanItem? match;
    for (final loan in _visibleLoans) {
      if (loan.toyId != toyId) continue;
      match = loan;
      break;
    }
    if (!mounted) return;
    if (match == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Toy $toyId isn't on loan to ${widget.memberName} for this due date.",
          ),
        ),
      );
      return;
    }
    await _checkIn(match);
  }

  @override
  Widget build(BuildContext context) {
    final busy = _checkingInLoanId != null || _refreshing;
    final visible = _visibleLoans;
    final isOverdue = _loans.isNotEmpty
        ? _loans.any((loan) => loan.effectiveIsOverdue)
        : isLoanOverdue(widget.dueDate);
    final isDueToday = !isOverdue &&
        (_loans.isNotEmpty
            ? _loans.any((loan) => loan.effectiveIsDueToday)
            : isLoanDueToday(widget.dueDate));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Check in"),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshLoans,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          children: [
            _MemberCheckInHeader(
              memberName: widget.memberName,
              dueDate: widget.dueDate,
              isOverdue: isOverdue,
              isDueToday: isDueToday,
              toyCount: _loans.length,
            ),
            const SizedBox(height: 16),
            if (kDeskToyIdScanEnabled) ...[
              AdminCvScanPanel(onToyIdScanned: _handleScannedToyId),
              const SizedBox(height: 16),
            ],
            if (_loans.isNotEmpty) ...[
              TextField(
                controller: _searchController,
                style: fieldTextStyle(context),
                cursorColor: fieldCursorColor(context),
                textInputAction: TextInputAction.search,
                decoration: searchInputDecoration(
                  context,
                  hintText: "Search by toy or ID",
                  suffixIcon: searchClearSuffix(
                    context,
                    visible: _query.isNotEmpty,
                    onClear: () {
                      _searchController.clear();
                      setState(() => _query = "");
                    },
                  ),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 12),
            ],
            if (_loans.isEmpty)
              SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.35,
                child: Center(
                  child: Text(
                    _refreshing
                        ? "Refreshing…"
                        : "No toys on loan for this due date.",
                    textAlign: TextAlign.center,
                    style: context.listSubtitle,
                  ),
                ),
              )
            else if (visible.isEmpty)
              SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.25,
                child: Center(
                  child: Text(
                    'No toys match "${_query.trim()}".',
                    textAlign: TextAlign.center,
                    style: context.listSubtitle,
                  ),
                ),
              )
            else ...[
              const SectionHeader("On loan"),
              for (var i = 0; i < visible.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                _CheckInTile(
                  loan: visible[i],
                  loading: busy && _checkingInLoanId == visible[i].loanId,
                  onOpen: () => _openToy(visible[i].toyId),
                  onCheckIn: () => _checkIn(visible[i]),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

DateTime _sameDayKey(DateTime date) =>
    DateTime(date.year, date.month, date.day);

bool _sameDay(DateTime a, DateTime b) => _sameDayKey(a) == _sameDayKey(b);

/// Member + due date context when opening check-in from the admin profile.
class _MemberCheckInHeader extends StatelessWidget {
  const _MemberCheckInHeader({
    required this.memberName,
    required this.dueDate,
    required this.isOverdue,
    required this.isDueToday,
    required this.toyCount,
  });

  final String memberName;
  final DateTime dueDate;
  final bool isOverdue;
  final bool isDueToday;
  final int toyCount;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final iconColor =
        isOverdue ? colors.error : colors.primary.withValues(alpha: 0.85);

    return Material(
      color: kModalSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.65)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.person_outline, size: 22, color: iconColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Member", style: context.formSectionLabel),
                      const SizedBox(height: 2),
                      Text(
                        memberName,
                        style: context.cardTitle.copyWith(fontSize: 17),
                      ),
                      if (toyCount > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          toyCount == 1
                              ? "1 toy to check in"
                              : "$toyCount toys to check in",
                          style: context.listSubtitle,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: colors.outlineVariant.withValues(alpha: 0.5),
          ),
          LoanDueDateHeader(
            dueDate: dueDate,
            isOverdue: isOverdue,
            isDueToday: isDueToday,
            embedded: true,
          ),
        ],
      ),
    );
  }
}

class _AdminLoansScreenState extends State<AdminLoansScreen> {
  TabController? _mainTabController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDesk());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final index = widget.refreshOnMainTabIndex;
    if (index == null) return;
    final controller = DefaultTabController.maybeOf(context);
    if (controller == null || identical(controller, _mainTabController)) {
      return;
    }
    _mainTabController?.removeListener(_onMainTabChanged);
    _mainTabController = controller;
    _mainTabController!.addListener(_onMainTabChanged);
    if (controller.index == index) {
      _loadDesk();
    }
  }

  @override
  void dispose() {
    _mainTabController?.removeListener(_onMainTabChanged);
    super.dispose();
  }

  void _onMainTabChanged() {
    final controller = _mainTabController;
    final index = widget.refreshOnMainTabIndex;
    if (controller == null || index == null || controller.indexIsChanging) {
      return;
    }
    if (controller.index == index) {
      _loadDesk();
    }
  }

  void _loadDesk() {
    if (!mounted) return;
    context.read<LoansController>().loadVolunteerDesk();
  }

  Future<void> _checkOutReservations(List<BookingItem> bookings) async {
    if (bookings.isEmpty) return;

    final member = bookings.first;
    final result = await showDeskCheckoutDialog(
      context,
      memberLabel: member.memberLabel,
      memberUserId: member.userId,
      lines: [
        for (final booking in bookings)
          DeskCheckoutLine(
            toyId: booking.toyId,
            toyName: booking.toyName ?? booking.toyId,
            rentalPriceCents: booking.rentalPriceCents,
          ),
      ],
    );
    if (result == null || !mounted) return;

    final controller = context.read<LoansController>();
    try {
      for (final booking in bookings) {
        await controller.checkOutFromBooking(
          booking.bookingId,
          rentalPayment: result.rentalPayment,
          paymentMethod: result.paymentMethod,
        );
      }
      if (!mounted) return;
      await syncAfterReservationCheckout(context, bookings);
      if (!mounted) return;
      final message = bookings.length == 1
          ? "Checked out ${bookings.first.toyName ?? bookings.first.toyId}"
          : "Checked out ${bookings.length} reserved toys";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loanActionErrorMessage(e))),
      );
    }
  }

  Future<void> _checkOut(BookingItem booking) =>
      _checkOutReservations([booking]);

  Future<void> _handleScannedToyId(String toyId) async {
    final controller = context.read<LoansController>();
    LoanItem? match;
    for (final loan in controller.activeLoans) {
      if (loan.toyId == toyId) {
        match = loan;
        break;
      }
    }
    if (!mounted) return;
    if (match == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Toy $toyId isn't on loan right now.")),
      );
      return;
    }
    await _checkIn(match);
  }

  Future<void> _checkIn(LoanItem loan) async {
    final result = await showDeskCheckInDialog(context, loan);
    if (result == null || !mounted) return;

    final controller = context.read<LoansController>();
    final catalog = context.read<CatalogController>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await controller.checkIn(
        loan.loanId,
        missingPieces: result.missingPieces,
        missingPiecesDetail: result.missingPiecesDetail,
      );
      await catalog.refresh();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text("Checked in ${loan.toyName ?? loan.toyId}")),
      );
      if (kDeskCheckInCvEnabled) {
        final photoLearn = result.photoLearn;
        if (photoLearn != null) {
          runDeskPhotoLearnInBackground(controller, messenger, photoLearn);
        }
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(loanActionErrorMessage(e))),
      );
    }
  }

  void _openToy(String toyId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ToyDetailScreen(toyId: toyId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.volunteerDeskMode) {
      return Consumer<LoansController>(
        builder: (context, c, _) {
          final offDuty = c.deskError != null &&
              c.pendingCheckouts.isEmpty &&
              c.activeLoans.isEmpty;
          if (offDuty) {
            return RefreshIndicator(
              onRefresh: c.loadVolunteerDesk,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 80),
                  Icon(
                    Icons.event_busy,
                    size: 48,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    c.deskError!,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }
          return _deskTabs(context);
        },
      );
    }
    return _deskTabs(context);
  }

  Widget _deskTabs(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: const TabBar(
              tabs: [
                Tab(text: "Check out"),
                Tab(text: "Check in"),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _CheckOutTab(
                  onCheckOutReservations: _checkOutReservations,
                  onOpenToy: _openToy,
                  onRefresh: () =>
                      context.read<LoansController>().loadVolunteerDesk(),
                ),
                _CheckInTab(
                  onCheckIn: _checkIn,
                  onOpenToy: _openToy,
                  onToyIdScanned: _handleScannedToyId,
                  onRefresh: () =>
                      context.read<LoansController>().loadVolunteerDesk(),
                  enableToyIdScan: !widget.volunteerDeskMode,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckOutTab extends StatefulWidget {
  const _CheckOutTab({
    required this.onCheckOutReservations,
    required this.onOpenToy,
    required this.onRefresh,
  });

  final Future<void> Function(List<BookingItem> bookings)
      onCheckOutReservations;
  final ValueChanged<String> onOpenToy;
  final Future<void> Function() onRefresh;

  @override
  State<_CheckOutTab> createState() => _CheckOutTabState();
}

class _CheckOutTabState extends State<_CheckOutTab> {
  bool _walkInDraft = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<LoansController>(
      builder: (context, c, _) {
        if (c.deskLoading && c.pendingCheckouts.isEmpty) {
          return const Center(child: ToyLibraryLoadingIndicator());
        }

        final today = deskTodayReservations(c.pendingCheckouts);
        final earlier = deskEarlierReady(c.pendingCheckouts);

        return RefreshIndicator(
          onRefresh: widget.onRefresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                sliver: SliverToBoxAdapter(
                  child: DeskWalkInPanel(
                    loading: c.deskLoading,
                    allowEarlyReservationCheckout: true,
                    onDraftChanged: (active) {
                      if (_walkInDraft != active) {
                        setState(() => _walkInDraft = active);
                      }
                    },
                    onCheckedOut: () {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Walk-in toy checked out")),
                      );
                    },
                    onCheckOutReservations: widget.onCheckOutReservations,
                    onOpenToy: widget.onOpenToy,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              if (today.isEmpty && earlier.isEmpty && !_walkInDraft) ...[
                const SliverToBoxAdapter(
                  child: Center(
                    child: Text(
                      "No reservations ready for checkout.",
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],
              if (today.isNotEmpty) ...[
                const SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  sliver: SliverToBoxAdapter(
                    child: SectionHeader("Today's reservations"),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  sliver: SliverList.separated(
                    itemCount: today.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => _CheckoutTile(
                      key: ValueKey(today[i].bookingId),
                      booking: today[i],
                      loading: c.deskLoading,
                      onOpen: () => widget.onOpenToy(today[i].toyId),
                      onCheckOut: () =>
                          widget.onCheckOutReservations([today[i]]),
                    ),
                  ),
                ),
              ],
              if (today.isNotEmpty && earlier.isNotEmpty)
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
              if (earlier.isNotEmpty) ...[
                const SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  sliver: SliverToBoxAdapter(
                    child: SectionHeader("Ready for checkout"),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  sliver: SliverList.separated(
                    itemCount: earlier.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => _CheckoutTile(
                      key: ValueKey(earlier[i].bookingId),
                      booking: earlier[i],
                      loading: c.deskLoading,
                      onOpen: () => widget.onOpenToy(earlier[i].toyId),
                      onCheckOut: () =>
                          widget.onCheckOutReservations([earlier[i]]),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _CheckInTab extends StatefulWidget {
  const _CheckInTab({
    required this.onCheckIn,
    required this.onOpenToy,
    required this.onToyIdScanned,
    required this.onRefresh,
    this.enableToyIdScan = true,
    this.filterMemberUserId,
    this.filterDueDate,
  });

  final Future<void> Function(LoanItem loan) onCheckIn;
  final ValueChanged<String> onOpenToy;
  final Future<void> Function(String toyId) onToyIdScanned;
  final Future<void> Function() onRefresh;
  final bool enableToyIdScan;
  final String? filterMemberUserId;
  final DateTime? filterDueDate;

  @override
  State<_CheckInTab> createState() => _CheckInTabState();
}

class _CheckInTabState extends State<_CheckInTab> {
  final TextEditingController _searchController = TextEditingController();
  String _query = "";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<LoanItem> _filtered(List<LoanItem> loans) {
    return filterCheckInLoans(
      loans,
      query: _query,
      memberUserId: widget.filterMemberUserId,
      dueDate: widget.filterDueDate,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LoansController>(
      builder: (context, c, _) {
        if (c.deskLoading && c.activeLoans.isEmpty) {
          return const Center(child: ToyLibraryLoadingIndicator());
        }

        final all = c.activeLoans;
        final filtered = _filtered(all);
        final hasDeskFilters = widget.filterMemberUserId != null ||
            widget.filterDueDate != null;

        return RefreshIndicator(
          onRefresh: widget.onRefresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (kDeskToyIdScanEnabled && widget.enableToyIdScan) ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  sliver: SliverToBoxAdapter(
                    child: AdminCvScanPanel(
                      onToyIdScanned: widget.onToyIdScanned,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],
              if (all.isNotEmpty && !hasDeskFilters)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  sliver: SliverToBoxAdapter(
                    child: TextField(
                      controller: _searchController,
                      style: fieldTextStyle(context),
                      cursorColor: fieldCursorColor(context),
                      textInputAction: TextInputAction.search,
                      decoration: searchInputDecoration(
                        context,
                        hintText: "Search by member, toy or ID",
                        suffixIcon: searchClearSuffix(
                          context,
                          visible: _query.isNotEmpty,
                          onClear: () {
                            _searchController.clear();
                            setState(() => _query = "");
                          },
                        ),
                      ),
                      onChanged: (value) => setState(() => _query = value),
                    ),
                  ),
                ),
              if (all.isNotEmpty && !hasDeskFilters)
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
              if (all.isEmpty)
                SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        c.deskError ??
                            (c.deskLoading
                                ? "Loading loans…"
                                : "No toys currently on loan."),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                )
              else if (filtered.isEmpty)
                SliverToBoxAdapter(
                  child: Center(
                    child: Text(
                      hasDeskFilters
                          ? "No toys on loan for this member on this due date."
                          : 'No toys match "${_query.trim()}".',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else ...[
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
                  sliver: SliverToBoxAdapter(child: SectionHeader("On loan")),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  sliver: SliverList.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => _CheckInTile(
                      key: ValueKey(filtered[i].loanId),
                      loan: filtered[i],
                      loading: c.deskLoading,
                      onOpen: () => widget.onOpenToy(filtered[i].toyId),
                      onCheckIn: () => widget.onCheckIn(filtered[i]),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _CheckoutTile extends StatelessWidget {
  const _CheckoutTile({
    super.key,
    required this.booking,
    required this.loading,
    required this.onOpen,
    required this.onCheckOut,
  });

  final BookingItem booking;
  final bool loading;
  final VoidCallback onOpen;
  final VoidCallback onCheckOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      color: colors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: InkWell(
                onTap: onOpen,
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ToyPhotoTile(toyId: booking.toyId),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            booking.toyName ?? booking.toyId,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.cardTitle,
                          ),
                          if (booking.toyId.trim().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              booking.toyId,
                              style: context.listSubtitle,
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            booking.deskSubtitle,
                            style: context.listSubtitle,
                          ),
                          if (booking.pickupLabel != null &&
                              booking.pickupLabel!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              booking.pickupLabel!,
                              style: context.listSubtitle,
                            ),
                          ],
                          if (booking.rentalPriceLabel != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              "Hire ${booking.rentalPriceLabel}",
                              style: context.listSubtitle,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            BrandChipButton(
              label: "Check out",
              fixedWidth: 100,
              onPressed: loading ? null : onCheckOut,
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckInTile extends StatelessWidget {
  const _CheckInTile({
    super.key,
    required this.loan,
    required this.loading,
    required this.onOpen,
    required this.onCheckIn,
  });

  final LoanItem loan;
  final bool loading;
  final VoidCallback onOpen;
  final VoidCallback onCheckIn;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: LoanDeskSummary(loan: loan, photoSize: 80),
              ),
              const SizedBox(width: 8),
              BrandChipButton(
                label: "Check in",
                fixedWidth: 100,
                onPressed: loading ? null : onCheckIn,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
