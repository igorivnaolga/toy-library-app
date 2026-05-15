/// Root widget for the Flutter application.
library;

import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "core/api_client.dart";
import "core/auth_store.dart";
import "features/admin/admin_placeholder.dart";
import "features/auth/login_screen.dart";
import "features/bookings/bookings_placeholder.dart";
import "features/catalog/catalog_provider.dart";
import "features/catalog/catalog_screen.dart";
import "features/membership/membership_onboarding_screen.dart";

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
      ],
      child: MaterialApp(
        title: "Toy Library",
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          useMaterial3: true,
        ),
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
          title: const Text("Toy Library"),
          actions: [
            if (!auth.isLoggedIn)
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const LoginScreen()),
                  );
                },
                child: const Text("Sign in"),
              )
            else
              TextButton(
                onPressed: () => context.read<AuthStore>().signOut(),
                child: const Text("Sign out"),
              ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabs: _tabsForRole(auth.role)
                .map((t) => Tab(icon: Icon(t.$2), text: t.$1))
                .toList(),
          ),
        ),
        body: TabBarView(
          children: _screensForRole(auth.role),
        ),
      ),
    );
  }

  List<(String, IconData)> _tabsForRole(AppRole role) {
    switch (role) {
      case AppRole.admin:
        return const [
          ("Catalog", Icons.toys),
          ("Bookings", Icons.event_note),
          ("Admin", Icons.admin_panel_settings),
        ];
      case AppRole.volunteer:
      case AppRole.member:
        return const [
          ("Catalog", Icons.toys),
          ("Bookings", Icons.event_note),
        ];
      case AppRole.guest:
        return const [("Catalog", Icons.toys)];
    }
  }

  List<Widget> _screensForRole(AppRole role) {
    switch (role) {
      case AppRole.admin:
        return const [
          CatalogScreen(),
          BookingsPlaceholder(),
          AdminPlaceholder()
        ];
      case AppRole.volunteer:
      case AppRole.member:
        return const [CatalogScreen(), BookingsPlaceholder()];
      case AppRole.guest:
        return const [CatalogScreen()];
    }
  }
}
