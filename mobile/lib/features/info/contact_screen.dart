import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../core/app_text_styles.dart";
import "../../core/app_theme.dart";
import "../../core/main_tab_navigation.dart";
import "contact_links.dart";
import "../payments/payment_instructions_card.dart";
import "library_info_copy.dart";
import "library_location_map.dart";

/// Library welcome, map, hours, and contact details.
class ContactScreen extends StatefulWidget {
  const ContactScreen({
    super.key,
    this.scrollToPaymentsOnMount = false,
  });

  final bool scrollToPaymentsOnMount;

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final _paymentsSectionKey = GlobalKey();
  MainTabNavigation? _tabNav;
  int _lastScrollToken = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.scrollToPaymentsOnMount) {
        _scrollToPayments();
        return;
      }
      final token = context.read<MainTabNavigation>().scrollPaymentsToken;
      if (token > 0 && token > _lastScrollToken) {
        _lastScrollToken = token;
        _scrollToPayments();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nav = context.read<MainTabNavigation>();
    if (!identical(_tabNav, nav)) {
      _tabNav?.removeListener(_onMainTabNavigation);
      _tabNav = nav;
      _tabNav!.addListener(_onMainTabNavigation);
    }
  }

  @override
  void dispose() {
    _tabNav?.removeListener(_onMainTabNavigation);
    super.dispose();
  }

  void _onMainTabNavigation() {
    if (!mounted || widget.scrollToPaymentsOnMount) return;
    final token = _tabNav?.scrollPaymentsToken ?? 0;
    if (token <= 0 || token == _lastScrollToken) return;
    _lastScrollToken = token;
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToPayments());
  }

  void _scrollToPayments() {
    final target = _paymentsSectionKey.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      alignment: 0.05,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
      children: [
        const LibraryLocationMap(),
        const SizedBox(height: 12),
        _ContactInfoCard(
          icon: Icons.location_on_outlined,
          title: LibraryInfoCopy.locationTitle,
          onTap: openLibraryInGoogleMaps,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                LibraryInfoCopy.locationAddressLine1,
                style: context.cardTitle,
              ),
              const SizedBox(height: 4),
              Text(
                LibraryInfoCopy.locationAddressLine2,
                style: context.bodyText,
              ),
              const SizedBox(height: 4),
              Text(
                LibraryInfoCopy.locationAddressHint,
                style: context.listSubtitle,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _ContactInfoCard(
          icon: Icons.schedule_outlined,
          title: LibraryInfoCopy.openingHoursTitle,
          child: Column(
            children: [
              for (var i = 0; i < LibraryInfoCopy.openingHoursEntries.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _OpeningHoursRow(
                  day: LibraryInfoCopy.openingHoursEntries[i].$1,
                  hours: LibraryInfoCopy.openingHoursEntries[i].$2,
                ),
              ],
              const SizedBox(height: 12),
              Text(
                "Closed on public holidays and over the Christmas break.",
                style: context.listSubtitle,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _ContactInfoCard(
          icon: Icons.contact_phone_outlined,
          title: LibraryInfoCopy.contactTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ContactActionRow(
                icon: Icons.phone_outlined,
                label: LibraryInfoCopy.coordinatorPhone,
                onTap: launchPhoneCall,
              ),
              const SizedBox(height: 8),
              _ContactActionRow(
                icon: Icons.email_outlined,
                label: LibraryInfoCopy.coordinatorEmail,
                onTap: launchCoordinatorEmail,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        KeyedSubtree(
          key: _paymentsSectionKey,
          child: _ContactInfoCard(
            icon: Icons.payments_outlined,
            title: LibraryInfoCopy.paymentsTitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LibraryInfoCopy.paymentsBody,
                  style: context.bodyText,
                ),
                const SizedBox(height: 12),
                PaymentInstructionsCard(compact: true),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ContactInfoCard extends StatelessWidget {
  const _ContactInfoCard({
    required this.icon,
    required this.title,
    required this.child,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final content = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 22,
                color: kBrandOnYellow.withValues(alpha: 0.55),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: context.sectionHeader,
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: colors.onSurfaceVariant,
                ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );

    return Material(
      color: colors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              child: content,
            ),
    );
  }
}

class _OpeningHoursRow extends StatelessWidget {
  const _OpeningHoursRow({
    required this.day,
    required this.hours,
  });

  final String day;
  final String hours;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(day, style: context.listSecondaryEmphasis),
        ),
        Expanded(
          flex: 3,
          child: Text(hours, style: context.bodyText),
        ),
      ],
    );
  }
}

class _ContactActionRow extends StatelessWidget {
  const _ContactActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 20, color: colors.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: context.bodyText.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
