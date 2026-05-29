import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../core/app_text_styles.dart";
import "../../core/section_header.dart";
import "../bookings/booking_list_tile.dart";
import "../bookings/booking_models.dart";
import "../catalog/toy_detail_screen.dart";
import "admin_controller.dart";

/// All member bookings with date and member filters.
class AdminBookingsScreen extends StatefulWidget {
  const AdminBookingsScreen({super.key});

  @override
  State<AdminBookingsScreen> createState() => _AdminBookingsScreenState();
}

class _AdminBookingsScreenState extends State<AdminBookingsScreen> {
  final TextEditingController _memberQuery = TextEditingController();
  DateTime? _pickupFrom;
  DateTime? _pickupTo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  @override
  void dispose() {
    _memberQuery.dispose();
    super.dispose();
  }

  Future<void> _reload() {
    return context.read<AdminController>().loadBookings(
          pickupFrom: _pickupFrom,
          pickupTo: _pickupTo,
          memberQuery: _memberQuery.text,
        );
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom ? _pickupFrom : _pickupTo;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isFrom) {
        _pickupFrom = picked;
      } else {
        _pickupTo = picked;
      }
    });
    await _reload();
  }

  void _clearDates() {
    setState(() {
      _pickupFrom = null;
      _pickupTo = null;
    });
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _memberQuery,
                  decoration: InputDecoration(
                    hintText: "Filter by member, email, or toy",
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _memberQuery.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _memberQuery.clear();
                              setState(() {});
                              _reload();
                            },
                          ),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _reload(),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilterChip(
                      label: Text(
                        _pickupFrom == null
                            ? "From date"
                            : "From ${formatApiDate(_pickupFrom!)}",
                      ),
                      selected: _pickupFrom != null,
                      onSelected: (_) => _pickDate(isFrom: true),
                    ),
                    FilterChip(
                      label: Text(
                        _pickupTo == null
                            ? "To date"
                            : "To ${formatApiDate(_pickupTo!)}",
                      ),
                      selected: _pickupTo != null,
                      onSelected: (_) => _pickDate(isFrom: false),
                    ),
                    if (_pickupFrom != null || _pickupTo != null)
                      ActionChip(
                        label: const Text("Clear dates"),
                        onPressed: _clearDates,
                      ),
                    ActionChip(
                      avatar: const Icon(Icons.refresh, size: 18),
                      label: const Text("Apply"),
                      onPressed: _reload,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Consumer<AdminController>(
            builder: (context, admin, _) {
              if (admin.bookingsLoading && admin.bookings.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (admin.bookingsError != null && admin.bookings.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(admin.bookingsError!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: admin.bookingsLoading ? null : _reload,
                          icon: const Icon(Icons.refresh),
                          label: const Text("Retry"),
                        ),
                      ],
                    ),
                  ),
                );
              }
              if (admin.bookings.isEmpty) {
                return RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      EmptyStateMessage("No bookings match these filters."),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: _reload,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  itemCount: admin.bookings.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final item = admin.bookings[i];
                    return _AdminBookingTile(item: item);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AdminBookingTile extends StatelessWidget {
  const _AdminBookingTile({required this.item});

  final BookingItem item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
          child: Text(
            item.memberLabel,
            style: context.groupLabel,
          ),
        ),
        BookingListTile(
          item: item,
          loading: false,
          onOpen: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ToyDetailScreen(toyId: item.toyId),
              ),
            );
          },
          onChangeDate: null,
          onCancel: null,
        ),
      ],
    );
  }
}
