import "package:flutter/foundation.dart";

import "auth_store.dart";

/// Main bottom-tab switches requested from nested routes (e.g. profile → Contact).
class MainTabNavigation extends ChangeNotifier {
  int generation = 0;
  int? pendingTabIndex;
  int scrollPaymentsToken = 0;

  void openContactPayments(int tabIndex) {
    pendingTabIndex = tabIndex;
    notifyListeners();
  }

  void completeContactPaymentsScroll() {
    scrollPaymentsToken++;
    pendingTabIndex = null;
    notifyListeners();
  }

  void reset() {
    generation++;
    pendingTabIndex = null;
    scrollPaymentsToken = 0;
    notifyListeners();
  }
}

int? contactTabIndexForRole(AppRole role) {
  switch (role) {
    case AppRole.member:
      return 3;
    case AppRole.volunteer:
      return 4;
    case AppRole.guest:
      return 1;
    case AppRole.admin:
      return null;
  }
}
