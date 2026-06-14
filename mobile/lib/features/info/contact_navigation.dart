import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../core/auth_store.dart";
import "../../core/main_tab_navigation.dart";
import "contact_screen.dart";
import "library_info_copy.dart";

/// Opens the Contact tab (or a contact route) scrolled to payment details.
void openContactPaymentDetails(BuildContext context) {
  final auth = context.read<AuthStore>();
  final tabNav = context.read<MainTabNavigation>();
  final tabIndex = contactTabIndexForRole(auth.role);
  final navigator = Navigator.of(context);
  final poppedProfile = navigator.canPop();

  if (tabIndex != null) {
    if (poppedProfile) {
      navigator.pop();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      tabNav.openContactPayments(tabIndex);
    });
    return;
  }

  if (poppedProfile) {
    navigator.pop();
  }
  navigator.push(
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text(LibraryInfoCopy.contactTitle)),
        body: const ContactScreen(scrollToPaymentsOnMount: true),
      ),
    ),
  );
}
