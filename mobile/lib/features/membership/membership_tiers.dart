/// Membership tier labels shown in onboarding and the Membership tab.
class MembershipTierOption {
  const MembershipTierOption({
    required this.tier,
    required this.title,
    required this.subtitle,
  });

  final String tier;
  final String title;
  final String subtitle;
}

const membershipTierOptions = [
  MembershipTierOption(
    tier: "casual",
    title: "Casual",
    subtitle: "Browse and borrow with a standard member account.",
  ),
  MembershipTierOption(
    tier: "non_duty",
    title: "Non-duty member",
    subtitle: "Member without volunteer shifts.",
  ),
  MembershipTierOption(
    tier: "duty",
    title: "Duty volunteer",
    subtitle:
        "You intend to take volunteer shifts. An admin will confirm "
        "before volunteer tools unlock.",
  ),
];

/// Card title; "(pending)" only when this tier is the member's choice and
/// volunteer access is not confirmed yet.
String membershipTierCardTitle(
  MembershipTierOption option, {
  String? currentTier,
  bool volunteerConfirmed = false,
}) {
  if (option.tier == "duty" &&
      currentTier == "duty" &&
      !volunteerConfirmed) {
    return "Duty volunteer (pending)";
  }
  return option.title;
}
