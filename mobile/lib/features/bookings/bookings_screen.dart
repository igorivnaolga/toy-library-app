import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../core/brand_chip_button.dart";
import "../../core/auth_store.dart";
import "../catalog/catalog_provider.dart";
import "../catalog/toy_detail_screen.dart";
import "../catalog/toy_photo_tile.dart";
import "booking_models.dart";
import "bookings_controller.dart";

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

        return RefreshIndicator(
          onRefresh: c.loadBookings,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: c.bookings.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = c.bookings[index];
              return ListTile(
                leading: ToyPhotoTile(toyId: item.toyId),
                title: Text(item.toyName ?? item.toyId),
                subtitle: Text(
                  "${item.statusLabel} · ${_formatWhen(item.createdAt)}",
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ToyDetailScreen(toyId: item.toyId),
                    ),
                  );
                },
                trailing: item.isPending
                    ? BrandChipButton(
                        label: "Cancel",
                        fixedWidth: kBookingsChipWidth,
                        onPressed: c.loading ? null : () => _cancel(item),
                      )
                    : BookingStatusChip(status: item.status),
              );
            },
          ),
        );
      },
    );
  }

  String _formatWhen(DateTime dt) {
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, "0");
    final m = local.month.toString().padLeft(2, "0");
    final d = local.day.toString().padLeft(2, "0");
    final h = local.hour.toString().padLeft(2, "0");
    final min = local.minute.toString().padLeft(2, "0");
    return "$y-$m-$d $h:$min";
  }
}
