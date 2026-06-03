import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../core/app_text_styles.dart";
import "../../core/app_input_field.dart";
import "../../core/search_field.dart";
import "../../core/app_theme.dart";
import "../../core/section_header.dart";
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

  bool get _hasDateFilters =>
      _startedFrom != null ||
      _startedTo != null ||
      _endingFrom != null ||
      _endingTo != null;

  Future<void> _clearDateFilters() async {
    setState(() {
      _startedFrom = null;
      _startedTo = null;
      _endingFrom = null;
      _endingTo = null;
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
                _MembershipDateFilterGroup(
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
                const SizedBox(height: 12),
                _MembershipDateFilterGroup(
                  title: "Ending",
                  from: _endingFrom,
                  to: _endingTo,
                  onFromTap: () => _pickDate(
                    label: "Membership ending from",
                    current: _endingFrom,
                    onPicked: (d) => _endingFrom = d,
                  ),
                  onToTap: () => _pickDate(
                    label: "Membership ending to",
                    current: _endingTo,
                    onPicked: (d) => _endingTo = d,
                  ),
                  onFromClear: _endingFrom == null
                      ? null
                      : () async {
                          setState(() => _endingFrom = null);
                          await _reload();
                        },
                  onToClear: _endingTo == null
                      ? null
                      : () async {
                          setState(() => _endingTo = null);
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

class _MembershipDateFilterGroup extends StatelessWidget {
  const _MembershipDateFilterGroup({
    required this.title,
    required this.from,
    required this.to,
    required this.onFromTap,
    required this.onToTap,
    this.onFromClear,
    this.onToClear,
  });

  final String title;
  final DateTime? from;
  final DateTime? to;
  final VoidCallback onFromTap;
  final VoidCallback onToTap;
  final VoidCallback? onFromClear;
  final VoidCallback? onToClear;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: context.sectionHeader.copyWith(
              fontSize: 13,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _DateFilterChip(
                  label: "From",
                  date: from,
                  onTap: onFromTap,
                  onClear: onFromClear,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DateFilterChip(
                  label: "To",
                  date: to,
                  onTap: onToTap,
                  onClear: onToClear,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DateFilterChip extends StatelessWidget {
  const _DateFilterChip({
    required this.label,
    required this.date,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final active = date != null;
    final chipLabel =
        active ? "$label · ${formatAdminDate(date)}" : label;

    return Material(
      color: active
          ? colors.primaryContainer.withValues(alpha: 0.45)
          : colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: active ? kBrandYellow : colors.outlineVariant,
          width: active ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  chipLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: context.listSubtitle.copyWith(
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              if (active && onClear != null) ...[
                const SizedBox(width: 4),
                InkWell(
                  onTap: onClear,
                  customBorder: const CircleBorder(),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
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
