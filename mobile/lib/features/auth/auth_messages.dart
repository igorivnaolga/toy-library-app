import "package:flutter/material.dart";

Future<void> showAuthSuccessDialog(
  BuildContext context, {
  required String title,
  required String message,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text("OK"),
        ),
      ],
    ),
  );
}

String signedInMessage({required bool needsMembershipOnboarding}) {
  if (needsMembershipOnboarding) {
    return "You are signed in. Tap Choose membership on the catalog to finish "
        "setting up your account.";
  }
  return "Welcome back! You are signed in to Church Corner Toy Library.";
}

const accountCreatedMessage =
    "Your account was created and you are signed in. "
    "Tap Choose membership on the catalog to finish setting up your account.";

const emailConfirmationMessage =
    "We sent a confirmation link to your email. "
    "Open it, then return here and sign in with your password.";
