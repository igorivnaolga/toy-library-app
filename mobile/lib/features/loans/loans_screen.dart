import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../core/app_theme.dart";
import "../../core/auth_store.dart";
import "../../core/brand_chip_button.dart";
import "../bookings/booking_models.dart";
import "../catalog/catalog_provider.dart";
import "../catalog/toy_photo_tile.dart";
import "../catalog/toy_detail_screen.dart";
import "loan_list_tile.dart";
import "loan_models.dart";
import "loans_controller.dart";

/// Member loans list and volunteer checkout desk.
class LoansScreen extends StatefulWidget {
  const LoansScreen({super.key});

  @override
  State<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends State<LoansScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadForRole(context.read<AuthStore>().role);
    });
  }

  void _loadForRole(AppRole role) {
    final controller = context.read<LoansController>();
    if (_canManageDesk(role)) {
      controller.loadVolunteerDesk();
    }
    if (_canViewMyLoans(role)) {
      controller.loadMyLoans();
    }
  }

  bool _canManageDesk(AppRole role) =>
      role == AppRole.volunteer || role == AppRole.admin;

  bool _canViewMyLoans(AppRole role) =>
      role == AppRole.member ||
      role == AppRole.volunteer ||
      role == AppRole.admin;

  Future<void> _renew(LoanItem item) async {
    final controller = context.read<LoansController>();
    try {
      final updated = await controller.renewLoan(item.loanId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Renewed ${updated.toyName ?? updated.toyId} until ${formatDisplayDate(updated.dueDate)}",
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loanActionErrorMessage(e))),
      );
    }
  }

  Future<void> _checkOut(BookingItem booking) async {
    final controller = context.read<LoansController>();
    final catalog = context.read<CatalogController>();
    try {
      await controller.checkOutFromBooking(booking.bookingId);
      await catalog.refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Checked out ${booking.toyName ?? booking.toyId}",
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loanActionErrorMessage(e))),
      );
    }
  }

  Future<void> _checkIn(LoanItem loan) async {
    final controller = context.read<LoansController>();
    final catalog = context.read<CatalogController>();
    try {
      await controller.checkIn(loan.loanId);
      await catalog.refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Checked in ${loan.toyName ?? loan.toyId}"),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
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
    final auth = context.watch<AuthStore>();

    if (!auth.isLoggedIn) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            "Sign in to view your loans or use the volunteer desk.",
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (!_canViewMyLoans(auth.role)) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            "Complete membership setup to borrow toys from the library.",
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_canManageDesk(auth.role)) {
      return DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Material(
              color: Theme.of(context).colorScheme.surface,
              child: const TabBar(
                tabs: [
                  Tab(text: "Desk"),
                  Tab(text: "My loans"),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _VolunteerDeskView(
                    onCheckOut: _checkOut,
                    onCheckIn: _checkIn,
                    onOpenToy: _openToy,
                    onRefresh: () =>
                        context.read<LoansController>().loadVolunteerDesk(),
                  ),
                  _MyLoansView(
                    onRenew: _renew,
                    onOpenToy: _openToy,
                    onRefresh: () =>
                        context.read<LoansController>().loadMyLoans(),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return _MyLoansView(
      onRenew: _renew,
      onOpenToy: _openToy,
      onRefresh: () => context.read<LoansController>().loadMyLoans(),
    );
  }
}

class _MyLoansView extends StatelessWidget {
  const _MyLoansView({
    required this.onRenew,
    required this.onOpenToy,
    required this.onRefresh,
  });

  final Future<void> Function(LoanItem item) onRenew;
  final ValueChanged<String> onOpenToy;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Consumer<LoansController>(
      builder: (context, c, _) {
        if (c.myLoansLoading && c.myLoans.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (c.myLoansError != null && c.myLoans.isEmpty) {
          return _ErrorState(
            message: c.myLoansError!,
            loading: c.myLoansLoading,
            onRetry: onRefresh,
          );
        }
        if (c.myLoans.isEmpty) {
          return RefreshIndicator(
            onRefresh: onRefresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                Center(
                  child: Text(
                    "No loans yet.\nPick up a booking or borrow a toy at the desk.",
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        }

        final sections = groupLoansBySection(c.myLoans);

        return RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            children: [
              if (sections.active.isNotEmpty) ...[
                const _LoansSectionHeader(title: "Active"),
                for (var i = 0; i < sections.active.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  LoanListTile(
                    item: sections.active[i],
                    loading: c.myLoansLoading,
                    onOpen: () => onOpenToy(sections.active[i].toyId),
                    onRenew: sections.active[i].canRenew
                        ? () => onRenew(sections.active[i])
                        : null,
                  ),
                ],
              ],
              if (sections.active.isNotEmpty && sections.returned.isNotEmpty)
                const SizedBox(height: 20),
              if (sections.returned.isNotEmpty) ...[
                const _LoansSectionHeader(title: "Returned"),
                for (var i = 0; i < sections.returned.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  LoanListTile(
                    item: sections.returned[i],
                    loading: c.myLoansLoading,
                    onOpen: () => onOpenToy(sections.returned[i].toyId),
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}

class _VolunteerDeskView extends StatelessWidget {
  const _VolunteerDeskView({
    required this.onCheckOut,
    required this.onCheckIn,
    required this.onOpenToy,
    required this.onRefresh,
  });

  final Future<void> Function(BookingItem booking) onCheckOut;
  final Future<void> Function(LoanItem loan) onCheckIn;
  final ValueChanged<String> onOpenToy;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Consumer<LoansController>(
      builder: (context, c, _) {
        if (c.deskLoading &&
            c.pendingCheckouts.isEmpty &&
            c.activeLoans.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (c.deskError != null &&
            c.pendingCheckouts.isEmpty &&
            c.activeLoans.isEmpty) {
          return _ErrorState(
            message: c.deskError!,
            loading: c.deskLoading,
            onRetry: onRefresh,
          );
        }

        final empty = c.pendingCheckouts.isEmpty && c.activeLoans.isEmpty;

        return RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            children: [
              if (empty) ...[
                const SizedBox(height: 80),
                const Center(
                  child: Text(
                    "Nothing on the desk right now.\nPull down to refresh.",
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              if (c.pendingCheckouts.isNotEmpty) ...[
                const _LoansSectionHeader(title: "Ready for checkout"),
                for (var i = 0; i < c.pendingCheckouts.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _PendingCheckoutTile(
                    booking: c.pendingCheckouts[i],
                    loading: c.deskLoading,
                    onOpen: () => onOpenToy(c.pendingCheckouts[i].toyId),
                    onCheckOut: () => onCheckOut(c.pendingCheckouts[i]),
                  ),
                ],
              ],
              if (c.pendingCheckouts.isNotEmpty && c.activeLoans.isNotEmpty)
                const SizedBox(height: 20),
              if (c.activeLoans.isNotEmpty) ...[
                const _LoansSectionHeader(title: "On loan"),
                for (var i = 0; i < c.activeLoans.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _ActiveLoanDeskTile(
                    loan: c.activeLoans[i],
                    loading: c.deskLoading,
                    onOpen: () => onOpenToy(c.activeLoans[i].toyId),
                    onCheckIn: () => onCheckIn(c.activeLoans[i]),
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}

class _PendingCheckoutTile extends StatelessWidget {
  const _PendingCheckoutTile({
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
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(12),
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
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: kBrandOnYellow,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      booking.listSubtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurface.withValues(alpha: 0.62),
                      ),
                    ),
                  ],
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
      ),
    );
  }
}

class _ActiveLoanDeskTile extends StatelessWidget {
  const _ActiveLoanDeskTile({
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

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
              ToyPhotoTile(toyId: loan.toyId),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loan.toyName ?? loan.toyId,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: kBrandOnYellow,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      loan.listSubtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: loan.isOverdue
                            ? colors.error
                            : colors.onSurface.withValues(alpha: 0.62),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              BrandChipButton(
                label: "Check in",
                variant: BrandChipButtonVariant.outlined,
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

class _LoansSectionHeader extends StatelessWidget {
  const _LoansSectionHeader({required this.title});

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

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.loading,
    required this.onRetry,
  });

  final String message;
  final bool loading;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: loading ? null : onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text("Retry"),
            ),
          ],
        ),
      ),
    );
  }
}
