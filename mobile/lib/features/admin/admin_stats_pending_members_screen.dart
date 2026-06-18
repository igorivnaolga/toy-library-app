import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../core/api_client.dart";
import "../../core/api_exception.dart";
import "../../core/app_text_styles.dart";
import "../../core/toy_loading_indicator.dart";
import "../../core/user_friendly_error.dart";
import "../bookings/booking_models.dart";
import "admin_member_profile_screen.dart";
import "admin_models.dart";
import "admin_statistics_models.dart";

/// Members with pending charges in the selected stats period.
class AdminStatsPendingMembersScreen extends StatefulWidget {
  const AdminStatsPendingMembersScreen({
    super.key,
    required this.period,
    this.sessionDate,
    this.year,
    this.month,
    required this.periodLabel,
  });

  final String period;
  final DateTime? sessionDate;
  final int? year;
  final int? month;
  final String periodLabel;

  @override
  State<AdminStatsPendingMembersScreen> createState() =>
      _AdminStatsPendingMembersScreenState();
}

class _AdminStatsPendingMembersScreenState
    extends State<AdminStatsPendingMembersScreen> {
  bool _loading = true;
  String? _error;
  StatsPendingMembers? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Map<String, String> _query() {
    final query = <String, String>{"period": widget.period};
    if (widget.period == "session" && widget.sessionDate != null) {
      query["session_date"] = formatApiDate(widget.sessionDate!);
    }
    if (widget.period == "month") {
      if (widget.year != null) query["year"] = "${widget.year}";
      if (widget.month != null) query["month"] = "${widget.month}";
    }
    if (widget.period == "year" && widget.year != null) {
      query["year"] = "${widget.year}";
    }
    return query;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final json = await context.read<BackendClient>().getJson(
            "/api/v1/admin/stats/payments/pending-members",
            _query(),
          );
      if (!mounted) return;
      setState(() {
        _result = StatsPendingMembers.fromJson(json);
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyErrorMessage(
          e,
          fallback: "Couldn't load pending members.",
        );
        _loading = false;
      });
    }
  }

  AdminMember _memberFromRow(StatsPendingMember row) {
    return AdminMember(
      userId: row.userId,
      email: row.email,
      fullName: row.fullName,
      role: "member",
    );
  }

  Future<void> _openProfile(StatsPendingMember row) async {
    final member = _memberFromRow(row);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminMemberProfileScreen(
          userId: member.userId,
          initialMember: member,
        ),
      ),
    );
    if (!mounted) return;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final totalLabel = result == null
        ? ""
        : formatRevenueCents(result.totalPendingCents);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Pending charges"),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Center(child: ToyLibraryLoadingIndicator()),
                ],
              )
            : _error != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    children: [
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  )
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                    children: [
                      Text(
                        widget.periodLabel,
                        style: context.sectionHeader.copyWith(fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        result!.data.isEmpty
                            ? "No pending charges in this period."
                            : "${result.data.length} "
                                "${result.data.length == 1 ? "member owes" : "members owe"} "
                                "$totalLabel in pending charges.",
                        style: context.listSubtitle,
                      ),
                      const SizedBox(height: 12),
                      if (result.data.isNotEmpty)
                        ...result.data.map(
                          (row) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _PendingMemberTile(
                              row: row,
                              onTap: () => _openProfile(row),
                            ),
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }
}

class _PendingMemberTile extends StatelessWidget {
  const _PendingMemberTile({
    required this.row,
    required this.onTap,
  });

  final StatsPendingMember row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.displayName,
                      style: context.cardTitle.copyWith(fontSize: 15),
                    ),
                    if (row.email.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        row.email.trim(),
                        style: context.listSubtitle.copyWith(fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatRevenueCents(row.pendingCents),
                style: context.cardTitle.copyWith(fontSize: 15),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
