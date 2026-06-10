import "package:flutter/material.dart";
import "package:image_picker/image_picker.dart";
import "package:provider/provider.dart";

import "../../core/app_input_field.dart";
import "../../core/app_text_styles.dart";
import "../../core/auth_store.dart";
import "../../core/brand_chip_button.dart";
import "profile_avatar.dart";
import "profile_controller.dart";
import "profile_labels.dart";
import "member_contact_info.dart";

/// Editable user profile opened from the AppBar avatar button.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _kidController;
  DateTime? _kidBirthDate;
  bool _editingChildren = false;
  bool _contactExpanded = false;

  @override
  void initState() {
    super.initState();
    context.read<ProfileController>().syncFromAuth();
    _kidController = TextEditingController();
  }

  @override
  void dispose() {
    _kidController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar(ProfileController profile) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Text(
                "Change profile photo",
                style: context.screenTitle,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text("Choose from gallery"),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text("Take a photo"),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    await profile.pickAndUploadAvatar(source);
  }

  Future<void> _addKid(ProfileController profile) async {
    final name = _kidController.text.trim();
    if (name.isEmpty || _kidBirthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a name and date of birth")),
      );
      return;
    }
    final ok = await profile.addKid(name, birthDate: _kidBirthDate!);
    if (!mounted) return;
    if (ok) {
      _kidController.clear();
      setState(() => _kidBirthDate = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Added $name")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(profile.error ?? "Could not add child")),
      );
    }
  }

  Future<void> _removeKid(ProfileController profile, int index) async {
    final ok = await profile.removeKid(index);
    if (!mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(profile.error ?? "Could not remove child")),
    );
  }

  void _toggleChildrenEdit() {
    setState(() {
      _editingChildren = !_editingChildren;
      if (!_editingChildren) {
        _kidController.clear();
        _kidBirthDate = null;
      }
    });
  }

  Future<void> _pickKidBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _kidBirthDate ?? DateTime(DateTime.now().year - 5),
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
      helpText: "Child date of birth",
    );
    if (picked != null) setState(() => _kidBirthDate = picked);
  }

  String _formatBirthDate(DateTime date) {
    const months = [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
    ];
    return "${date.day} ${months[date.month - 1]} ${date.year}";
  }

  bool _hasContactDetails(MemberContactInfo contact) {
    return contact.hasAddress ||
        (contact.parentBName?.trim().isNotEmpty ?? false) ||
        (contact.mobilePhone?.trim().isNotEmpty ?? false) ||
        (contact.altContactName?.trim().isNotEmpty ?? false) ||
        (contact.heardAboutUs?.trim().isNotEmpty ?? false) ||
        (contact.skills?.trim().isNotEmpty ?? false);
  }

  Future<void> _signOut() async {
    await context.read<AuthStore>().signOut();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthStore>();
    final profile = context.watch<ProfileController>();
    final membershipStatus = membershipSummaryLabel(
      role: auth.role,
      membershipTier: auth.membershipTier,
    );

    return Scaffold(
      appBar: AppBar(
        title: const SizedBox.shrink(),
        actionsPadding: const EdgeInsets.only(right: 20),
        actions: [
          _ProfileSignOutAction(
            onPressed: profile.saving ? null : _signOut,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _ProfileHeader(
            fullName: profile.fullName.trim().isEmpty
                ? "Your name"
                : profile.fullName.trim(),
            email: auth.email,
            avatarPath: profile.avatarPath,
            uploadingAvatar: profile.uploadingAvatar,
            onChangePhoto: () => _pickAvatar(profile),
          ),
          const SizedBox(height: 28),
          _ProfileSection(
            title: "Membership",
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.card_membership_outlined,
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.55),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: auth.membershipTier == "duty" && auth.isMember
                          ? Text(
                              "Volunteer access pending approval",
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.secondary,
                                fontStyle: FontStyle.italic,
                              ),
                            )
                          : Text(
                              "Your current membership",
                              style: context.profileSecondary,
                            ),
                    ),
                    _MembershipBadge(
                      label: membershipStatus,
                      style: membershipBadgeStyle(
                        label: membershipStatus,
                        colors: theme.colorScheme,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_hasContactDetails(profile.contact)) ...[
            const SizedBox(height: 24),
            _CollapsibleProfileSection(
              title: "Contact & membership form",
              expanded: _contactExpanded,
              onToggle: () =>
                  setState(() => _contactExpanded = !_contactExpanded),
              children: [
                _ContactDetailsBody(contact: profile.contact),
              ],
            ),
          ],
          const SizedBox(height: 24),
          _ProfileSection(
            title: "Children",
            trailing: IconButton(
              tooltip: _editingChildren ? "Done editing" : "Edit children",
              onPressed: profile.saving ? null : _toggleChildrenEdit,
              icon: Icon(
                _editingChildren ? Icons.close : Icons.edit_outlined,
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: profile.kids.isEmpty
                    ? Text(
                        _editingChildren
                            ? "Add a child below."
                            : "Add children who borrow toys from the library.",
                        style: context.profileSecondary,
                      )
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: profile.kids.asMap().entries.map(
                          (entry) {
                            if (_editingChildren) {
                              return InputChip(
                                label: Text(entry.value.displayLabel),
                                deleteIcon:
                                    const Icon(Icons.close, size: 18),
                                onDeleted: profile.saving
                                    ? null
                                    : () => _removeKid(profile, entry.key),
                              );
                            }
                            return Chip(label: Text(entry.value.displayLabel));
                          },
                        ).toList(),
                      ),
              ),
              if (_editingChildren) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    controller: _kidController,
                    style: fieldTextStyle(context),
                    cursorColor: fieldCursorColor(context),
                    decoration: labeledInputDecoration(
                      context,
                      labelText: "Child name",
                      fillColor: theme.colorScheme.surface,
                    ),
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    onSubmitted:
                        profile.saving ? null : (_) => _addKid(profile),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: InkWell(
                    onTap: profile.saving ? null : _pickKidBirthDate,
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: labeledInputDecoration(
                        context,
                        labelText: "Date of birth",
                        fillColor: theme.colorScheme.surface,
                        suffixIcon: _kidBirthDate == null
                            ? Icon(
                                Icons.calendar_today_outlined,
                                size: 20,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.55),
                              )
                            : IconButton(
                                tooltip: "Clear date",
                                icon: const Icon(Icons.clear, size: 20),
                                onPressed: profile.saving
                                    ? null
                                    : () =>
                                        setState(() => _kidBirthDate = null),
                              ),
                      ),
                      child: Text(
                        _kidBirthDate == null
                            ? "Select date"
                            : _formatBirthDate(_kidBirthDate!),
                        style: _kidBirthDate == null
                            ? fieldPlaceholderStyle(context)
                            : fieldTextStyle(context),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: BrandChipButton(
                    label: profile.saving ? "Saving…" : "Add child",
                    large: true,
                    onPressed: profile.saving ? null : () => _addKid(profile),
                  ),
                ),
              ],
            ],
          ),
          if (profile.error != null) ...[
            const SizedBox(height: 16),
            Text(
              profile.error!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.fullName,
    required this.email,
    required this.avatarPath,
    required this.uploadingAvatar,
    required this.onChangePhoto,
  });

  final String fullName;
  final String? email;
  final String? avatarPath;
  final bool uploadingAvatar;
  final VoidCallback onChangePhoto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            ProfileAvatar(
              fullName: fullName == "Your name" ? null : fullName,
              avatarPath: avatarPath,
              radius: 68,
              onTap: uploadingAvatar ? null : onChangePhoto,
            ),
            if (uploadingAvatar)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                bottom: 0,
                child: CircleAvatar(
                  radius: 68,
                  backgroundColor: const Color(0x66000000),
                  child: const CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              Material(
                color: theme.colorScheme.primary,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onChangePhoto,
                  child: const Padding(
                    padding: EdgeInsets.all(7),
                    child: Icon(Icons.camera_alt_outlined, size: 18),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          fullName,
          textAlign: TextAlign.center,
          style: context.detailTitle,
        ),
        if (email != null && email!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            email!,
            textAlign: TextAlign.center,
            style: context.profileSecondary,
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}

class _ContactDetailsBody extends StatelessWidget {
  const _ContactDetailsBody({required this.contact});

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

class _CollapsibleProfileSection extends StatelessWidget {
  const _CollapsibleProfileSection({
    required this.title,
    required this.expanded,
    required this.onToggle,
    required this.children,
  });

  final String title;
  final bool expanded;
  final VoidCallback onToggle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: theme.colorScheme.surfaceContainerLowest,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              expanded ? 16 : 16,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title.toUpperCase(),
                          style: context.formSectionLabel,
                        ),
                      ),
                      AnimatedRotation(
                        turns: expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (expanded) ...[
                const Divider(height: 1),
                ...children,
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.title,
    required this.children,
    this.trailing,
  });

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: context.formSectionLabel,
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
        Material(
          color: theme.colorScheme.surfaceContainerLowest,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
    );
  }
}

class _MembershipBadge extends StatelessWidget {
  const _MembershipBadge({
    required this.label,
    required this.style,
  });

  final String label;
  final MembershipBadgeStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(999),
        border: style.border,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: style.foreground,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _ProfileSignOutAction extends StatelessWidget {
  const _ProfileSignOutAction({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    final enabled = onPressed != null;
    final color = enabled ? error : error.withValues(alpha: 0.45);
    final borderColor = enabled
        ? error.withValues(alpha: 0.55)
        : error.withValues(alpha: 0.35);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          customBorder: const StadiumBorder(),
          child: Ink(
            decoration: ShapeDecoration(
              shape: StadiumBorder(
                side: BorderSide(color: borderColor, width: 1.5),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.logout, size: 16, color: color),
                const SizedBox(width: 6),
                Text(
                  "Sign out",
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
