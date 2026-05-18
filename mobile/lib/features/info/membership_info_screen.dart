import "package:flutter/material.dart";

import "info_section_screen.dart";
import "library_info_copy.dart";

class MembershipInfoScreen extends StatelessWidget {
  const MembershipInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const InfoSectionScreen(
      title: LibraryInfoCopy.membershipTitle,
      body: LibraryInfoCopy.membershipBody,
    );
  }
}
