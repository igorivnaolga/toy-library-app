import "package:flutter/material.dart";

import "../../core/app_theme.dart";
import "../../core/auth_store.dart";

class MembershipBadgeStyle {
  const MembershipBadgeStyle({
    required this.background,
    required this.foreground,
    this.border,
  });

  final Color background;
  final Color foreground;
  final BoxBorder? border;
}

MembershipBadgeStyle membershipBadgeStyle({
  required String label,
  Color? tierForeground,
  required ColorScheme colors,
}) {
  if (label == "Volunteer") {
    return const MembershipBadgeStyle(
      background: kBrandYellow,
      foreground: kBrandOnYellow,
    );
  }
  if (tierForeground != null) {
    return MembershipBadgeStyle(
      background: tierForeground.withValues(alpha: 0.12),
      foreground: tierForeground,
      border: Border.all(color: tierForeground.withValues(alpha: 0.28)),
    );
  }
  return MembershipBadgeStyle(
    background: colors.primaryContainer,
    foreground: colors.onPrimaryContainer,
  );
}
String membershipTierLabel(String? tier) {
  switch ((tier ?? "").trim()) {
    case "casual":
      return "Casual";
    case "non_duty":
      return "Non-duty member";
    case "duty":
      return "Duty volunteer";
    default:
      return "Not set";
  }
}

String appRoleLabel(AppRole role) {
  switch (role) {
    case AppRole.member:
      return "Member";
    case AppRole.volunteer:
      return "Volunteer";
    case AppRole.admin:
      return "Admin";
    case AppRole.guest:
      return "Guest";
  }
}

/// Single membership line for the profile screen.
String membershipSummaryLabel({
  required AppRole role,
  required String? membershipTier,
}) {
  if (role == AppRole.admin) return "Admin";
  if (role == AppRole.volunteer) return "Volunteer";
  if (role == AppRole.guest) return "Guest";
  return membershipTierLabel(membershipTier);
}
