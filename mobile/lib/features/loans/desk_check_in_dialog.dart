import "package:flutter/material.dart";

import "../../core/app_text_styles.dart";
import "../../core/modal_action_buttons.dart";
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                          style: context.cardTitle,
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
              const SizedBox(height: 20),
              ModalEqualWidthButtonRow(
                secondaryLabel: "Cancel",
                primaryLabel: "Check in",
                onSecondary: () => Navigator.pop(context, false),
                onPrimary: () => Navigator.pop(context, true),
              ),
            ],
          ),
        ),
      );
    },
  );
  return result == true;
}
