import "package:flutter/material.dart";

import "../catalog/toy_photo_tile.dart";
import "loan_models.dart";

/// Confirm toy details before checking a loan back in at the desk.
Future<bool> showDeskCheckInDialog(
  BuildContext context,
  LoanItem loan,
) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      return AlertDialog(
        title: const Text("Confirm check-in"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ToyPhotoTile(toyId: loan.toyId),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loan.toyName ?? loan.toyId,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text("Toy id: ${loan.toyId}"),
                        const SizedBox(height: 4),
                        Text("Member: ${loan.memberLabel}"),
                        const SizedBox(height: 4),
                        Text("Due ${formatDisplayDate(loan.dueDate)}"),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                "Confirm the toy matches what is being returned, then check it in.",
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Check in"),
          ),
        ],
      );
    },
  );
  return result == true;
}
