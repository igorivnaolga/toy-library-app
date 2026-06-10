import "../profile/kid_profile.dart";

/// In-memory state for the paper membership form during registration.
class RegistrationFormData {
  RegistrationFormData({
    DateTime? registeredAt,
    this.parentAName = "",
    this.parentBName = "",
    this.addressLine1 = "",
    this.addressLine2 = "",
    this.suburb = "",
    this.mobilePhone = "",
    this.email = "",
    List<KidProfile>? kids,
    this.altContactName = "",
    this.altContactAddress = "",
    this.altContactPhone = "",
    this.heardAboutUs = "",
    this.skills = "",
    this.membershipTier,
    this.textRemindersConsent,
    this.termsAccepted = false,
    this.liabilityAccepted = false,
  })  : registeredAt = registeredAt ?? DateTime.now(),
        kids = kids ?? const [];

  DateTime registeredAt;
  String parentAName;
  String parentBName;
  String addressLine1;
  String addressLine2;
  String suburb;
  String mobilePhone;
  String email;
  List<KidProfile> kids;
  String altContactName;
  String altContactAddress;
  String altContactPhone;
  String heardAboutUs;
  String skills;
  String? membershipTier;
  bool? textRemindersConsent;
  bool termsAccepted;
  bool liabilityAccepted;

  Map<String, dynamic> toRegistrationJson() {
    return {
      "full_name": parentAName.trim(),
      "parent_b_name": _optional(parentBName),
      "address_line1": _optional(addressLine1),
      "address_line2": _optional(addressLine2),
      "suburb": _optional(suburb),
      "mobile_phone": _optional(mobilePhone),
      "alt_contact_name": _optional(altContactName),
      "alt_contact_address": _optional(altContactAddress),
      "alt_contact_phone": _optional(altContactPhone),
      "heard_about_us": _optional(heardAboutUs),
      "skills": _optional(skills),
      "kids": kids.map((kid) => kid.toJson()).toList(),
      "membership_tier": membershipTier,
      "text_reminders_consent": textRemindersConsent,
      "registered_at": _formatDate(registeredAt),
      "terms_accepted": termsAccepted,
      "liability_accepted": liabilityAccepted,
    };
  }

  String? _optional(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, "0");
    final m = date.month.toString().padLeft(2, "0");
    final d = date.day.toString().padLeft(2, "0");
    return "$y-$m-$d";
  }
}
