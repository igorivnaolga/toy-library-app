import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../core/toy_loading_indicator.dart";
import "../../core/app_text_styles.dart";
import "../../core/app_input_field.dart";
import "../../core/app_theme.dart";
import "../../core/search_field.dart";
import "../../core/section_header.dart";
import "../bookings/booking_list_tile.dart";
import "../bookings/booking_models.dart";
import "../bookings/booking_pickup_date_section.dart";
import "admin_models.dart";
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
                return const Center(child: ToyLibraryLoadingIndicator());
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
              final pendingBookings =
                  admin.bookings.where((item) => item.isPending).toList();
              if (pendingBookings.isEmpty) {
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

              final groups =
                  groupAdminBookingsByDateAndMember(pendingBookings);

              return RefreshIndicator(
                onRefresh: _reload,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  children: [
                    for (var d = 0; d < groups.byPickupDate.length; d++) ...[
                      if (d > 0) const SizedBox(height: 12),
                      BookingPickupDateSection(
                        group: groups.byPickupDate[d].pickupSummary,
                        showTotalRental: false,
                        children: [
                          for (var m = 0;
                              m < groups.byPickupDate[d].members.length;
                              m++) ...[
                            if (m > 0) const SizedBox(height: 10),
                            _AdminMemberSection(
                              section: groups.byPickupDate[d].members[m],
                            ),
                          ],
                        ],
                      ),
                    ],
                    if (groups.withoutPickupDate.isNotEmpty) ...[
                      if (groups.byPickupDate.isNotEmpty)
                        const SizedBox(height: 20),
                      const SectionHeader("No pickup date"),
                      for (var m = 0;
                          m < groups.withoutPickupDate.length;
                          m++) ...[
                        if (m > 0) const SizedBox(height: 10),
                        _AdminMemberSection(
                          section: groups.withoutPickupDate[m],
                        ),
                      ],
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AdminMemberSection extends StatelessWidget {
  const _AdminMemberSection({required this.section});

  final AdminBookingMemberSection section;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final email = section.memberEmail?.trim();
    final totalLabel = formatRentalPriceCents(section.totalRentalCents);
    final toyLabel =
        section.toyCount == 1 ? "1 toy" : "${section.toyCount} toys";

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              border: Border(
                left: BorderSide(
                  color: kBrandYellow.withValues(alpha: 0.55),
                  width: 4,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 20,
                      color: colors.onSurface.withValues(alpha: 0.72),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        section.memberLabel,
                        style: context.cardTitle.copyWith(fontSize: 16),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: kBrandYellow.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        toyLabel,
                        style: const TextStyle(
                          color: kBrandOnYellow,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ],
                ),
                if (email != null &&
                    email.isNotEmpty &&
                    email.toLowerCase() !=
                        section.memberLabel.toLowerCase()) ...[
                  const SizedBox(height: 2),
                  Padding(
                    padding: const EdgeInsets.only(left: 28),
                    child: Text(email, style: context.listSubtitle),
                  ),
                ],
                if (totalLabel != null) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 28),
                    child: Row(
                      children: [
                        Text(
                          "Total rental",
                          style: context.listSubtitle.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colors.onSurface.withValues(alpha: 0.72),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          totalLabel,
                          style: context.cardTitle.copyWith(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  if (section.unpricedBookingCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 28, top: 2),
                      child: Text(
                        section.unpricedBookingCount == 1
                            ? "Excludes 1 toy without a listed price"
                            : "Excludes ${section.unpricedBookingCount} toys without listed prices",
                        style: context.listSubtitle.copyWith(fontSize: 12),
                      ),
                    ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < section.bookings.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _AdminBookingTile(item: section.bookings[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminBookingTile extends StatelessWidget {
  const _AdminBookingTile({required this.item});

  final BookingItem item;

  @override
  Widget build(BuildContext context) {
    return BookingListTile(
      item: item,
      loading: false,
      inGroup: true,
      onOpen: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ToyDetailScreen(toyId: item.toyId),
          ),
        );
      },
      onChangeDate: null,
      onCancel: null,
    );
  }
}
