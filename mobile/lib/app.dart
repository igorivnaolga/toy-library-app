/// Root widget for the Flutter application.
library;

import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "core/api_client.dart";
import "core/app_theme.dart";
import "core/auth_store.dart";
import "features/admin/admin_placeholder.dart";
import "features/auth/login_screen.dart";
import "features/bookings/bookings_controller.dart";
import "features/bookings/bookings_screen.dart";
import "features/catalog/catalog_provider.dart";
import "features/loans/loans_controller.dart";
import "features/loans/loans_screen.dart";
import "features/catalog/catalog_screen.dart";
import "features/duty/duty_controller.dart";
import "features/duty/duty_screen.dart";
import "features/info/contact_screen.dart";
import "features/info/library_info_copy.dart";
import "features/info/membership_info_screen.dart";
import "features/membership/membership_onboarding_screen.dart";
import "features/profile/profile_avatar.dart";
import "features/profile/profile_controller.dart";
import "features/profile/profile_screen.dart";

class ToyLibraryApp extends StatelessWidget {
  const ToyLibraryApp({super.key, this.backend, this.authStore});

  /// Optional backend for tests.
  final BackendClient? backend;

  /// Optional auth store for tests/previews.
  final AuthStore? authStore;

  @override
  Widget build(BuildContext context) {
    late final AuthStore auth;
    final client = backend ?? ApiClient(tokenProvider: () => auth.accessToken);

    if (authStore != null) {
      auth = authStore!;
    } else {
      try {
        auth = AuthStore.supabase(client);
      } catch (_) {
        // Useful for tests or when SUPABASE_* dart-defines aren't set yet.
        auth = AuthStore.guest();
      }
    }

    return MultiProvider(
      providers: [
        Provider<BackendClient>.value(value: client),
        ChangeNotifierProvider<AuthStore>.value(value: auth),
        ChangeNotifierProvider(create: (_) => CatalogController(client)),
        ChangeNotifierProvider(create: (_) => BookingsController(client)),
        ChangeNotifierProvider(create: (_) => LoansController(client)),
        ChangeNotifierProvider(create: (_) => DutyController(client)),
        ChangeNotifierProxyProvider2<BackendClient, AuthStore, ProfileController>(
          create: (context) => ProfileController(
            context.read<BackendClient>(),
            context.read<AuthStore>(),
          )..syncFromAuth(),
          update: (_, client, auth, previous) {
            final controller =
                previous ?? ProfileController(client, auth);
            controller.syncFromAuth();
            return controller;
          },
        ),
      ],
      child: MaterialApp(
        title: "Toy Library",
        theme: buildAppTheme(),
        home: const _AppShell(),
      ),
    );
  }
}

class _AppShell extends StatelessWidget {
  const _AppShell();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();

    if (auth.isLoggedIn && auth.profileLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (auth.needsMembershipOnboarding) {
      return const MembershipOnboardingScreen();
    }

    return const _RoleHome();
  }
}

class _RoleHome extends StatelessWidget {
  const _RoleHome();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();

    return DefaultTabController(
      length: _tabsForRole(auth.role).length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            LibraryInfoCopy.libraryName,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            if (!auth.isLoggedIn)
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const LoginScreen()),
                  );
                },
                style: TextButton.styleFrom(
                  foregroundColor: kBrandOnYellow,
                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
                ),
                child: const Text("Sign in"),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ProfileAvatar(
                  fullName: auth.fullName,
                  avatarPath: auth.avatarPath,
                  radius: 18,
                  onTap: () {
                    context.read<ProfileController>().syncFromAuth();
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ProfileScreen(),
                      ),
                    );
                  },
                ),
              ),
          ],
          bottom: TabBar(
            isScrollable: false,
            tabAlignment: TabAlignment.fill,
            labelPadding: EdgeInsets.zero,
            tabs: _tabsForRole(auth.role)
                .map((t) => Tab(
                      height: 56,
                      icon: Icon(t.$2, size: 22),
                      text: t.$1,
                      iconMargin: const EdgeInsets.only(bottom: 2),
                    ))
                .toList(),
          ),
        ),
        body: TabBarView(
          children: _screensForRole(auth.role),
        ),
      ),
    );
  }

  static const _infoTabs = [
    ("Contact", Icons.contact_page_outlined),
    ("Membership", Icons.card_membership),
  ];

  static const _infoScreens = [
    ContactScreen(),
    MembershipInfoScreen(),
  ];

  List<(String, IconData)> _tabsForRole(AppRole role) {
    const catalog = ("Catalog", Icons.toys);
    const bookings = ("Bookings", Icons.event_note);
    const loans = ("Loans", Icons.autorenew);
    const duty = ("Duty", Icons.event_available);
    const admin = ("Admin", Icons.admin_panel_settings);

    switch (role) {
      case AppRole.admin:
        return const [catalog, bookings, loans, duty, ..._infoTabs, admin];
      case AppRole.volunteer:
        return const [catalog, bookings, loans, duty, ..._infoTabs];
      case AppRole.member:
        return const [catalog, bookings, loans, ..._infoTabs];
      case AppRole.guest:
        return const [catalog, ..._infoTabs];
    }
  }

  List<Widget> _screensForRole(AppRole role) {
    switch (role) {
      case AppRole.admin:
        return const [
          CatalogScreen(),
          BookingsScreen(),
          LoansScreen(),
          DutyScreen(),
          ..._infoScreens,
          AdminPlaceholder(),
        ];
      case AppRole.volunteer:
        return const [
          CatalogScreen(),
          BookingsScreen(),
          LoansScreen(),
          DutyScreen(),
          ..._infoScreens,
        ];
      case AppRole.member:
        return const [
          CatalogScreen(),
          BookingsScreen(),
          LoansScreen(),
          ..._infoScreens,
        ];
      case AppRole.guest:
        return const [CatalogScreen(), ..._infoScreens];
    }
  }
}
