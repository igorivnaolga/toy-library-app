import "package:flutter/material.dart";

import "../../core/app_text_styles.dart";
import "../../core/app_theme.dart";

/// Selectable membership tier row (onboarding and info screens).
class MembershipTierCard extends StatelessWidget {
  const MembershipTierCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.selected = false,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: kMembershipTierCardBg,
      surfaceTintColor: Colors.transparent,
      elevation: selected ? 1 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.cardTitle),
              const SizedBox(height: 8),
              Text(subtitle, style: context.listSubtitle),
            ],
          ),
        ),
      ),
    );
  }
}
