import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../core/toy_loading_indicator.dart";
import "../../core/section_header.dart";
import "../../core/auth_store.dart";
import "../catalog/catalog_provider.dart";
import "../catalog/toy_detail_screen.dart";
import "booking_list_tile.dart";
import "booking_models.dart";
import "booking_pickup_date_section.dart";
import "bookings_controller.dart";
import "pickup_date_flow.dart";

/// Member bookings list with cancel for pending reservations.
class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

enum _BookingsRowType {
  upcomingHeader,
  groupGap,
  pickupGroup,
  sectionGap,
  pastHeader,
  pastGap,
  pastBooking,
}

class _BookingsRow {
  const _BookingsRow(
    this.type, {
    this.groupIndex,
    this.pastIndex,
  });

  final _BookingsRowType type;
  final int? groupIndex;
  final int? pastIndex;
}

class _BookingsScreenState extends State<BookingsScreen> {
  bool _pastExpanded = false;

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
      await catalog.updateToyInCatalog(item.toyId);
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
        toyId: item.toyId,
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
      key: ValueKey(item.bookingId),
      item: item,
      loading: c.loading,
      inGroup: item.isPending,
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

  List<_BookingsRow> _bookingsListRows(BookingSections sections) {
    final rows = <_BookingsRow>[];
    if (sections.upcomingByPickupDate.isNotEmpty) {
      rows.add(const _BookingsRow(_BookingsRowType.upcomingHeader));
      for (var g = 0; g < sections.upcomingByPickupDate.length; g++) {
        if (g > 0) {
          rows.add(const _BookingsRow(_BookingsRowType.groupGap));
        }
        rows.add(_BookingsRow(_BookingsRowType.pickupGroup, groupIndex: g));
      }
    }
    if (sections.upcomingByPickupDate.isNotEmpty && sections.past.isNotEmpty) {
      rows.add(const _BookingsRow(_BookingsRowType.sectionGap));
    }
    if (sections.past.isNotEmpty) {
      rows.add(const _BookingsRow(_BookingsRowType.pastHeader));
      if (_pastExpanded) {
        for (var i = 0; i < sections.past.length; i++) {
          if (i > 0) {
            rows.add(const _BookingsRow(_BookingsRowType.pastGap));
          }
          rows.add(_BookingsRow(_BookingsRowType.pastBooking, pastIndex: i));
        }
      }
    }
    return rows;
  }

  Widget _buildBookingsRow(
    BuildContext context,
    BookingsController controller,
    BookingSections sections,
    _BookingsRow row,
  ) {
    switch (row.type) {
      case _BookingsRowType.upcomingHeader:
        return const SectionHeader("Upcoming");
      case _BookingsRowType.groupGap:
        return const SizedBox(height: 12);
      case _BookingsRowType.pickupGroup:
        final group = sections.upcomingByPickupDate[row.groupIndex!];
        return BookingPickupDateSection(
          group: group,
          children: [
            for (final item in group.bookings)
              _bookingTile(context, controller, item),
          ],
        );
      case _BookingsRowType.sectionGap:
        return const SizedBox(height: 20);
      case _BookingsRowType.pastHeader:
        return CollapsibleSection(
          title: "Past (${sections.past.length})",
          expanded: _pastExpanded,
          onToggle: () => setState(() => _pastExpanded = !_pastExpanded),
          children: const [],
        );
      case _BookingsRowType.pastGap:
        return const SizedBox(height: 8);
      case _BookingsRowType.pastBooking:
        return _bookingTile(
          context,
          controller,
          sections.past[row.pastIndex!],
        );
    }
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

    if (!auth.isMember && !auth.isVolunteer) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            "Sign in as a member to view and manage your toy bookings.",
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Consumer<BookingsController>(
      builder: (context, c, _) {
        if (c.loading && c.bookings.isEmpty) {
          return const Center(child: ToyLibraryLoadingIndicator());
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
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              children: const [
                EmptyStateMessage(
                  "No bookings yet.\nOpen a toy in the catalog and tap Book.",
                ),
              ],
            ),
          );
        }

        final sections = groupBookingsBySection(c.bookings);
        final rows = _bookingsListRows(sections);

        return RefreshIndicator(
          onRefresh: c.loadBookings,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            itemCount: rows.length,
            itemBuilder: (context, index) {
              return _buildBookingsRow(context, c, sections, rows[index]);
            },
          ),
        );
      },
    );
  }
}
