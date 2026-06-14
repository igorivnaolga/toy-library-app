import "package:flutter/material.dart";

import "../../core/app_text_styles.dart";
import "member_contact_info.dart";

/// Read-only registration contact fields (profile + admin member view).
class ContactDetailsBody extends StatelessWidget {
  const ContactDetailsBody({super.key, required this.contact});

  final MemberContactInfo contact;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[];
    void add(String label, String? value) {
      final trimmed = value?.trim();
      if (trimmed == null || trimmed.isEmpty) return;
      rows.add((label, trimmed));
    }

    add("Parent B", contact.parentBName);
    if (contact.hasAddress) add("Address", contact.formattedAddress);
    add("Mobile phone", contact.mobilePhone);
    add("Emergency contact", contact.altContactName);
    add("Emergency address", contact.altContactAddress);
    add("Emergency phone", contact.altContactPhone);
    add("How you heard about us", contact.heardAboutUs);
    add("Skills you can offer", contact.skills);
    if (contact.textRemindersConsent != null) {
      add(
        "Text reminders",
        contact.textRemindersConsent! ? "Yes" : "No",
      );
    }

    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Text(
          "No contact details on file.",
          style: context.profileSecondary,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            Text(rows[i].$1, style: context.formSectionLabel),
            const SizedBox(height: 4),
            Text(rows[i].$2, style: context.listSubtitle),
          ],
        ],
      ),
    );
  }
}
