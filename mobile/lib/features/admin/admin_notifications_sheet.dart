import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../core/app_text_styles.dart";
import "../../core/section_header.dart";
import "admin_controller.dart";
import "admin_models.dart";

/// Bell icon action: pending duty-tier volunteer approvals.
Future<void> showAdminNotificationsSheet(BuildContext context) async {
  final controller = context.read<AdminController>();
  await controller.loadPendingVolunteers();
  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return _PendingApprovalsSheet(scrollController: scrollController);
        },
      );
    },
  );
}

class AdminNotificationBell extends StatelessWidget {
  const AdminNotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminController>(
      builder: (context, admin, _) {
        final count = admin.notifications?.pendingVolunteerApprovals ?? 0;
        return IconButton(
          tooltip: "Pending approvals",
          onPressed: () => showAdminNotificationsSheet(context),
          icon: Badge(
            isLabelVisible: count > 0,
            label: Text("$count"),
            child: const Icon(Icons.notifications_outlined),
          ),
        );
      },
    );
  }
}

class _PendingApprovalsSheet extends StatelessWidget {
  const _PendingApprovalsSheet({required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminController>(
      builder: (context, admin, _) {
        if (admin.pendingLoading && admin.pendingVolunteers.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                "Pending volunteer approvals",
                style: context.screenTitle,
              ),
            ),
            if (admin.pendingError != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  admin.pendingError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Expanded(
              child: admin.pendingVolunteers.isEmpty
                  ? ListView(
                      controller: scrollController,
                      children: const [
                        EmptyStateMessage(
                          "No members waiting for approval.",
                          topSpacing: 48,
                        ),
                      ],
                    )
                  : ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                      itemCount: admin.pendingVolunteers.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final row = admin.pendingVolunteers[i];
                        return _PendingVolunteerTile(volunteer: row);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _PendingVolunteerTile extends StatelessWidget {
  const _PendingVolunteerTile({required this.volunteer});

  final PendingVolunteer volunteer;

  @override
  Widget build(BuildContext context) {
    final admin = context.read<AdminController>();
    return ListTile(
      title: Text(volunteer.displayName, style: context.cardTitle),
      subtitle: Text(
        volunteer.email.isEmpty ? "Duty tier member" : volunteer.email,
        style: context.listSubtitle,
      ),
      trailing: FilledButton(
        onPressed: admin.pendingLoading
            ? null
            : () async {
                try {
                  await admin.approveVolunteer(volunteer.userId);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Approved ${volunteer.displayName}"),
                    ),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(adminActionErrorMessage(e))),
                  );
                }
              },
        child: const Text("Approve"),
      ),
    );
  }
}
