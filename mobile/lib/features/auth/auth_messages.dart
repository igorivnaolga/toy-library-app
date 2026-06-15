import "package:flutter/material.dart";

import "../../core/app_text_styles.dart";

Future<void> showAuthSuccessDialog(
  BuildContext context, {
  required String title,
  String? message,
  Widget? content,
}) {
  assert(message != null || content != null);
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: content ?? Text(message!),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text("OK"),
        ),
      ],
    ),
  );
}

String _firstName(String? fullName) {
  final trimmed = fullName?.trim() ?? "";
  if (trimmed.isEmpty) return "";
  return trimmed.split(RegExp(r"\s+")).first;
}

/// First name for welcome greetings.
String signedInFirstName(String? fullName) => _firstName(fullName);

/// Branded sign-in greeting with the member's first name highlighted.
class SignedInWelcomeContent extends StatelessWidget {
  const SignedInWelcomeContent({
    super.key,
    required this.needsMembershipOnboarding,
    this.fullName,
  });

  final bool needsMembershipOnboarding;
  final String? fullName;

  @override
  Widget build(BuildContext context) {
    final name = _firstName(fullName);
    final followUp = needsMembershipOnboarding
        ? "You are signed in. Tap Choose membership on the catalog "
            "to finish setting up your account."
        : "You are signed in to Church Corner Toy Library.";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (name.isEmpty)
          Text("Welcome back!", style: context.detailTitle)
        else
          WelcomeNameBanner(leadIn: "Welcome back,", name: name),
        const SizedBox(height: 12),
        Text(followUp, style: context.bodyText),
      ],
    );
  }
}

class WelcomeNameBanner extends StatelessWidget {
  const WelcomeNameBanner({
    super.key,
    required this.leadIn,
    required this.name,
  });

  final String leadIn;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          leadIn,
          style: context.sectionHeader.copyWith(fontSize: 15),
        ),
        const SizedBox(height: 4),
        Text(name, style: context.detailTitle),
      ],
    );
  }
}

String signedInMessage({
  required bool needsMembershipOnboarding,
  String? fullName,
}) {
  final name = _firstName(fullName);
  final greeting = name.isEmpty ? "Welcome back!" : "Welcome back, $name!";

  if (needsMembershipOnboarding) {
    return "$greeting You are signed in. Tap Choose membership on the catalog "
        "to finish setting up your account.";
  }
  return "$greeting You are signed in to Church Corner Toy Library.";
}

const accountCreatedMessage =
    "Your account was created and you are signed in. "
    "Tap Choose membership on the catalog to finish setting up your account.";

const emailConfirmationMessage =
    "We sent a confirmation link to your email. "
    "Open it, then return here and sign in with your password.";
