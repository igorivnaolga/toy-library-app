import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../core/app_input_field.dart";
import "../../core/app_text_styles.dart";
import "../../core/section_header.dart";
import "../../core/brand_chip_button.dart";
import "../bookings/booking_models.dart";
import "../catalog/catalog_provider.dart";
import "../catalog/toy_detail_screen.dart";
import "../catalog/toy_photo_tile.dart";
import "../loans/desk_check_in_dialog.dart";
import "../loans/desk_walk_in_panel.dart";
import "../loans/loan_desk_summary.dart";
import "../loans/loan_models.dart";
import "../loans/loans_controller.dart";
import "admin_cv_scan_panel.dart";

/// Admin desk: separate check-out and check-in flows (CV-ready check-in).
class AdminLoansScreen extends StatefulWidget {
  const AdminLoansScreen({super.key});

  @override
  State<AdminLoansScreen> createState() => _AdminLoansScreenState();
}

class _AdminLoansScreenState extends State<AdminLoansScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LoansController>().loadVolunteerDesk();
    });
  }

  Future<void> _checkOut(BookingItem booking) async {
    final controller = context.read<LoansController>();
    final catalog = context.read<CatalogController>();
    try {
      await controller.checkOutFromBooking(booking.bookingId);
      await catalog.refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Checked out ${booking.toyName ?? booking.toyId}")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loanActionErrorMessage(e))),
      );
    }
  }

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
    try {
      await controller.checkIn(
        loan.loanId,
        missingPieces: result.missingPieces,
      );
      await catalog.refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Checked in ${loan.toyName ?? loan.toyId}")),
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
                  onCheckOut: _checkOut,
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
    required this.onCheckOut,
    required this.onOpenToy,
    required this.onRefresh,
  });

  final Future<void> Function(BookingItem booking) onCheckOut;
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
          return const Center(child: CircularProgressIndicator());
        }

        final today = deskTodayReservations(c.pendingCheckouts);
        final earlier = deskEarlierReady(c.pendingCheckouts);

        return RefreshIndicator(
          onRefresh: widget.onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            children: [
              DeskWalkInPanel(
                loading: c.deskLoading,
                onDraftChanged: (active) {
                  if (_walkInDraft != active) {
                    setState(() => _walkInDraft = active);
                  }
                },
                onCheckedOut: () async {
                  await context.read<CatalogController>().refresh();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Walk-in toy checked out")),
                  );
                },
              ),
              const SizedBox(height: 16),
              if (today.isEmpty && earlier.isEmpty && !_walkInDraft) ...[
                const Center(
                  child: Text(
                    "No reservations ready for checkout.",
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (today.isNotEmpty) ...[
                const SectionHeader("Today's reservations"),
                for (var i = 0; i < today.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _CheckoutTile(
                    booking: today[i],
                    loading: c.deskLoading,
                    onOpen: () => widget.onOpenToy(today[i].toyId),
                    onCheckOut: () => widget.onCheckOut(today[i]),
                  ),
                ],
              ],
              if (today.isNotEmpty && earlier.isNotEmpty)
                const SizedBox(height: 20),
              if (earlier.isNotEmpty) ...[
                const SectionHeader("Ready for checkout"),
                for (var i = 0; i < earlier.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _CheckoutTile(
                    booking: earlier[i],
                    loading: c.deskLoading,
                    onOpen: () => widget.onOpenToy(earlier[i].toyId),
                    onCheckOut: () => widget.onCheckOut(earlier[i]),
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

class _CheckInTab extends StatefulWidget {
  const _CheckInTab({
    required this.onCheckIn,
    required this.onOpenToy,
    required this.onToyIdScanned,
    required this.onRefresh,
  });

  final Future<void> Function(LoanItem loan) onCheckIn;
  final ValueChanged<String> onOpenToy;
  final Future<void> Function(String toyId) onToyIdScanned;
  final Future<void> Function() onRefresh;

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
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return loans;
    return loans.where((loan) {
      final name = (loan.toyName ?? "").toLowerCase();
      return loan.toyId.toLowerCase().contains(q) || name.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LoansController>(
      builder: (context, c, _) {
        if (c.deskLoading && c.activeLoans.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final all = c.activeLoans;
        final filtered = _filtered(all);

        return RefreshIndicator(
          onRefresh: widget.onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            children: [
              AdminCvScanPanel(onToyIdScanned: widget.onToyIdScanned),
              const SizedBox(height: 16),
              if (all.isNotEmpty) ...[
                TextField(
                  controller: _searchController,
                  style: fieldTextStyle(context),
                  cursorColor: fieldCursorColor(context),
                  textInputAction: TextInputAction.search,
                  decoration: searchInputDecoration(
                    context,
                    hintText: "Search by toy name or ID",
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
              if (all.isEmpty)
                const Center(
                  child: Text(
                    "No toys currently on loan.",
                    textAlign: TextAlign.center,
                  ),
                )
              else if (filtered.isEmpty)
                Center(
                  child: Text(
                    'No toys match "${_query.trim()}".',
                    textAlign: TextAlign.center,
                  ),
                )
              else ...[
                const SectionHeader("On loan"),
                for (var i = 0; i < filtered.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _CheckInTile(
                    loan: filtered[i],
                    loading: c.deskLoading,
                    onOpen: () => widget.onOpenToy(filtered[i].toyId),
                    onCheckIn: () => widget.onCheckIn(filtered[i]),
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

class _CheckoutTile extends StatelessWidget {
  const _CheckoutTile({
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
                      style: context.cardTitle,
                    ),
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

class _CheckInTile extends StatelessWidget {
  const _CheckInTile({
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
