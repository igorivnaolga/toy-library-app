import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../core/app_text_styles.dart";
import "../../core/auth_store.dart";
import "../../core/brand_chip_button.dart";
import "../info/library_info_copy.dart";
import "../payments/payment_instructions_card.dart";
import "../payments/payment_models.dart";

/// Shown once after registration: payment options and link to book toys.
class RegistrationWelcomeScreen extends StatefulWidget {
  const RegistrationWelcomeScreen({super.key});

  @override
  State<RegistrationWelcomeScreen> createState() =>
      _RegistrationWelcomeScreenState();
}

class _RegistrationWelcomeScreenState extends State<RegistrationWelcomeScreen> {
  String? _paymentChoice;

  void _finish() {
    context.read<AuthStore>().dismissPostRegistrationWelcome();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();
    final theme = Theme.of(context);
    final dueLabel = auth.membershipDueCents > 0
        ? formatDueCents(auth.membershipDueCents)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Welcome"),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(
            "Welcome to ${LibraryInfoCopy.libraryName}!",
            style: context.detailTitle,
          ),
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
          Text("How would you like to pay?", style: context.sectionHeader),
          const SizedBox(height: 10),
          _PaymentChoiceTile(
            value: "library",
            groupValue: _paymentChoice,
            icon: Icons.storefront_outlined,
            title: "Pay at the library",
            subtitle:
                "Cash or EFTPOS during opening hours (Wednesdays and Saturdays).",
            onSelected: (value) => setState(() => _paymentChoice = value),
          ),
          const SizedBox(height: 8),
          _PaymentChoiceTile(
            value: "bank",
            groupValue: _paymentChoice,
            icon: Icons.account_balance_outlined,
            title: "Pay by bank transfer",
            subtitle: "Transfer from your bank using the details below.",
            onSelected: (value) => setState(() => _paymentChoice = value),
          ),
          const SizedBox(height: 16),
          PaymentInstructionsCard(
            amountDueCents: auth.membershipDueCents,
            memberEmail: auth.email,
            compact: true,
            showBookingHint: true,
          ),
          if (_paymentChoice == "library") ...[
            const SizedBox(height: 12),
            Material(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  "Bring your payment to the desk at your first visit. "
                  "Opening hours are on the Contact tab.",
                  style: context.bodyText,
                ),
              ),
            ),
          ],
          const SizedBox(height: 28),
          BrandChipButton(
            label: "Browse toys & book",
            large: true,
            onPressed: _finish,
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _finish,
            child: const Text("Skip for now"),
          ),
        ],
      ),
    );
  }
}

class _PaymentChoiceTile extends StatelessWidget {
  const _PaymentChoiceTile({
    required this.value,
    required this.groupValue,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onSelected,
  });

  final String value;
  final String? groupValue;
  final IconData icon;
  final String title;
  final String subtitle;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = groupValue == value;

    return Material(
      color: selected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.45)
          : theme.colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.65),
          width: selected ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onSelected(value),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Radio<String>(
                value: value,
                groupValue: groupValue,
                onChanged: (picked) {
                  if (picked != null) onSelected(picked);
                },
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, size: 20, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(title, style: context.cardTitle),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle, style: context.listSubtitle),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
