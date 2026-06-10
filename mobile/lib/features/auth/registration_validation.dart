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
  static final RegExp addressLine = RegExp(
    r"^[A-Za-z0-9][A-Za-z0-9\s,.#/''-]{2,119}$",
  );
  static final RegExp suburb = RegExp(r"^[A-Za-z][A-Za-z\s'.-]{1,79}$");
  static final RegExp phoneChars = RegExp(r"^[\d\s()+\-.]{7,20}$");
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
    return null;
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
    if (trimmed.isEmpty) return "Enter your mobile phone number.";
    return _nzPhoneError(trimmed);
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
    var digits = trimmed.replaceAll(RegExp(r"\D"), "");
    if (digits.startsWith("64")) {
      digits = digits.substring(2);
    }
    if (digits.startsWith("0")) {
      digits = digits.substring(1);
    }
    if (digits.length < 8 || digits.length > 11) {
      return "Enter a valid New Zealand phone number.";
    }
    return null;
  }
}
