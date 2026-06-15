import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../core/api_client.dart";
import "../../core/api_exception.dart";
import "../../core/notification_bell_ack.dart";
import "../../core/toy_loading_indicator.dart";
import "../profile/profile_labels.dart";
import "admin_controller.dart";
import "admin_member_profile_screen.dart";
import "admin_models.dart";

/// Admin bell badge: only counts above what the admin last viewed.
int adminNotificationBadgeCount(
  AdminNotifications? summary,
  NotificationBellAckStore ack,
) {
  if (summary == null || !ack.adminAckLoaded) return 0;
  return ack.adminUnreadCount(summary);
}

/// Opens admin notifications (full screen).
Future<void> showAdminNotificationsSheet(BuildContext context) async {
  if (!context.mounted) return;
  final admin = context.read<AdminController>();
  final ack = context.read<NotificationBellAckStore>();
  final summary = admin.notifications;
  if (summary != null) {
    await ack.markAdminNotificationsSeen(summary);
  }
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => const AdminNotificationsScreen(),
    ),
  );
  if (context.mounted) {
    await context.read<AdminController>().loadNotifications(silent: true);
    final updated = context.read<AdminController>().notifications;
    if (updated != null && context.mounted) {
      await ack.markAdminNotificationsSeen(updated);
    }
  }
}

class AdminNotificationBell extends StatefulWidget {
  const AdminNotificationBell({super.key});

  @override
  State<AdminNotificationBell> createState() => _AdminNotificationBellState();
}

class _AdminNotificationBellState extends State<AdminNotificationBell> {
  AdminNotifications? _lastReconciled;

  @override
  Widget build(BuildContext context) {
    final ack = context.watch<NotificationBellAckStore>();
    return Consumer<AdminController>(
      builder: (context, admin, _) {
        final summary = admin.notifications;
        if (summary != null && !identical(summary, _lastReconciled)) {
          _lastReconciled = summary;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;
            await context
                .read<NotificationBellAckStore>()
                .reconcileAdminSummary(summary);
          });
        }
        final count = adminNotificationBadgeCount(summary, ack);
        return IconButton(
          tooltip: "Admin notifications",
          onPressed: () => showAdminNotificationsSheet(context),
          icon: Badge(
            isLabelVisible: count > 0,
            label: Text(count > 9 ? "9+" : "$count"),
            child: const Icon(Icons.notifications_outlined),
          ),
        );
      },
    );
  }
}

/// Pending duty approvals and recently joined members.
class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  bool _loading = true;
  String? _loadError;
  List<PendingVolunteer> _pending = [];
  List<AdminMember> _recent = [];
  String? _recentError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
      _recentError = null;
    });

    final client = context.read<BackendClient>();
    List<PendingVolunteer> pending = [];
    List<AdminMember> recent = [];
    String? loadError;
    String? recentError;

    try {
      final json =
          await client.getJson("/api/v1/admin/pending-duty-volunteers");
      final raw = json["data"];
      if (raw is List<dynamic>) {
        pending = raw
            .whereType<Map<String, dynamic>>()
            .map(PendingVolunteer.fromJson)
            .toList();
      }
    } on ApiException catch (e) {
      loadError = "Pending approvals: ${e.message}";
    } catch (e) {
      loadError = "Pending approvals: $e";
    }

    try {
      final json = await client.getJson(
        "/api/v1/admin/recent-members",
        {"days": "7"},
      );
      recent = parseAdminMemberList(json);
    } on ApiException catch (e) {
      recentError = e.message;
    } catch (e) {
      recentError = e.toString();
    }

    if (!mounted) return;
    setState(() {
      _pending = pending;
      _recent = recent;
      _loadError = loadError;
      _recentError = recentError;
      _loading = false;
    });
  }

  Future<void> _approve(PendingVolunteer volunteer) async {
    final client = context.read<BackendClient>();
    try {
      await client.postJson(
        "/api/v1/admin/users/${volunteer.userId}/approve-volunteer",
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Approved ${volunteer.displayName}")),
      );
      await _load();
      if (!mounted) return;
      await context.read<AdminController>().loadNotifications(silent: true);
      final summary = context.read<AdminController>().notifications;
      if (summary != null) {
        await context
            .read<NotificationBellAckStore>()
            .markAdminNotificationsSeen(summary);
      }
    } catch (e) {
      if (!mounted) return;
      final message =
          e is ApiException ? e.message : adminActionErrorMessage(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _openMemberProfile(AdminMember member) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminMemberProfileScreen(
          userId: member.userId,
          initialMember: member,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifications"),
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: ToyLibraryLoadingIndicator(
          message: "Loading notifications…",
        ),
      );
    }

    if (_loadError != null && _pending.isEmpty && _recent.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _loadError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 14),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _load,
                child: const Text("Retry"),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_loadError != null) ...[
            Text(
              _loadError!,
              style: const TextStyle(color: Colors.red, fontSize: 14),
            ),
            const SizedBox(height: 12),
          ],
          _sectionTitle("Pending volunteer approvals"),
          const SizedBox(height: 8),
          if (_pending.isEmpty)
            _sectionBody("No duty members waiting for approval.")
          else
            ..._pending.map(
              (row) => _PendingVolunteerCard(
                volunteer: row,
                onApprove: () => _approve(row),
              ),
            ),
          const SizedBox(height: 24),
          _sectionTitle("New members (last 7 days)"),
          const SizedBox(height: 8),
          if (_recentError != null) ...[
            Text(
              _recentError!,
              style: const TextStyle(color: Colors.red, fontSize: 14),
            ),
            const SizedBox(height: 8),
          ],
          if (_recent.isEmpty && _recentError == null)
            _sectionBody("No new members in the last 7 days.")
          else
            ..._recent.map(
              (member) => _RecentMemberCard(
                member: member,
                onTap: () => _openMemberProfile(member),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1A1A1A),
      ),
    );
  }

  Widget _sectionBody(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        height: 1.35,
        color: Color(0xFF5C5C5C),
      ),
    );
  }
}

class _PendingVolunteerCard extends StatelessWidget {
  const _PendingVolunteerCard({
    required this.volunteer,
    required this.onApprove,
  });

  final PendingVolunteer volunteer;
  final VoidCallback onApprove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              volunteer.displayName,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (volunteer.email.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                volunteer.email,
                style: const TextStyle(fontSize: 13, color: Color(0xFF5C5C5C)),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onApprove,
              child: const Text("Approve volunteer"),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentMemberCard extends StatelessWidget {
  const _RecentMemberCard({
    required this.member,
    required this.onTap,
  });

  final AdminMember member;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                member.displayName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (member.email.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  member.email,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF5C5C5C)),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                membershipTierLabel(member.membershipTier),
                style: const TextStyle(fontSize: 13, color: Color(0xFF5C5C5C)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
