import "package:flutter_test/flutter_test.dart";
import "package:toy_library_mobile/features/auth/password_validation.dart";

void main() {
  test("rejects password without symbol", () {
    expect(
      PasswordValidation.validate("Abcdefg1"),
      "Password must include at least one symbol (e.g. ! @ #).",
    );
  });

  test("accepts password meeting all rules", () {
    expect(PasswordValidation.validate("Abcdefg1!"), isNull);
  });

  test("generateStrongPassword passes validation", () {
    final password = PasswordValidation.generateStrongPassword();
    expect(PasswordValidation.validate(password), isNull);
    expect(password.length, PasswordValidation.suggestedPasswordLength);
  });
}
