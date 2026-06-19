/// Static copy for Church Corner Toy Library (from organisation materials).
abstract final class LibraryInfoCopy {
  static const libraryName = "Church Corner Toy Library";
  static const appBarTitle = "Church Corner Toy Library";

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

  static const dutyMembershipDescription =
      "Become one of our fantastic volunteers. Help out in the library "
      "3 times a year and pay a reduced fee of \$65. Plus each time you "
      "volunteer we give you a \$5 credit towards your hire.";

  static const nonDutyMembershipDescription =
      "No time to help out? No problem. Full membership is \$150 for the year.";

  static const casualMembershipDescription =
      "5 visits per year for \$50 (+\$50 refundable bond). This suits "
      "out-of-town relatives/Grandparents.";

  static const membershipTiers = """
Duty membership — $dutyMembershipDescription

Non-duty membership — $nonDutyMembershipDescription

Casual membership — $casualMembershipDescription""";

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
  static const locationAddressHint = "Next to Woolworths";

  /// Used when opening Google Maps (name + address pins more reliably than lat/lng alone).
  static const locationMapsQuery =
      "Church Corner Toy Library, Sir John McKenzie Memorial Building, "
      "393 Riccarton Road, Upper Riccarton, Christchurch, New Zealand";

  static const locationLat = -43.53799;
  static const locationLng = 172.60439;

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

  static const paymentsBody =
      "Pay at the library (cash or EFTPOS), or by bank transfer using the "
      "details below.";

  /// Update with your library's real account before production use.
  static const bankAccountName = "Church Corner Toy Library";
  static const bankAccountNumber = "12-3456-0123456-00";

  static const bankTransferReferenceHint =
      "Use the email address on your membership account as the payment reference.";
}
