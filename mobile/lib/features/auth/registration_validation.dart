/// Regex validation for the membership registration form.
class RegistrationValidation {
  RegistrationValidation._();

  static final RegExp fullName = RegExp(
    r"^[A-Za-z][A-Za-z\s'.-]{2,98}\s+[A-Za-z][A-Za-z\s'.-]{1,99}$",
  );
  static final RegExp personName = RegExp(r"^[A-Za-z][A-Za-z\s'.-]{1,99}$");
  static final RegExp email = RegExp(
    r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$",
  );

  /// Common misspellings of well-known email domains (lowercase keys).
  static const Map<String, String> _emailProviderTypos = {
    "gmal.com": "gmail.com",
    "gmial.com": "gmail.com",
    "gamil.com": "gmail.com",
    "gnail.com": "gmail.com",
    "gmai.com": "gmail.com",
    "gmail.con": "gmail.com",
    "gmail.co": "gmail.com",
    "gmail.cm": "gmail.com",
    "gmail.om": "gmail.com",
    "hotmial.com": "hotmail.com",
    "hotmal.com": "hotmail.com",
    "hotmil.com": "hotmail.com",
    "homail.com": "hotmail.com",
    "hotmail.con": "hotmail.com",
    "outlok.com": "outlook.com",
    "outllok.com": "outlook.com",
    "outllook.com": "outlook.com",
    "outlook.con": "outlook.com",
    "yaho.com": "yahoo.com",
    "yahooo.com": "yahoo.com",
    "yahoo.con": "yahoo.com",
    "icloud.con": "icloud.com",
    "iclod.com": "icloud.com",
    "live.con": "live.com",
    "liv.com": "live.com",
    "protonmail.con": "protonmail.com",
    "protonmai.com": "protonmail.com",
  };

  /// Well-known providers; used to catch close misspellings (e.g. gmial.com).
  static const _knownEmailProviders = [
    "gmail.com",
    "googlemail.com",
    "hotmail.com",
    "outlook.com",
    "yahoo.com",
    "yahoo.co.nz",
    "icloud.com",
    "live.com",
    "msn.com",
    "xtra.co.nz",
    "clear.net.nz",
    "protonmail.com",
    "proton.me",
  ];
  static final RegExp addressLine = RegExp(
    r"^[A-Za-z0-9][A-Za-z0-9\s,.#/''-]{2,119}$",
  );
  static final RegExp suburb = RegExp(r"^[A-Za-z][A-Za-z\s'.-]{1,79}$");
  static final RegExp phoneChars = RegExp(r"^[\d\s()+\-.]{7,20}$");
  /// NZ mobile national significant number (after +64 / leading 0 removed).
  static final RegExp nzMobileDigits = RegExp(r"^2[0-9]\d{6,7}$");
  /// NZ landline or mobile (after normalization).
  static final RegExp nzPhoneDigits = RegExp(r"^[234679]\d{7,8}$");
  static final RegExp freeText = RegExp(r"^[\s\S]{0,500}$");

  static String? requiredFullName(String? value, {String label = "Full name"}) {
    final trimmed = value?.trim() ?? "";
    if (trimmed.isEmpty) return "Enter $label.";
    if (!fullName.hasMatch(trimmed)) {
      return "Enter a valid $label (first and last name).";
    }
    return null;
  }

  static String? optionalFullName(String? value, {String label = "Full name"}) {
    final trimmed = value?.trim() ?? "";
    if (trimmed.isEmpty) return null;
    if (!fullName.hasMatch(trimmed)) {
      return "Enter a valid $label (first and last name).";
    }
    return null;
  }

  static String? requiredPersonName(String? value, {String label = "Name"}) {
    final trimmed = value?.trim() ?? "";
    if (trimmed.isEmpty) return "Enter $label.";
    if (!personName.hasMatch(trimmed)) {
      return "Enter a valid $label.";
    }
    return null;
  }

  static String? requiredEmail(String? value) {
    final trimmed = value?.trim() ?? "";
    if (trimmed.isEmpty) return "Enter your email address.";
    if (!email.hasMatch(trimmed)) {
      return "Enter a valid email address.";
    }
    return _emailProviderTypoMessage(trimmed);
  }

  static String? _emailProviderTypoMessage(String emailValue) {
    final at = emailValue.lastIndexOf("@");
    if (at <= 0 || at >= emailValue.length - 1) return null;
    final domain = emailValue.substring(at + 1).toLowerCase();
    final mapped = _emailProviderTypos[domain];
    if (mapped != null) {
      return "Did you mean $mapped? Check your email provider.";
    }
    final nearest = _nearestKnownProvider(domain);
    if (nearest != null) {
      return "Did you mean $nearest? Check your email provider.";
    }
    return null;
  }

