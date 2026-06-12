/// Root widget for the Flutter application.
library;

import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "dart:async";

import "core/api_client.dart";
import "core/app_theme.dart";
import "core/auth_store.dart";
import "core/reminder_sync.dart";
import "core/library_app_bar_title.dart";
import "features/admin/admin_bookings_screen.dart";
import "features/admin/admin_controller.dart";
import "features/admin/admin_loans_screen.dart";
import "features/admin/admin_members_screen.dart";
import "features/admin/admin_statistics_screen.dart";
import "features/admin/admin_notifications_sheet.dart";
import "features/auth/login_screen.dart";
import "features/bookings/bookings_controller.dart";
import "features/bookings/bookings_screen.dart";
import "features/catalog/catalog_provider.dart";
import "features/loans/loans_controller.dart";
import "features/loans/loans_screen.dart";
import "features/catalog/catalog_screen.dart";
import "features/duty/duty_controller.dart";
import "features/duty/volunteer_duty_tab_screen.dart";
import "features/duty/duty_screen.dart";
import "features/info/contact_screen.dart";
import "features/info/membership_info_screen.dart";
import "features/info/library_info_copy.dart";
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

    const supabaseUrl = String.fromEnvironment("SUPABASE_URL", defaultValue: "");
    const supabaseAnonKey =
        String.fromEnvironment("SUPABASE_ANON_KEY", defaultValue: "");

    if (authStore != null) {
      auth = authStore!;
    } else if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
      auth = AuthStore.supabase(client);
    } else {
      auth = AuthStore.guest();
    }

    return MultiProvider(
      providers: [
        Provider<BackendClient>.value(value: client),
        ChangeNotifierProvider<AuthStore>.value(value: auth),
        ChangeNotifierProvider(create: (_) => CatalogController(client)),
        ChangeNotifierProvider(create: (_) => BookingsController(client)),
        ChangeNotifierProvider(create: (_) => LoansController(client)),
        ChangeNotifierProvider(create: (_) => DutyController(client)),
        ChangeNotifierProvider(create: (_) => AdminController(client)),
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
        title: LibraryInfoCopy.appBarTitle,
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

class _RoleHome extends StatefulWidget {
  const _RoleHome();

  @override
  State<_RoleHome> createState() => _RoleHomeState();
}

class _RoleHomeState extends State<_RoleHome> with WidgetsBindingObserver {
  String _lastReminderSignature = "";
  bool _memberRemindersBootstrapped = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncAdminNotifications();
      _bootstrapMemberReminders();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _bootstrapMemberReminders();
    }
  }

  @override
  void didUpdateWidget(covariant _RoleHome oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAdminNotifications();
  }

  void _syncAdminNotifications() {
    if (!mounted) return;
    final auth = context.read<AuthStore>();
    if (auth.isAdmin) {
      context.read<AdminController>().loadNotifications(silent: true);
    }
  }

  Future<void> _bootstrapMemberReminders() async {
    if (!mounted) return;
    final auth = context.read<AuthStore>();
    if (!auth.canBookToys) {
      await ReminderSync.clear();
      return;
    }
    if (!_memberRemindersBootstrapped) {
      _memberRemindersBootstrapped = true;
      await ReminderSync.refreshForMember(context);
    }
  }

  void _syncMemberRemindersIfChanged(AuthStore auth) {
    final signature = _reminderSignature(auth);
    if (signature == _lastReminderSignature) return;
    _lastReminderSignature = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ReminderSync.syncFromControllers(context));
    });
  }

  String _reminderSignature(AuthStore auth) {
    final enabled = ReminderSync.remindersEnabled(auth);
    final bookings = context.read<BookingsController>().bookings;
    final loans = context.read<LoansController>().myLoans;
    final pending = bookings
        .where((booking) => booking.isPending)
        .map((booking) => "${booking.bookingId}:${booking.pickupDate}")
        .join("|");
    final active = loans
        .where((loan) => loan.isActive)
        .map((loan) => "${loan.loanId}:${loan.dueDate}:${loan.isOverdue}")
        .join("|");
    return "$enabled#$pending#$active";
  }

  void _openDuty(BuildContext context) {
    showDutyRosterSheet(context);
  }

  void _openLogin(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
    );
  }

  Widget _guestAuthActions() {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilledButton(
        onPressed: () => _openLogin(context),
        style: brandFilledButtonStyle().copyWith(
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          minimumSize: const WidgetStatePropertyAll(Size(0, 36)),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        child: const Text("Sign in"),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();
    context.watch<BookingsController>();
    context.watch<LoansController>();
    _syncMemberRemindersIfChanged(auth);
    final tabs = _tabsForRole(auth.role);

    return DefaultTabController(
      length: tabs.length,
      child: Builder(
        builder: (context) {
          final tabController = DefaultTabController.of(context);
          return AnimatedBuilder(
            animation: tabController,
            builder: (context, _) {
              return Scaffold(
                appBar: AppBar(
                  title: const LibraryAppBarTitle(),
                  actions: [
                    if (auth.isAdmin) ...[
                      const AdminNotificationBell(),
                      IconButton(
                        tooltip: "Duty roster",
                        icon: const Icon(Icons.event_available_outlined),
                        onPressed: () => _openDuty(context),
                      ),
                    ] else if (auth.isVolunteer) ...[
                      IconButton(
                        tooltip: "Duty roster",
                        icon: const Icon(Icons.event_available_outlined),
                        onPressed: () => _openDuty(context),
                      ),
                    ],
                    if (!auth.isLoggedIn)
                      _guestAuthActions()
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
                    tabs: tabs
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
              );
            },
          );
        },
      ),
    );
  }

  static const _infoTabs = [
    ("Contact", Icons.contact_page_outlined),
  ];

  static const _guestInfoTabs = [
    ("Contact", Icons.contact_page_outlined),
    ("Membership", Icons.card_membership),
  ];

  static const _infoScreens = [
    ContactScreen(),
  ];

  static const _guestInfoScreens = [
    ContactScreen(),
    MembershipInfoScreen(embedded: true),
  ];

  List<(String, IconData)> _tabsForRole(AppRole role) {
    const catalog = ("Catalog", Icons.toys);
    const bookings = ("Bookings", Icons.event_note);
    const members = ("Members", Icons.people_outline);
    const loans = ("Loans", Icons.autorenew);
    const stats = ("Stats", Icons.bar_chart_outlined);
    const duty = ("Duty", Icons.desk_outlined);

    switch (role) {
      case AppRole.admin:
        return const [catalog, bookings, members, loans, stats];
      case AppRole.volunteer:
        return const [catalog, bookings, loans, duty, ..._infoTabs];
      case AppRole.member:
        return const [catalog, bookings, loans, ..._infoTabs];
      case AppRole.guest:
        return const [catalog, ..._guestInfoTabs];
    }
  }

  List<Widget> _screensForRole(AppRole role) {
    switch (role) {
      case AppRole.admin:
        return const [
          CatalogScreen(),
          AdminBookingsScreen(),
          AdminMembersScreen(),
          AdminLoansScreen(),
          AdminStatisticsScreen(),
        ];
      case AppRole.volunteer:
        return const [
          CatalogScreen(),
          BookingsScreen(),
          LoansScreen(),
          VolunteerDutyTabScreen(),
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
        return const [CatalogScreen(), ..._guestInfoScreens];
    }
  }
}
