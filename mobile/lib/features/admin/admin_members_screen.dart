import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../core/app_text_styles.dart";
import "../../core/app_input_field.dart";
import "../../core/search_field.dart";
import "../../core/app_theme.dart";
import "../../core/section_header.dart";
import "../profile/profile_labels.dart";
import "admin_controller.dart";
import "admin_date_filters.dart";
import "admin_member_profile_screen.dart";
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

  bool get _hasDateFilters => _startedFrom != null || _startedTo != null;

  Future<void> _clearDateFilters() async {
    setState(() {
      _startedFrom = null;
      _startedTo = null;
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
                  controller: _search,
                  style: fieldTextStyle(context),
                  cursorColor: fieldCursorColor(context),
                  decoration: searchInputDecoration(
                    context,
                    hintText: "Search name or email",
                    suffixIcon: searchClearSuffix(
                      context,
                      visible: _search.text.isNotEmpty,
                      onClear: () {
                        _search.clear();
                        setState(() {});
                        _reload();
                      },
                    ),
                  ),
                  onSubmitted: (_) => _reload(),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: _tierFilter,
                  decoration: labeledInputDecoration(
                    context,
                    labelText: "Membership type",
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
                const SizedBox(height: 12),
                AdminDateFilterGroup(
                  title: "Started",
                  from: _startedFrom,
                  to: _startedTo,
                  onFromTap: () => _pickDate(
                    label: "Membership started from",
                    current: _startedFrom,
                    onPicked: (d) => _startedFrom = d,
                  ),
                  onToTap: () => _pickDate(
                    label: "Membership started to",
                    current: _startedTo,
                    onPicked: (d) => _startedTo = d,
                  ),
                  onFromClear: _startedFrom == null
                      ? null
                      : () async {
                          setState(() => _startedFrom = null);
                          await _reload();
                        },
                  onToClear: _startedTo == null
                      ? null
                      : () async {
                          setState(() => _startedTo = null);
                          await _reload();
                        },
                ),
                if (_hasDateFilters) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton(
                      onPressed: _clearDateFilters,
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
                  itemBuilder: (context, i) => _AdminMemberTile(
                    member: admin.members[i],
                    onTap: () async {
                      final member = admin.members[i];
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => AdminMemberProfileScreen(
                            userId: member.userId,
                            initialMember: member,
                          ),
                        ),
                      );
                      if (!context.mounted) return;
                      await _reload();
                    },
                  ),
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
  const _AdminMemberTile({
    required this.member,
    required this.onTap,
  });

  final AdminMember member;
  final VoidCallback onTap;

  bool get _showDutySessionsLabel =>
      member.role == "volunteer" || member.membershipTier == "duty";

  @override
  Widget build(BuildContext context) {
    final tier = membershipTierLabel(member.membershipTier);
    final role = member.role == "volunteer" ? "Volunteer" : "Member";

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              member.displayName,
              style: context.cardTitle,
            ),
          ),
          if (_showDutySessionsLabel) ...[
            const SizedBox(width: 8),
            _DutySessionsBadge(count: member.dutySessionsCompleted),
          ],
        ],
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
            "Started ${formatAdminDate(member.membershipStartedAt)}",
            style: context.listSubtitle,
          ),
        ],
      ),
      isThreeLine: true,
    );
  }
}

class _DutySessionsBadge extends StatelessWidget {
  const _DutySessionsBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final complete = isDutyRequirementMet(count);
    final label = dutySessionsCompletedLabel(count);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: complete
            ? kDutyCompleteBg
            : kBrandYellow.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: complete ? kDutyCompleteBorder : kBrandYellow,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: complete ? kDutyCompleteFg : kBrandOnYellow,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}
