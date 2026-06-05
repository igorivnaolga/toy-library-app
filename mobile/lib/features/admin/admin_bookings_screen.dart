import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../core/app_text_styles.dart";
import "../../core/app_input_field.dart";
import "../../core/app_theme.dart";
import "../../core/search_field.dart";
import "../../core/section_header.dart";
import "../bookings/booking_list_tile.dart";
import "../bookings/booking_models.dart";
import "../catalog/toy_detail_screen.dart";
import "admin_controller.dart";
import "admin_date_filters.dart";

/// All member bookings with date range and search.
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

  Future<void> _pickDate({
    required String label,
    required DateTime? current,
    required ValueChanged<DateTime?> onPicked,
  }) async {
    final picked = await showDatePicker(
      context: context,
      helpText: label,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (!mounted) return;
    setState(() => onPicked(picked));
    await _reload();
  }

  bool get _hasDateFilters => _pickupFrom != null || _pickupTo != null;

  Future<void> _clearDates() async {
    setState(() {
      _pickupFrom = null;
      _pickupTo = null;
    });
    await _reload();
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
                  style: fieldTextStyle(context),
                  cursorColor: fieldCursorColor(context),
                  decoration: searchInputDecoration(
                    context,
                    hintText: "Search by member, email, or toy",
                    suffixIcon: searchClearSuffix(
                      context,
                      visible: _memberQuery.text.isNotEmpty,
                      onClear: () {
                        _memberQuery.clear();
                        setState(() {});
                        _reload();
                      },
                    ),
                  ),
                  onSubmitted: (_) => _reload(),
                ),
                const SizedBox(height: 12),
                AdminDateFilterGroup(
                  title: "Pickup",
                  from: _pickupFrom,
                  to: _pickupTo,
                  onFromTap: () => _pickDate(
                    label: "Pickup from",
                    current: _pickupFrom,
                    onPicked: (d) => _pickupFrom = d,
                  ),
                  onToTap: () => _pickDate(
                    label: "Pickup to",
                    current: _pickupTo,
                    onPicked: (d) => _pickupTo = d,
                  ),
                  onFromClear: _pickupFrom == null
                      ? null
                      : () async {
                          setState(() => _pickupFrom = null);
                          await _reload();
                        },
                  onToClear: _pickupTo == null
                      ? null
                      : () async {
                          setState(() => _pickupTo = null);
                          await _reload();
                        },
                ),
                if (_hasDateFilters) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton(
                      onPressed: _clearDates,
                      style: brandOutlinedButtonStyle(
                        backgroundColor:
                            Theme.of(context).colorScheme.surface,
                      ),
                      child: const Text("Clear dates"),
                    ),
                  ),
                ],
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
                      EmptyStateMessage("No bookings match your search."),
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
