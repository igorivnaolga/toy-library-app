import "package:flutter/material.dart";

import "../../core/app_theme.dart";
import "loan_due_date_header.dart";
import "loan_models.dart";

/// Groups a due-date header with its loan rows in one branded card.
class LoanDueDateSection extends StatelessWidget {
  const LoanDueDateSection({
    super.key,
    required this.group,
    required this.children,
    this.onHeaderTap,
  });

  final LoanDueDateGroup group;
  final List<Widget> children;
  final VoidCallback? onHeaderTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: kModalSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.65)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (onHeaderTap == null)
            LoanDueDateHeader(
              dueDate: group.dueDate,
              isOverdue: group.isOverdue,
              isDueToday: group.isDueToday,
              embedded: true,
            )
          else
            InkWell(
              onTap: onHeaderTap,
              child: Row(
                children: [
                  Expanded(
                    child: LoanDueDateHeader(
                      dueDate: group.dueDate,
                      isOverdue: group.isOverdue,
                      isDueToday: group.isDueToday,
                      embedded: true,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      Icons.chevron_right,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 17,
                      thickness: 1,
                      color: colors.outlineVariant.withValues(alpha: 0.55),
                    ),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