  static String? _nearestKnownProvider(String domain) {
    if (_knownEmailProviders.contains(domain)) return null;
    String? best;
    var bestDistance = 999;
    for (final known in _knownEmailProviders) {
      final distance = _editDistance(domain, known);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = known;
      }
    }
    if (best != null && bestDistance > 0 && bestDistance <= 2) {
      return best;
    }
    return null;
  }

  static int _editDistance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final previous = List<int>.generate(b.length + 1, (index) => index);
    for (var i = 0; i < a.length; i++) {
      var corner = previous[0];
      previous[0] = i + 1;
      for (var j = 0; j < b.length; j++) {
        final upper = previous[j + 1];
        final cost = a.codeUnitAt(i) == b.codeUnitAt(j) ? 0 : 1;
        previous[j + 1] = [
          previous[j + 1] + 1,
          previous[j] + 1,
          corner + cost,
        ].reduce((left, right) => left < right ? left : right);
        corner = upper;
      }
    }
    return previous[b.length];
  }

  static String? requiredAddressLine(String? value) {
    final trimmed = value?.trim() ?? "";
    if (trimmed.isEmpty) return "Enter your street address.";
    if (!addressLine.hasMatch(trimmed)) {
      return "Enter a valid address.";
    }
    return null;
  }

  static String? optionalAddressLine(String? value) {
    final trimmed = value?.trim() ?? "";
    if (trimmed.isEmpty) return null;
    if (!addressLine.hasMatch(trimmed)) {
      return "Enter a valid address.";
    }
    return null;
  }

  static String? requiredSuburb(String? value) {
    final trimmed = value?.trim() ?? "";
    if (trimmed.isEmpty) return "Enter your suburb.";
    if (!suburb.hasMatch(trimmed)) {
      return "Enter a valid suburb.";
    }
    return null;
  }

  static String? requiredNzPhone(String? value) {
    final trimmed = value?.trim() ?? "";
    if (trimmed.isEmpty) return "Enter your phone number.";
    return _nzPhoneError(trimmed);
  }

  static String? requiredNzMobile(String? value) {
    final trimmed = value?.trim() ?? "";
    if (trimmed.isEmpty) return "Enter your mobile phone number.";
    return _nzMobileError(trimmed);
  }

  static String? optionalNzPhone(String? value) {
    final trimmed = value?.trim() ?? "";
    if (trimmed.isEmpty) return null;
    return _nzPhoneError(trimmed);
  }

  static String? requiredFreeText(String? value, {required String label}) {
    final trimmed = value?.trim() ?? "";
    if (trimmed.isEmpty) return "Enter $label.";
    if (!freeText.hasMatch(trimmed) || trimmed.length < 2) {
      return "Enter at least 2 characters for $label.";
    }
    return null;
  }

  static String? heardAboutUs(String? source, String otherText) {
    if (source == null || source.trim().isEmpty) {
      return "Choose how you heard about us.";
    }
    if (source == "other") {
      return requiredFreeText(otherText, label: "how you heard about us");
    }
    return null;
  }

  static String? optionalFreeText(String? value) {
    final trimmed = value?.trim() ?? "";
    if (trimmed.isEmpty) return null;
    if (!freeText.hasMatch(trimmed)) {
      return "Enter up to 500 characters.";
    }
    return null;
  }

  static String? _nzPhoneError(String trimmed) {
    if (!phoneChars.hasMatch(trimmed)) {
      return "Enter a valid phone number.";
    }
    final digits = normalizeNzPhoneDigits(trimmed);
    if (digits == null || !nzPhoneDigits.hasMatch(digits)) {
      return "Enter a valid New Zealand phone number (e.g. 021 123 4567).";
    }
    return null;
  }

  static String? _nzMobileError(String trimmed) {
    if (!phoneChars.hasMatch(trimmed)) {
      return "Enter a valid phone number.";
    }
    final digits = normalizeNzPhoneDigits(trimmed);
    if (digits == null || !nzMobileDigits.hasMatch(digits)) {
      return "Enter a valid New Zealand mobile number (e.g. 021 123 4567).";
    }
    return null;
  }

  /// Strips formatting and NZ country/leading-zero prefixes for validation.
  static String? normalizeNzPhoneDigits(String trimmed) {
    if (!phoneChars.hasMatch(trimmed)) return null;
    var digits = trimmed.replaceAll(RegExp(r"\D"), "");
    if (digits.startsWith("64")) {
      digits = digits.substring(2);
    }
    if (digits.startsWith("0")) {
      digits = digits.substring(1);
    }
    if (digits.length < 8 || digits.length > 9) {
      return null;
    }
    return digits;
  }
}
