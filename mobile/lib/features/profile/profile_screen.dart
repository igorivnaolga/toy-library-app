import "package:flutter/material.dart";
import "package:image_picker/image_picker.dart";
import "package:provider/provider.dart";

import "../../core/app_theme.dart";
import "../../core/auth_store.dart";
import "../../core/brand_chip_button.dart";
import "profile_avatar.dart";
import "profile_controller.dart";
import "profile_labels.dart";
import "kid_profile.dart";

/// Editable user profile opened from the AppBar avatar button.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _kidController;
  DateTime? _kidBirthDate;

  @override
  void initState() {
    super.initState();
    final profile = context.read<ProfileController>();
    profile.syncFromAuth();
    _nameController = TextEditingController(text: profile.fullName);
    _kidController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
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
                style: Theme.of(context).textTheme.titleMedium,
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

  Future<void> _save(ProfileController profile) async {
    profile.setFullName(_nameController.text);
    final ok = await profile.save();
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile updated")),
      );
    }
  }

  void _addKid(ProfileController profile) {
    final name = _kidController.text.trim();
    final birthDate = _kidBirthDate;
    if (name.isEmpty || birthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a name and date of birth")),
      );
      return;
    }
    profile.addKid(name, birthDate);
    _kidController.clear();
    setState(() => _kidBirthDate = null);
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
        title: const Text("Profile"),
        actions: [
          TextButton(
            onPressed: profile.saving
                ? null
                : () => context.read<AuthStore>().signOut(),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
            child: const Text("Sign out"),
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
            title: "Personal details",
            children: [
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: "Full name",
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                textCapitalization: TextCapitalization.words,
                onChanged: profile.setFullName,
              ),
              const Divider(height: 1),
              _ProfileReadOnlyRow(
                icon: Icons.mail_outline,
                label: "Email",
                value: auth.email ?? "—",
              ),
            ],
          ),
          const SizedBox(height: 24),
          _ProfileSection(
            title: "Membership",
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.card_membership_outlined,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
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
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.62),
                              ),
                            ),
                    ),
                    _MembershipBadge(label: membershipStatus),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _ProfileSection(
            title: "Children",
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: profile.kids.isEmpty
                    ? Text(
                        "Add children who borrow toys from the library.",
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.62),
                        ),
                      )
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: profile.kids.asMap().entries.map(
                          (entry) {
                            return InputChip(
                              label: Text(entry.value.displayLabel),
                              deleteIcon: const Icon(Icons.close, size: 18),
                              onDeleted: profile.saving
                                  ? null
                                  : () => profile.removeKid(entry.key),
                            );
                          },
                        ).toList(),
                      ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  controller: _kidController,
                  decoration: InputDecoration(
                    labelText: "Child name",
                    filled: true,
                    fillColor: theme.colorScheme.surface,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                  textCapitalization: TextCapitalization.words,
                  onSubmitted: (_) => _addKid(profile),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: profile.saving ? null : _pickKidBirthDate,
                        borderRadius: BorderRadius.circular(12),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: "Date of birth",
                            filled: true,
                            fillColor: theme.colorScheme.surface,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                          child: Text(
                            _kidBirthDate == null
                                ? "Select date"
                                : _formatBirthDate(_kidBirthDate!),
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: _kidBirthDate == null
                                  ? theme.colorScheme.onSurface
                                      .withValues(alpha: 0.45)
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed:
                          profile.saving ? null : () => _addKid(profile),
                      style: FilledButton.styleFrom(
                        backgroundColor: kBrandYellow,
                        foregroundColor: kBrandOnYellow,
                      ),
                      child: const Text("Add"),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (profile.error != null) ...[
            const SizedBox(height: 16),
            Text(
              profile.error!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
          const SizedBox(height: 32),
          BrandChipButton(
            label: "Save changes",
            large: true,
            onPressed: profile.saving ? null : () => _save(profile),
          ),
          if (profile.saving)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Center(child: CircularProgressIndicator()),
            ),
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
              radius: 56,
              onTap: uploadingAvatar ? null : onChangePhoto,
            ),
            if (uploadingAvatar)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                bottom: 0,
                child: CircleAvatar(
                  radius: 56,
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
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (email != null && email!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            email!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
            ),
          ),
        ],
        const SizedBox(height: 8),
        TextButton(
          onPressed: uploadingAvatar ? null : onChangePhoto,
          style: TextButton.styleFrom(
            foregroundColor: theme.colorScheme.secondary,
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
          child: const Text("Change photo"),
        ),
      ],
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Material(
          color: theme.colorScheme.surfaceContainerLowest,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
            ),
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

class _ProfileReadOnlyRow extends StatelessWidget {
  const _ProfileReadOnlyRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(
            icon,
            size: 22,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodySmall),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MembershipBadge extends StatelessWidget {
  const _MembershipBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
