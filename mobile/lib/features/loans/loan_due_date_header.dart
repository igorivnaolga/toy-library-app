import "package:flutter/material.dart";

import "../../core/app_text_styles.dart";
import "../../core/app_theme.dart";
import "../duty/duty_session_models.dart";
import "loan_models.dart";

/// Due-date group header for the member loans list.
class LoanDueDateHeader extends StatelessWidget {
  const LoanDueDateHeader({
    super.key,
    required this.dueDate,
    required this.isOverdue,
    this.isDueToday = false,
    this.embedded = false,
  });

  final DateTime dueDate;
  final bool isOverdue;
  final bool isDueToday;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final background = isOverdue
        ? const Color(0xFFFFEBEE)
        : kGroupHeaderBackground;
    final borderColor = isOverdue
        ? colors.error.withValues(alpha: 0.35)
        : kGroupHeaderBorder;
    final iconColor =
        isOverdue ? colors.error : kBrandOnYellow.withValues(alpha: 0.72);
    final dateColor = isOverdue ? const Color(0xFFC62828) : colors.onSurface;

    final content = Row(
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
                formatSessionDate(dueDate),
                style: context.cardTitle.copyWith(
                  color: dateColor,
                  fontSize: 17,
                ),
              ),
            ],
          ),
        ),
        if (isDueToday)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3C4),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              "Due today",
              style: TextStyle(
                color: Color(0xFFE65100),
                fontWeight: FontWeight.w700,
                fontSize: 11,
                decoration: TextDecoration.none,
              ),
            ),
          )
        else if (isOverdue)
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
    );

    final decoration = BoxDecoration(
      color: background,
      border: embedded
          ? Border(
              bottom: BorderSide(
                color: isOverdue
                    ? colors.error.withValues(alpha: 0.25)
                    : colors.outlineVariant.withValues(alpha: 0.5),
              ),
            )
          : Border.all(color: borderColor),
      borderRadius: embedded ? null : BorderRadius.circular(12),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(0, embedded ? 0 : 4, 0, embedded ? 0 : 10),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: embedded ? 14 : 12,
          vertical: embedded ? 12 : 10,
        ),
        decoration: decoration,
        child: content,
      ),
    );
  }
}
