import "dart:ui";

import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../core/toy_loading_indicator.dart";
import "../../core/api_exception.dart";
import "../../core/user_friendly_error.dart";
import "../../core/app_text_styles.dart";
import "../../core/auth_store.dart";
import "../../core/toy_photo_url.dart";
import "../../core/toy_pieces.dart";
import "../auth/login_screen.dart";
import "../membership/membership_onboarding_screen.dart";
import "../bookings/booking_confirmed_dialog.dart";
import "../bookings/booking_models.dart";
import "../bookings/bookings_controller.dart";
import "../bookings/pickup_date_flow.dart";
import "../duty/duty_controller.dart";
import "../loans/loan_models.dart";
import "../loans/loans_controller.dart";
import "catalog_models.dart";
import "catalog_provider.dart";
import "toy_edit_sheet.dart";
import "toy_label_pdf.dart";
import "toy_availability_badge.dart";
import "toy_id_badge.dart";
import "toy_detail_action_bar.dart";
import "toy_detail_pieces_section.dart";
import "toy_detail_section.dart";
import "toy_photo_placeholder.dart";

/// Lightweight catalog row for instant detail navigation before fetch completes.
ToyItem previewToyItem({
  required String toyId,
  String? name,
  String? photoFile,
  String availability = "unknown",
  int? totalPieces,
  int? missingPieces,
}) {
  return ToyItem.preview(
    toyId: toyId,
    name: name,
    photoFile: photoFile,
    availability: availability,
    totalPieces: totalPieces,
    missingPieces: missingPieces,
  );
}

/// Loads a single toy from `GET /api/v1/toys/{toy_id}`.
class ToyDetailScreen extends StatefulWidget {
  const ToyDetailScreen({
    super.key,
    required this.toyId,
    this.initialToy,
  });

  final String toyId;
  final ToyItem? initialToy;

  @override
  State<ToyDetailScreen> createState() => _ToyDetailScreenState();
}

class _ToyDetailScreenState extends State<ToyDetailScreen> {
  Future<ToyItem>? _future;
  ToyItem? _previewToy;
  bool _started = false;
  bool _sideEffectsStarted = false;
  bool _bookingInProgress = false;
  bool _cancellingInProgress = false;
  bool _reschedulingInProgress = false;
  bool _onDutyRequested = false;

  ToyItem? _resolvePreviewToy() {
    return widget.initialToy ??
        context.read<CatalogController>().cachedToy(widget.toyId);
  }

  void _scheduleMemberContextLoads() {
    if (_sideEffectsStarted) return;
    _sideEffectsStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthStore>();
      if (auth.canBookToys) {
        context.read<BookingsController>().loadBookings();
        context.read<LoansController>().loadMyLoans(activeOnly: true);
      }
      if (!_onDutyRequested && auth.isVolunteer && !auth.isAdmin) {
        _onDutyRequested = true;
        context.read<DutyController>().refreshOnDutyStatus();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _previewToy ??= _resolvePreviewToy();
    _scheduleMemberContextLoads();
    if (_started) return;
    _started = true;
    setState(() {
      _future = context.read<CatalogController>().fetchToy(widget.toyId);
    });
  }

  void _retry() {
    setState(() {
      _previewToy ??= _resolvePreviewToy();
      _future = context.read<CatalogController>().fetchToy(widget.toyId);
    });
  }

  Future<void> _startBookFlow(ToyItem toy) async {
    final bookings = context.read<BookingsController>();
    final selected = await choosePickupDate(context, bookings, toyId: toy.toyId);
    if (selected == null || !mounted) return;

    setState(() => _bookingInProgress = true);
    final catalog = context.read<CatalogController>();
    try {
      await bookings.createBooking(toy.toyId, selected.date);
      await catalog.updateToyInCatalog(toy.toyId);
      _retry();
      if (!mounted) return;
      await showBookingConfirmedDialog(
        context,
        toyName: toy.name,
        pickupLabel: selected.label,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(bookingActionErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _bookingInProgress = false);
    }
  }

  Future<void> _changePickupDate(BookingItem booking, ToyItem toy) async {
    final bookings = context.read<BookingsController>();
    final selected = await choosePickupDate(
      context,
      bookings,
      title: "Change pickup day",
      toyId: toy.toyId,
    );
    if (selected == null || !mounted) return;

    setState(() => _reschedulingInProgress = true);
    try {
      await bookings.rescheduleBooking(booking.bookingId, selected.date);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Pickup updated to ${selected.label}")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(bookingActionErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _reschedulingInProgress = false);
    }
  }

  Future<void> _cancelBooking(BookingItem booking, ToyItem toy) async {
    setState(() => _cancellingInProgress = true);
    final bookings = context.read<BookingsController>();
    final catalog = context.read<CatalogController>();
    try {
      await bookings.cancelBooking(booking.bookingId);
      await catalog.updateToyInCatalog(toy.toyId);
      _retry();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Cancelled booking for ${toy.name}")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(bookingActionErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _cancellingInProgress = false);
    }
  }

  void _signInToBook() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
    );
  }

