import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../core/app_text_styles.dart";
import "../../core/section_header.dart";
import "../../core/brand_chip_button.dart";
import "../bookings/booking_models.dart";
import "../catalog/catalog_provider.dart";
import "../catalog/toy_detail_screen.dart";
import "../catalog/toy_photo_tile.dart";
import "desk_check_in_dialog.dart";
import "desk_checkout_dialog.dart";
import "desk_walk_in_panel.dart";
import "loan_desk_summary.dart";
import "loan_models.dart";
import "loans_controller.dart";

/// Volunteer checkout desk: reservations, walk-ins, and check-ins.
class VolunteerDeskScreen extends StatefulWidget {
  const VolunteerDeskScreen({super.key});

  @override
  State<VolunteerDeskScreen> createState() => _VolunteerDeskScreenState();
}

class _VolunteerDeskScreenState extends State<VolunteerDeskScreen> {
  bool _walkInDraft = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<LoansController>().loadVolunteerDesk();
    });
  }

  Future<void> _checkOut(BookingItem booking) async {
    final result = await showDeskCheckoutDialog(
      context,
      memberLabel: booking.memberLabel,
      memberUserId: booking.userId,
      lines: [
        DeskCheckoutLine(
          toyId: booking.toyId,
          toyName: booking.toyName ?? booking.toyId,
          rentalPriceCents: booking.rentalPriceCents,
        ),
      ],
    );
    if (result == null || !mounted) return;

    final controller = context.read<LoansController>();
    final catalog = context.read<CatalogController>();
    try {
      await controller.checkOutFromBooking(
        booking.bookingId,
        rentalPayment: result.rentalPayment,
        paymentMethod: result.paymentMethod,
      );
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
      rethrow;
    }
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
        SnackBar(
          content: Text("Checked in ${loan.toyName ?? loan.toyId}"),
        ),
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

  Future<void> _walkInCheckedOut() async {
    final catalog = context.read<CatalogController>();
    final messenger = ScaffoldMessenger.of(context);
    await catalog.refresh();
    if (!mounted) return;
    messenger.showSnackBar(
      const SnackBar(content: Text("Walk-in toy checked out")),
    );
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
    return Consumer<LoansController>(
      builder: (context, c, _) {
        if (c.deskLoading &&
            c.pendingCheckouts.isEmpty &&
            c.activeLoans.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

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

        final today = deskTodayReservations(c.pendingCheckouts);
        final earlier = deskEarlierReady(c.pendingCheckouts);
        final empty = today.isEmpty &&
            earlier.isEmpty &&
            c.activeLoans.isEmpty &&
            !_walkInDraft;

        return RefreshIndicator(
          onRefresh: c.loadVolunteerDesk,
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
                onCheckedOut: _walkInCheckedOut,
                onCheckOutReservation: _checkOut,
                onOpenToy: _openToy,
              ),
              const SizedBox(height: 16),
              if (empty) ...[
                const Center(
                  child: Text(
                    "No reservations or loans on the desk right now.",
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (today.isNotEmpty) ...[
                const SectionHeader("Today's reservations"),
                for (var i = 0; i < today.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _PendingCheckoutTile(
                    booking: today[i],
                    loading: c.deskLoading,
                    onOpen: () => _openToy(today[i].toyId),
                    onCheckOut: () => _checkOut(today[i]),
                  ),
                ],
              ],
              if (today.isNotEmpty && earlier.isNotEmpty)
                const SizedBox(height: 20),
              if (earlier.isNotEmpty) ...[
                const SectionHeader("Ready for checkout"),
                for (var i = 0; i < earlier.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _PendingCheckoutTile(
                    booking: earlier[i],
                    loading: c.deskLoading,
                    onOpen: () => _openToy(earlier[i].toyId),
                    onCheckOut: () => _checkOut(earlier[i]),
                  ),
                ],
              ],
              if ((today.isNotEmpty || earlier.isNotEmpty) &&
                  c.activeLoans.isNotEmpty)
                const SizedBox(height: 20),
              if (c.activeLoans.isNotEmpty) ...[
                const SectionHeader("On loan"),
                for (var i = 0; i < c.activeLoans.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _ActiveLoanDeskTile(
                    loan: c.activeLoans[i],
                    loading: c.deskLoading,
                    onOpen: () => _openToy(c.activeLoans[i].toyId),
                    onCheckIn: () => _checkIn(c.activeLoans[i]),
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
    final colors = Theme.of(context).colorScheme;

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
                    ToyPhotoTile(
                      toyId: booking.toyId,
                      photoFile: booking.photoFile,
                      size: 80,
                    ),
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
                child: LoanDeskSummary(
                  loan: loan,
                  showToyId: false,
                  showPieces: true,
                  showMemberAndDue: true,
                  photoSize: 80,
                ),
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
