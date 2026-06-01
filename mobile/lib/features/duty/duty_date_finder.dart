import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "duty_controller.dart";

/// Opens a calendar to pick a day and scrolls the duty roster to that slot.
Future<void> findDutyDate(BuildContext context) async {
  final picked = await showDatePicker(
    context: context,
    helpText: "Find a duty slot",
    initialDate: DateTime.now(),
    firstDate: DateTime.now().subtract(const Duration(days: 365)),
    lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
  );
  if (picked == null || !context.mounted) return;

  final controller = context.read<DutyController>();
  final found = await controller.jumpToDate(picked);
  if (!context.mounted) return;
  if (!found) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("No duty slot on that date. Try a Wednesday or Saturday."),
      ),
    );
  }
}
