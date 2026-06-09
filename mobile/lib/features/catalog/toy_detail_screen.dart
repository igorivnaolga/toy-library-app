import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../core/api_exception.dart";
import "../../core/app_text_styles.dart";
import "../../core/auth_store.dart";
import "../../core/toy_photo_url.dart";
import "../../core/toy_pieces.dart";
import "../auth/login_screen.dart";
import "../bookings/booking_confirmed_dialog.dart";
import "../bookings/booking_models.dart";
import "../bookings/bookings_controller.dart";
import "../bookings/pickup_date_flow.dart";
import "../loans/loans_controller.dart";
import "catalog_models.dart";
import "catalog_provider.dart";
import "toy_edit_sheet.dart";
import "toy_label_pdf.dart";
import "toy_availability_badge.dart";
import "toy_id_badge.dart";
import "toy_detail_action_bar.dart";
import "toy_detail_section.dart";
import "toy_photo_placeholder.dart";

/// Loads a single toy from `GET /api/v1/toys/{toy_id}`.
class ToyDetailScreen extends StatefulWidget {
  const ToyDetailScreen({super.key, required this.toyId});

  final String toyId;

  @override
  State<ToyDetailScreen> createState() => _ToyDetailScreenState();
}

class _ToyDetailScreenState extends State<ToyDetailScreen> {
  Future<ToyItem>? _future;
  bool _started = false;
  bool _bookingsRequested = false;
  bool _loansRequested = false;
  bool _bookingInProgress = false;
  bool _cancellingInProgress = false;
  bool _reschedulingInProgress = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthStore>();
    if (!_bookingsRequested && auth.canBookToys) {
      _bookingsRequested = true;
      context.read<BookingsController>().loadBookings();
    }
    if (!_loansRequested && auth.canBookToys) {
      _loansRequested = true;
      context.read<LoansController>().loadMyLoans(activeOnly: true);
    }
    if (_started) return;
    _started = true;
    setState(() {
      _future = context.read<CatalogController>().fetchToy(widget.toyId);
    });
  }

  void _retry() {
    setState(() {
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
      await catalog.refresh();
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
      await catalog.refresh();
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();
    final bookings = context.watch<BookingsController>();
    final loans = context.watch<LoansController>();

    return FutureBuilder<ToyItem>(
      future: _future,
      builder: (context, snapshot) {
        if (_future == null ||
            snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text("Toy details")),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

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

        final t = snapshot.data!;
        final theme = Theme.of(context);
        final colors = theme.colorScheme;
        final hasPhotoName = t.photoFile != null && t.photoFile!.isNotEmpty;
        final myBooking = bookings.pendingBookingForToy(t.toyId);
        final myActiveLoan = t.availability == "on_loan"
            ? loans.activeLoanForToy(t.toyId)
            : null;
        final description = t.description?.trim().isNotEmpty == true
            ? t.description!.trim()
            : null;

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
                      final message =
                          e is ApiException ? e.message : e.toString();
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
                    final updated = await showToyEditSheet(context, toy: t);
                    if (!context.mounted) return;
                    if (updated != null) {
                      await context.read<CatalogController>().refresh();
                      _retry();
                    }
                  },
                ),
              ],
            ],
          ),
          bottomNavigationBar: auth.isAdmin
              ? null
              : ToyDetailActionBar(
            toy: t,
            isLoggedIn: auth.isLoggedIn,
            canBookToys: auth.canBookToys,
            myBooking: myBooking,
            myActiveLoan: myActiveLoan,
            bookingInProgress: _bookingInProgress,
            cancellingInProgress: _cancellingInProgress,
            reschedulingInProgress: _reschedulingInProgress,
            onSignIn: _signInToBook,
            onBook: () => _startBookFlow(t),
            onChangePickupDate: myBooking == null
                ? () {}
                : () => _changePickupDate(myBooking, t),
            onCancelBooking: myBooking == null
                ? () {}
                : () => _cancelBooking(myBooking, t),
          ),
          body: ListView(
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
                              toyPhotoHttpUrl(t.toyId),
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.medium,
                              errorBuilder: (_, __, ___) => ToyPhotoPlaceholder(
                                expand: true,
                                borderRadius: 12,
                              ),
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) {
                                  return child;
                                }
                                return const Center(
                                    child: CircularProgressIndicator());
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
                        ToyAvailabilityBadge(
                          availability: t.availability,
                          isMyLoan: myActiveLoan != null,
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
                          ? context.bodyText
                          : context.bodyPlaceholder,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
