import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../core/app_text_styles.dart";
import "../../core/section_header.dart";
import "../bookings/booking_models.dart";
import "../profile/profile_labels.dart";
import "admin_controller.dart";
import "admin_models.dart";

/// Member roster with membership tier and date filters.
class AdminMembersScreen extends StatefulWidget {
  const AdminMembersScreen({super.key});

  @override
  State<AdminMembersScreen> createState() => _AdminMembersScreenState();
}

class _AdminMembersScreenState extends State<AdminMembersScreen> {
  final TextEditingController _search = TextEditingController();
  String? _tierFilter;
  DateTime? _startedFrom;
  DateTime? _startedTo;
  DateTime? _endingFrom;
  DateTime? _endingTo;

  static const _tierOptions = [
    (null, "All tiers"),
    ("casual", "Casual"),
    ("non_duty", "Non-duty"),
    ("duty", "Duty"),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _reload() {
    return context.read<AdminController>().loadMembers(
          membershipTier: _tierFilter,
          startedFrom: _startedFrom,
          startedTo: _startedTo,
          endingFrom: _endingFrom,
          endingTo: _endingTo,
          queryText: _search.text,
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
                  controller: _search,
                  decoration: InputDecoration(
                    hintText: "Search name, email, or id",
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _search.clear();
                              setState(() {});
                              _reload();
                            },
                          ),
                  ),
                  onSubmitted: (_) => _reload(),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  initialValue: _tierFilter,
                  decoration: const InputDecoration(
                    labelText: "Membership type",
                    isDense: true,
                  ),
                  items: _tierOptions
                      .map(
                        (o) => DropdownMenuItem<String?>(
                          value: o.$1,
                          child: Text(o.$2),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() => _tierFilter = value);
                    _reload();
                  },
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilterChip(
                      label: Text(
                        _startedFrom == null
                            ? "Started from"
                            : "Started ≥ ${formatApiDate(_startedFrom!)}",
                      ),
                      selected: _startedFrom != null,
                      onSelected: (_) => _pickDate(
                        label: "Membership started from",
                        current: _startedFrom,
                        onPicked: (d) => _startedFrom = d,
                      ),
                    ),
                    FilterChip(
                      label: Text(
                        _startedTo == null
                            ? "Started to"
                            : "Started ≤ ${formatApiDate(_startedTo!)}",
                      ),
                      selected: _startedTo != null,
                      onSelected: (_) => _pickDate(
                        label: "Membership started to",
                        current: _startedTo,
                        onPicked: (d) => _startedTo = d,
                      ),
                    ),
                    FilterChip(
                      label: Text(
                        _endingFrom == null
                            ? "Ending from"
                            : "Ending ≥ ${formatApiDate(_endingFrom!)}",
                      ),
                      selected: _endingFrom != null,
                      onSelected: (_) => _pickDate(
                        label: "Membership ending from",
                        current: _endingFrom,
                        onPicked: (d) => _endingFrom = d,
                      ),
                    ),
                    FilterChip(
                      label: Text(
                        _endingTo == null
                            ? "Ending to"
                            : "Ending ≤ ${formatApiDate(_endingTo!)}",
                      ),
                      selected: _endingTo != null,
                      onSelected: (_) => _pickDate(
                        label: "Membership ending to",
                        current: _endingTo,
                        onPicked: (d) => _endingTo = d,
                      ),
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
              if (admin.membersLoading && admin.members.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (admin.membersError != null && admin.members.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(admin.membersError!, textAlign: TextAlign.center),
                  ),
                );
              }
              if (admin.members.isEmpty) {
                return RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      EmptyStateMessage("No members match these filters."),
                    ],
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: _reload,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  itemCount: admin.members.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) =>
                      _AdminMemberTile(member: admin.members[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AdminMemberTile extends StatelessWidget {
  const _AdminMemberTile({required this.member});

  final AdminMember member;

  @override
  Widget build(BuildContext context) {
    final tier = membershipTierLabel(member.membershipTier);
    final role = member.role == "volunteer" ? "Volunteer" : "Member";

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      title: Text(
        member.displayName,
        style: context.cardTitle,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (member.email.isNotEmpty)
            Text(member.email, style: context.listSubtitle),
          const SizedBox(height: 4),
          Text("$role · $tier", style: context.listSubtitle),
          const SizedBox(height: 2),
          Text(
            "Started ${formatAdminDate(member.membershipStartedAt)} · "
            "Ends ${formatAdminDate(member.membershipEndsAt)}",
            style: context.listSubtitle,
          ),
        ],
      ),
      isThreeLine: true,
    );
  }
}
