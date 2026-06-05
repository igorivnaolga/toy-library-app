import "package:flutter/material.dart";

import "../../core/app_text_styles.dart";
import "../../core/app_theme.dart";
import "admin_models.dart";

/// Branded from/to date range filter used on admin list screens.
class AdminDateFilterGroup extends StatelessWidget {
  const AdminDateFilterGroup({
    super.key,
    required this.title,
    required this.from,
    required this.to,
    required this.onFromTap,
    required this.onToTap,
    this.onFromClear,
    this.onToClear,
  });

  final String title;
  final DateTime? from;
  final DateTime? to;
  final VoidCallback onFromTap;
  final VoidCallback onToTap;
  final VoidCallback? onFromClear;
  final VoidCallback? onToClear;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: context.sectionHeader.copyWith(
              fontSize: 13,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: AdminDateFilterChip(
                  label: "From",
                  date: from,
                  onTap: onFromTap,
                  onClear: onFromClear,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AdminDateFilterChip(
                  label: "To",
                  date: to,
                  onTap: onToTap,
                  onClear: onToClear,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AdminDateFilterChip extends StatelessWidget {
  const AdminDateFilterChip({
    super.key,
    required this.label,
    required this.date,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final active = date != null;
    final chipLabel = active ? "$label · ${formatAdminDate(date)}" : label;

    return Material(
      color: active
          ? colors.primaryContainer.withValues(alpha: 0.45)
          : colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: active ? kBrandYellow : colors.outlineVariant,
          width: active ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  chipLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: context.listSubtitle.copyWith(
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              if (active && onClear != null) ...[
                const SizedBox(width: 4),
                InkWell(
                  onTap: onClear,
                  customBorder: const CircleBorder(),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
