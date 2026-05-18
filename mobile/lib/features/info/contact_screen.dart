import "package:flutter/material.dart";

import "info_section_screen.dart";
import "library_info_copy.dart";

/// Library welcome, opening hours, and how to reach us.
class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const InfoSectionScreen(
      title: LibraryInfoCopy.welcomeTitle,
      body: LibraryInfoCopy.welcomeBody,
      sections: [
        (
          heading: LibraryInfoCopy.openingHoursTitle,
          text: LibraryInfoCopy.openingHoursBody,
        ),
        (heading: LibraryInfoCopy.contactTitle, text: LibraryInfoCopy.contactBody),
        (heading: LibraryInfoCopy.locationTitle, text: LibraryInfoCopy.locationBody),
        (heading: LibraryInfoCopy.paymentsTitle, text: LibraryInfoCopy.paymentsBody),
      ],
    );
  }
}
