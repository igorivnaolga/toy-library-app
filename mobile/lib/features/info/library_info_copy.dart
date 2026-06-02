/// Static copy for Church Corner Toy Library (from organisation materials).
abstract final class LibraryInfoCopy {
  static const libraryName = "Church Corner Toy Library";

  static const welcomeTitle = "Welcome to the Church Corner Toy Library";

  static const welcomeBody = """
The Church Corner Toy Library is a non-profit organisation run by members. We aim to provide a variety of good quality, safe, educational toys for children (aged 0 to 8) in our community, which will enhance their social, physical, cultural and emotional development.

We are a member of the Toy Library Federation of New Zealand (TLFNZ).""";

  static const openingHoursTitle = "Opening hours";

  static const openingHoursBody = """
Wednesdays — 1:00 pm to 2:30 pm

Saturdays — 11:30 am to 2:00 pm

Closed on public holidays and over the Christmas break.""";

  static const membershipTitle = "Membership";

  static const membershipIntro = """
Membership is open to families in our community. When you sign in to the app, you can choose a membership type that fits how you take part in the library.""";

  static const casualMembershipDescription =
      "Browse and borrow with a standard member account.";

  static const nonDutyMembershipDescription =
      "Full membership without volunteer shifts.";

  static const dutyMembershipDescription =
      "Members who take volunteer shifts. Duty members are confirmed by our committee before volunteer tools are enabled in the app.";

  static const membershipTiers = """
Casual — $casualMembershipDescription

Non-duty member — $nonDutyMembershipDescription

Duty volunteer — $dutyMembershipDescription""";

  static const membershipBody = """
$membershipIntro

$membershipTiers""";

  static const contactTitle = "Contact";

  static const contactBody = """
Please contact our coordinator on 027 358 3259.

Email: library@cctoylibrary.org.nz""";

  static const coordinatorPhone = "027 358 3259";
  static const coordinatorPhoneDial = "0273583259";
  static const coordinatorEmail = "library@cctoylibrary.org.nz";

  static const locationTitle = "Location";

  static const locationAddressLine1 = "Sir John McKenzie Memorial building";
  static const locationAddressLine2 = "393 Riccarton Road, Upper Riccarton";
  static const locationAddressHint = "Next to Countdown Church Corner";

  static const locationLat = -43.53803;
  static const locationLng = 172.60456;

  static const locationBody = """
$locationAddressLine1
393 Riccarton Road
Upper Riccarton
($locationAddressHint)""";

  static const openingHoursEntries = [
    ("Wednesday", "1:00 pm – 2:30 pm"),
    ("Saturday", "11:30 am – 2:00 pm"),
  ];

  static const paymentsTitle = "Payments";

  static const paymentsBody = "Cash and EFTPOS payments available.";
}
