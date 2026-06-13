import "package:flutter/material.dart";

import "../../core/app_text_styles.dart";
import "payment_models.dart";

/// Reminder for members who can book but still owe membership fees.
class MembershipFeeBanner extends StatelessWidget {
  const MembershipFeeBanner({
    super.key,
    required this.membershipDueCents,
  });

  final int membershipDueCents;

  @override
  Widget build(BuildContext context) {
    if (membershipDueCents <= 0) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final dueLabel = formatDueCents(membershipDueCents);

    return Material(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline,
              size: 22,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Membership fee $dueLabel is still due — pay at the library "
                "or by bank transfer (see Membership tab). You can book toys now.",
                style: context.bodyText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