  void _chooseMembershipToBook() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const MembershipOnboardingScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();

    return FutureBuilder<ToyItem>(
      future: _future,
      builder: (context, snapshot) {
        final preview = _previewToy ?? widget.initialToy;
        final hasFullData = snapshot.hasData;
        final ToyItem? t = hasFullData ? snapshot.data : preview;
        final loadingDetail =
            snapshot.connectionState == ConnectionState.waiting && t != null;

        if (t == null) {
          if (snapshot.hasError) {
            final err = snapshot.error;
            final message = err is ApiException ? err.message : err.toString();
            return Scaffold(
              appBar: AppBar(title: const Text("Toy details")),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(message, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _retry,
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          return Scaffold(
            appBar: AppBar(title: const Text("Toy details")),
            body: const Center(child: ToyLibraryLoadingIndicator()),
          );
        }
        final theme = Theme.of(context);
        final colors = theme.colorScheme;
        final photoCacheSize =
            (200 * MediaQuery.of(context).devicePixelRatio).round();
        final hasPhotoName = t.photoFile != null && t.photoFile!.isNotEmpty;
        final description = t.description?.trim().isNotEmpty == true
            ? t.description!.trim()
            : null;
        final showPieceBreakdown = auth.isAdmin || auth.isVolunteer;

        return Scaffold(
          appBar: AppBar(
            title: const Text("Toy details"),
            actions: [
              if (auth.isAdmin) ...[
                IconButton(
                  tooltip: "Shelf label PDF",
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  onPressed: () async {
                    try {
                      await shareToyLabelPdf(t);
                    } catch (e) {
                      if (!context.mounted) return;
                      final message = friendlyErrorMessage(
                        e,
                        fallback: "Couldn't create the shelf label PDF.",
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(message)),
                      );
                    }
                  },
                ),
                IconButton(
                  tooltip: "Edit toy",
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () async {
                    final result = await showToyEditSheet(context, toy: t);
                    if (!context.mounted) return;
                    if (result is ToyFormDeleted) {
                      final catalog = context.read<CatalogController>();
                      final messenger = ScaffoldMessenger.of(context);
                      final deleted = result;
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      await catalog.refresh();
                      messenger
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          SnackBar(
                            content: Text(
                              'Toy "${deleted.toyName}" (${deleted.toyId}) deleted.',
                            ),
                            duration: const Duration(seconds: 4),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      return;
                    }
                    if (result is ToyFormSaved) {
                      await context.read<CatalogController>().refresh();
                      _retry();
                    }
                  },
                ),
              ],
            ],
          ),
          bottomNavigationBar: auth.isAdmin || loadingDetail
              ? null
              : _ToyDetailMemberBar(
                  toy: t,
                  bookingInProgress: _bookingInProgress,
                  cancellingInProgress: _cancellingInProgress,
                  reschedulingInProgress: _reschedulingInProgress,
                  onSignIn: _signInToBook,
                  onChooseMembership: _chooseMembershipToBook,
                  onBook: () => _startBookFlow(t),
                  onChangePickupDate: (booking) => _changePickupDate(booking, t),
                  onCancelBooking: (booking) => _cancelBooking(booking, t),
                ),
          body: Stack(
            fit: StackFit.expand,
            children: [
              ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ToyDetailSectionCard(
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 200,
                      height: 200,
                      child: hasPhotoName
                          ? Image.network(
                              toyPhotoUrl(t.toyId, photoFile: t.photoFile)!,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.medium,
                              cacheWidth: photoCacheSize,
                              cacheHeight: photoCacheSize,
                              errorBuilder: (_, __, ___) => ToyPhotoPlaceholder(
                                expand: true,
                                borderRadius: 12,
                              ),
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) {
                                  return child;
                                }
                                return const Center(
                                  child: ToyLibraryLoadingIndicator.compact(),
                                );
                              },
                            )
                          : ToyPhotoPlaceholder(
                              expand: true,
                              borderRadius: 12,
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ToyDetailSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.name,
                      style: context.detailTitle,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ToyIdBadge(toyId: t.toyId, compact: false),
                        Selector<LoansController, bool>(
                          selector: (_, controller) =>
                              t.availability == "on_loan" &&
                              controller.activeLoanForToy(t.toyId) != null,
                          builder: (context, isMyLoan, _) =>
                              ToyAvailabilityBadge(
                            availability: t.availability,
                            isMyLoan: isMyLoan,
                          ),
                        ),
                      ],
                    ),
                    if (t.category != null ||
                        t.ageRange != null ||
                        hasToyPiecesInfo(
                          totalPieces: t.totalPieces,
                          missingPieces: t.missingPieces,
                        ) ||
                        t.rentalPriceLabel != null ||
                        (t.manufacturer != null &&
                            t.manufacturer!.isNotEmpty)) ...[
                      const SizedBox(height: 16),
                      Divider(
                        height: 1,
                        color: colors.outlineVariant.withValues(alpha: 0.45),
                      ),
                      const SizedBox(height: 12),
                      if (t.category != null)
                        ToyDetailMetaRow(label: "Category", value: t.category!),
                      if (t.ageRange != null)
                        ToyDetailMetaRow(label: "Age range", value: t.ageRange!),
                      if (hasToyPiecesInfo(
                            totalPieces: t.totalPieces,
                            missingPieces: t.missingPieces,
                          ))
                        ToyDetailMetaRow(
                          label: "Pieces",
                          value: t.piecesSummary.isNotEmpty
                              ? t.piecesSummary
                              : "Not recorded",
                        ),
                      if ((auth.isAdmin || auth.isVolunteer) &&
                          t.missingPiecesDetail != null &&
                          t.missingPiecesDetail!.trim().isNotEmpty)
                        ToyDetailMetaRow(
                          label: "Missing pieces",
                          value: t.missingPiecesDetail!.trim(),
                        ),
                      if (t.rentalPriceLabel != null)
                        ToyDetailMetaRow(
                          label: "Rental price",
                          value: t.rentalPriceLabel!,
                        ),
                      if (t.manufacturer != null && t.manufacturer!.isNotEmpty)
                        ToyDetailMetaRow(
                          label: "Manufacturer",
                          value: t.manufacturer!,
                        ),
                    ],
                  ],
                ),
              ),
              if (showPieceBreakdown && !(loadingDetail && !hasFullData)) ...[
                const SizedBox(height: 12),
                Selector<DutyController, bool>(
                  selector: (_, controller) => controller.onDutyStatus.onDuty,
                  builder: (context, onDuty, _) {
                    final canEdit =
                        auth.isAdmin || (auth.isVolunteer && onDuty);
                    return ToyDetailPiecesSection(
                      toyId: t.toyId,
                      pieceLines: t.pieceLines,
                      totalPieces: t.totalPieces,
                      missingPieces: t.missingPieces,
                      canEdit: canEdit,
                      onSaved: _retry,
                    );
                  },
                ),
              ],
              if (auth.isAdmin &&
                  t.hasAdminHolderInfo &&
                  !(loadingDetail && !hasFullData)) ...[
                const SizedBox(height: 12),
                ToyDetailSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const ToyDetailSectionTitle(title: "Member"),
                      const SizedBox(height: 8),
                      if (t.onLoanToName != null &&
                          t.onLoanToName!.isNotEmpty) ...[
                        ToyDetailMetaRow(
                          label: "On loan to",
                          value: t.onLoanToName!,
                        ),
                        if (t.onLoanToEmail != null &&
                            t.onLoanToEmail!.isNotEmpty &&
                            t.onLoanToEmail != t.onLoanToName)
                          ToyDetailMetaRow(
                            label: "Email",
                            value: t.onLoanToEmail!,
                          ),
                        if (t.loanDueLabel != null &&
                            t.loanDueLabel!.isNotEmpty)
                          ToyDetailMetaRow(
                            label: "Due back",
                            value: t.loanDueLabel!,
                          ),
                      ],
                      if (t.reservedByName != null &&
                          t.reservedByName!.isNotEmpty) ...[
                        if (t.onLoanToName != null &&
                            t.onLoanToName!.isNotEmpty)
                          const SizedBox(height: 12),
                        ToyDetailMetaRow(
                          label: "Reserved by",
                          value: t.reservedByName!,
                        ),
                        if (t.reservedByEmail != null &&
                            t.reservedByEmail!.isNotEmpty &&
                            t.reservedByEmail != t.reservedByName)
                          ToyDetailMetaRow(
                            label: "Email",
                            value: t.reservedByEmail!,
                          ),
                        if (t.reservationPickupLabel != null &&
                            t.reservationPickupLabel!.isNotEmpty)
                          ToyDetailMetaRow(
                            label: "Pickup",
                            value: t.reservationPickupLabel!,
                          ),
                      ],
                    ],
                  ),
                ),
              ],
              if (loadingDetail && !hasFullData) ...[
                if (showPieceBreakdown) ...[
                  const SizedBox(height: 12),
                  const _ToyDetailSectionSkeleton(title: "Pieces"),
                ],
                if (auth.isAdmin) ...[
                  const SizedBox(height: 12),
                  const _ToyDetailSectionSkeleton(title: "Member"),
                ],
                const SizedBox(height: 12),
                const _ToyDetailSectionSkeleton(title: "Description"),
              ] else ...[
              const SizedBox(height: 12),
              ToyDetailSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ToyDetailSectionTitle(title: "Description"),
                    const SizedBox(height: 8),
                    Text(
                      description ?? "No description available.",
                      style: description != null
                          ? context.metaValue.copyWith(height: 1.45)
                          : context.bodyPlaceholder.copyWith(height: 1.45),
                    ),
                  ],
                ),
              ),
              ],
            ],
          ),
              if (loadingDetail)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                        child: ColoredBox(
                          color: theme.scaffoldBackgroundColor
                              .withValues(alpha: 0.55),
                          child: const Center(
                            child: ToyLibraryLoadingIndicator(
                              message: "Loading toy…",
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ToyDetailSectionSkeleton extends StatelessWidget {
  const _ToyDetailSectionSkeleton({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final fill = Theme.of(context)
        .colorScheme
        .onSurface
        .withValues(alpha: 0.08);

    return ToyDetailSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ToyDetailSectionTitle(title: title),
          const SizedBox(height: 12),
          Container(
            height: 14,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 10),
          FractionallySizedBox(
            widthFactor: 0.72,
            alignment: Alignment.centerLeft,
            child: Container(
              height: 14,
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToyDetailMemberBar extends StatelessWidget {
  const _ToyDetailMemberBar({
    required this.toy,
    required this.bookingInProgress,
    required this.cancellingInProgress,
    required this.reschedulingInProgress,
    required this.onSignIn,
    required this.onChooseMembership,
    required this.onBook,
    required this.onChangePickupDate,
    required this.onCancelBooking,
  });

  final ToyItem toy;
  final bool bookingInProgress;
  final bool cancellingInProgress;
  final bool reschedulingInProgress;
  final VoidCallback onSignIn;
  final VoidCallback onChooseMembership;
  final VoidCallback onBook;
  final ValueChanged<BookingItem> onChangePickupDate;
  final ValueChanged<BookingItem> onCancelBooking;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();
    final myBooking = context.select<BookingsController, BookingItem?>(
      (controller) => controller.pendingBookingForToy(toy.toyId),
    );
    final myActiveLoan =
        toy.availability == "on_loan" || toy.availability == "reserved"
        ? context.select<LoansController, LoanItem?>(
            (controller) => controller.activeLoanForToy(toy.toyId),
          )
        : null;

    return ToyDetailActionBar(
      toy: toy,
      showsSignedInUi: auth.showsSignedInUi,
      needsMembershipOnboarding: auth.needsMembershipOnboarding,
      canBookToys: auth.canBookToys,
      myBooking: myBooking,
      myActiveLoan: myActiveLoan,
      bookingInProgress: bookingInProgress,
      cancellingInProgress: cancellingInProgress,
      reschedulingInProgress: reschedulingInProgress,
      onSignIn: onSignIn,
      onChooseMembership: onChooseMembership,
      onBook: onBook,
      onChangePickupDate: myBooking == null
          ? () {}
          : () => onChangePickupDate(myBooking),
      onCancelBooking: myBooking == null
          ? () {}
          : () => onCancelBooking(myBooking),
    );
  }
}
