import "../info/library_info_copy.dart";

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
    tier: "duty",
    title: "Duty membership",
    subtitle: LibraryInfoCopy.dutyMembershipDescription,
  ),
  MembershipTierOption(
    tier: "non_duty",
    title: "Non-duty membership",
    subtitle: LibraryInfoCopy.nonDutyMembershipDescription,
  ),
  MembershipTierOption(
    tier: "casual",
    title: "Casual membership",
    subtitle: LibraryInfoCopy.casualMembershipDescription,
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
    return "${option.title} (pending)";
  }
  return option.title;
}
