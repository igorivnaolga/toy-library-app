import "../../core/auth_store.dart";

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
