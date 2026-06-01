import "package:flutter/material.dart";

import "../loans/volunteer_desk_screen.dart";
import "duty_screen.dart";

/// Volunteer Duty tab: roster slots and checkout desk.
class VolunteerDutyTabScreen extends StatelessWidget {
  const VolunteerDutyTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: const TabBar(
              tabs: [
                Tab(text: "Duty slots"),
                Tab(text: "Duty desk"),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                DutyScreen(),
                VolunteerDeskScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
