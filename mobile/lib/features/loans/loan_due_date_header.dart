import "package:flutter/material.dart";

import "../../core/app_text_styles.dart";
import "../../core/app_theme.dart";
import "loan_models.dart";

/// Prominent due-date group header for the member loans list.
class LoanDueDateHeader extends StatelessWidget {
  const LoanDueDateHeader({
    super.key,
    required this.dueDate,
    required this.isOverdue,
  });

  final DateTime dueDate;
  final bool isOverdue;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final background = isOverdue
        ? const Color(0xFFFFEBEE)
        : kBrandYellow.withValues(alpha: 0.18);
    final borderColor = isOverdue
        ? colors.error.withValues(alpha: 0.35)
        : kBrandYellow.withValues(alpha: 0.55);
    final iconColor =
        isOverdue ? colors.error : kBrandOnYellow.withValues(alpha: 0.72);
    final dateColor = isOverdue ? const Color(0xFFC62828) : colors.onSurface;

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Icon(Icons.event_outlined, size: 22, color: iconColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Due date", style: context.formSectionLabel),
                  const SizedBox(height: 2),
                  Text(
                    formatDisplayDate(dueDate),
                    style: context.cardTitle.copyWith(
                      color: dateColor,
                      fontSize: 17,
                    ),
                  ),
                ],
              ),
            ),
            if (isOverdue)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFCDD2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  "Overdue",
                  style: TextStyle(
                    color: Color(0xFFC62828),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
