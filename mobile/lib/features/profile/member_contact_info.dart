/// Contact and registration details from `/api/v1/auth/me`.
class MemberContactInfo {
  const MemberContactInfo({
    this.parentBName,
    this.addressLine1,
    this.addressLine2,
    this.suburb,
    this.mobilePhone,
    this.altContactName,
    this.altContactAddress,
    this.altContactPhone,
    this.heardAboutUs,
    this.skills,
    this.textRemindersConsent,
    this.registeredAt,
  });

  final String? parentBName;
  final String? addressLine1;
  final String? addressLine2;
  final String? suburb;
  final String? mobilePhone;
  final String? altContactName;
  final String? altContactAddress;
  final String? altContactPhone;
  final String? heardAboutUs;
  final String? skills;
  final bool? textRemindersConsent;
  final String? registeredAt;

  bool get hasAddress =>
      [addressLine1, addressLine2, suburb].any(
        (value) => value != null && value.trim().isNotEmpty,
      );

  bool get hasRegistrationDetails =>
      hasAddress ||
      (parentBName?.trim().isNotEmpty ?? false) ||
      (mobilePhone?.trim().isNotEmpty ?? false) ||
      (altContactName?.trim().isNotEmpty ?? false) ||
      (heardAboutUs?.trim().isNotEmpty ?? false) ||
      (skills?.trim().isNotEmpty ?? false);

  String get formattedAddress {
    final lines = <String>[
      if (addressLine1?.trim().isNotEmpty == true) addressLine1!.trim(),
      if (addressLine2?.trim().isNotEmpty == true) addressLine2!.trim(),
      if (suburb?.trim().isNotEmpty == true) suburb!.trim(),
    ];
    return lines.join("\n");
  }

  factory MemberContactInfo.fromJson(Map<String, dynamic> json) {
    final mobile = json["mobile_phone"]?.toString();
    final legacyHome = json["home_phone"]?.toString();
    return MemberContactInfo(
      parentBName: json["parent_b_name"]?.toString(),
      addressLine1: json["address_line1"]?.toString(),
      addressLine2: json["address_line2"]?.toString(),
      suburb: json["suburb"]?.toString(),
      mobilePhone: (mobile != null && mobile.isNotEmpty) ? mobile : legacyHome,
      altContactName: json["alt_contact_name"]?.toString(),
      altContactAddress: json["alt_contact_address"]?.toString(),
      altContactPhone: json["alt_contact_phone"]?.toString(),
      heardAboutUs: json["heard_about_us"]?.toString(),
      skills: json["skills"]?.toString(),
      textRemindersConsent: json["text_reminders_consent"] as bool?,
      registeredAt: json["registered_at"]?.toString(),
    );
  }

  Map<String, dynamic> toProfilePatchJson() {
    return {
      if (parentBName != null) "parent_b_name": parentBName,
      if (addressLine1 != null) "address_line1": addressLine1,
      if (addressLine2 != null) "address_line2": addressLine2,
      if (suburb != null) "suburb": suburb,
      if (mobilePhone != null) "mobile_phone": mobilePhone,
      if (altContactName != null) "alt_contact_name": altContactName,
      if (altContactAddress != null) "alt_contact_address": altContactAddress,
      if (altContactPhone != null) "alt_contact_phone": altContactPhone,
      if (heardAboutUs != null) "heard_about_us": heardAboutUs,
      if (skills != null) "skills": skills,
      if (textRemindersConsent != null)
        "text_reminders_consent": textRemindersConsent,
    };
  }
}
