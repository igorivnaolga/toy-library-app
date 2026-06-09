import "package:flutter/material.dart";

import "../admin/admin_loans_screen.dart";

/// Volunteer Duty tab: check-out and check-in desk (same layout as admin).
class VolunteerDutyTabScreen extends StatelessWidget {
  const VolunteerDutyTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminLoansScreen(volunteerDeskMode: true);
  }
}
