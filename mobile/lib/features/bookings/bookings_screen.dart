import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../core/app_theme.dart";
import "../../core/auth_store.dart";
import "../catalog/catalog_provider.dart";
import "../catalog/toy_detail_screen.dart";
import "booking_list_tile.dart";
import "booking_models.dart";
import "bookings_controller.dart";
import "pickup_date_flow.dart";

/// Member bookings list with cancel for pending reservations.
class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<BookingsController>().loadBookings();
    });
  }

  Future<void> _cancel(BookingItem item) async {
    final controller = context.read<BookingsController>();
    final catalog = context.read<CatalogController>();
    try {
      await controller.cancelBooking(item.bookingId);
      await catalog.refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Cancelled booking for ${item.toyName ?? item.toyId}"),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(bookingActionErrorMessage(e))),
      );
    }
  }

  Future<void> _changePickupDate(BookingItem item) async {
    final controller = context.read<BookingsController>();
    try {
      final selected = await choosePickupDate(
        context,
        controller,
        title: "Change pickup day",
      );
      if (selected == null || !mounted) return;
      await controller.rescheduleBooking(item.bookingId, selected.date);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Pickup updated to ${selected.label} for ${item.toyName ?? item.toyId}",
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(bookingActionErrorMessage(e))),
      );
    }
  }

  Widget _bookingTile(
    BuildContext context,
    BookingsController c,
    BookingItem item,
  ) {
    return BookingListTile(
      item: item,
      loading: c.loading,
      onOpen: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ToyDetailScreen(toyId: item.toyId),
          ),
        );
      },
      onChangeDate: () => _changePickupDate(item),
      onCancel: () => _cancel(item),
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
            "Sign in to view and manage your toy bookings.",
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (!auth.canBookToys) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            "Complete membership setup to book toys from the catalog.",
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Consumer<BookingsController>(
      builder: (context, c, _) {
        if (c.loading && c.bookings.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (c.error != null && c.bookings.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(c.error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: c.loading ? null : () => c.loadBookings(),
                    icon: const Icon(Icons.refresh),
                    label: const Text("Retry"),
                  ),
                ],
              ),
            ),
          );
        }
        if (c.bookings.isEmpty) {
          return RefreshIndicator(
            onRefresh: c.loadBookings,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                Center(
                  child: Text(
                    "No bookings yet.\nOpen a toy in the catalog and tap Book.",
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        }

        final sections = groupBookingsBySection(c.bookings);

        return RefreshIndicator(
          onRefresh: c.loadBookings,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            children: [
              if (sections.upcoming.isNotEmpty) ...[
                const _BookingsSectionHeader(title: "Upcoming"),
                for (var i = 0; i < sections.upcoming.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _bookingTile(context, c, sections.upcoming[i]),
                ],
              ],
              if (sections.upcoming.isNotEmpty && sections.past.isNotEmpty)
                const SizedBox(height: 20),
              if (sections.past.isNotEmpty) ...[
                const _BookingsSectionHeader(title: "Past"),
                for (var i = 0; i < sections.past.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _bookingTile(context, c, sections.past[i]),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}

class _BookingsSectionHeader extends StatelessWidget {
  const _BookingsSectionHeader({required this.title});

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
