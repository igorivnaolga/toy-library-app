import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "auth_messages.dart";
import "../../core/app_text_styles.dart";
import "../../core/auth_store.dart";
import "../../core/brand_chip_button.dart";
import "../info/library_info_copy.dart";
import "../payments/payment_instructions_card.dart";
import "../payments/payment_models.dart";

/// Shown once after registration: payment information and link to book toys.
class RegistrationWelcomeScreen extends StatelessWidget {
  const RegistrationWelcomeScreen({super.key});

  void _finish(BuildContext context) {
    context.read<AuthStore>().dismissPostRegistrationWelcome();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();
    final theme = Theme.of(context);
    final dueLabel = auth.membershipDueCents > 0
        ? formatDueCents(auth.membershipDueCents)
        : null;
    final firstName = signedInFirstName(auth.fullName);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Welcome"),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          if (firstName.isEmpty)
            Text(
              "Welcome to ${LibraryInfoCopy.libraryName}!",
              style: context.detailTitle,
            )
          else
            WelcomeNameBanner(leadIn: "Welcome,", name: firstName),
          const SizedBox(height: 12),
          Text(
            "Your membership is set up. You can browse the toy catalog and "
            "book toys straight away.",
            style: context.bodyText,
          ),
          if (dueLabel != null) ...[
            const SizedBox(height: 12),
            Text(
              "Membership fee due: $dueLabel",
              style: context.bodyText.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 24),
          Text("How to pay", style: context.sectionHeader),
          const SizedBox(height: 10),
          PaymentInstructionsCard(
            amountDueCents: auth.membershipDueCents,
            memberEmail: auth.email,
            compact: true,
            showBookingHint: true,
          ),
          const SizedBox(height: 12),
          Material(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                "Pay at the library with cash or EFTPOS during opening hours, "
                "or use bank transfer with the details above. "
                "Opening hours are on the Contact tab.",
                style: context.bodyText,
              ),
            ),
          ),
          const SizedBox(height: 28),
          BrandChipButton(
            label: "Browse toys & book",
            large: true,
            onPressed: () => _finish(context),
          ),
        ],
      ),
    );
  }
}
