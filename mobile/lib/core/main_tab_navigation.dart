import "package:flutter/material.dart";

import "auth_store.dart";

/// Main bottom-tab switches requested from nested routes (e.g. profile → Contact).
class MainTabNavigation extends ChangeNotifier {
  int generation = 0;
  int? pendingTabIndex;
  int scrollPaymentsToken = 0;
  TabController? _tabController;

  /// Called from [_RoleHome] so nested routes can switch main tabs.
  void bindTabController(TabController controller) {
    if (!identical(_tabController, controller)) {
      _tabController = controller;
    }
    _applyPendingContactTab();
  }

  void openContactPayments(int tabIndex) {
    pendingTabIndex = tabIndex;
    notifyListeners();
    _applyPendingContactTab();
  }

  void _applyPendingContactTab() {
    final tabIndex = pendingTabIndex;
    final controller = _tabController;
    if (tabIndex == null || controller == null) return;
    if (tabIndex < 0 || tabIndex >= controller.length) {
      pendingTabIndex = null;
      return;
    }

    pendingTabIndex = null;
    final requestGeneration = generation;

    controller.animateTo(tabIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 350), () {
        if (generation != requestGeneration) return;
        completeContactPaymentsScroll();
      });
    });
  }

  void completeContactPaymentsScroll() {
    scrollPaymentsToken++;
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
