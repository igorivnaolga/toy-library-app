import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../core/app_input_field.dart";
import "../../core/app_text_styles.dart";
import "../../core/brand_chip_button.dart";
import "../profile/kid_profile.dart";
import "../profile/profile_avatar.dart";
import "../profile/profile_labels.dart";
import "admin_controller.dart";
import "admin_models.dart";

/// Admin view of a member profile with editable membership, children, and notes.
class AdminMemberProfileScreen extends StatefulWidget {
  const AdminMemberProfileScreen({
    super.key,
    required this.userId,
    this.initialMember,
  });

  final String userId;
  final AdminMember? initialMember;

  static const double avatarRadius = 68;

  @override
  State<AdminMemberProfileScreen> createState() =>
      _AdminMemberProfileScreenState();
}

class _AdminMemberProfileScreenState extends State<AdminMemberProfileScreen> {
  AdminMemberDetail? _member;
  String? _selectedTier;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool _editingMembership = false;
  bool _editingChildren = false;
  bool _editingNotes = false;

  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _kidController = TextEditingController();
  DateTime? _kidBirthDate;
  List<KidProfile> _editableKids = [];

  static const _tierOptions = [
    ("casual", "Casual"),
    ("non_duty", "Non-duty member"),
    ("duty", "Duty volunteer"),
  ];

  @override
  void initState() {
    super.initState();
    _selectedTier = widget.initialMember?.membershipTier;
    _load();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _kidController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final member =
          await context.read<AdminController>().loadMemberDetail(widget.userId);
      if (!mounted) return;
      setState(() {
        _member = member;
        _selectedTier = member.membershipTier;
        _notesController.text = member.adminNotes ?? "";
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = adminActionErrorMessage(e);
        _loading = false;
      });
    }
  }

  Future<void> _saveMembership() async {
    final tier = _selectedTier;
    if (tier == null || tier.isEmpty) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await context
          .read<AdminController>()
          .updateMemberMembership(widget.userId, tier);
      if (!mounted) return;
      setState(() {
        _member = updated;
        _selectedTier = updated.membershipTier;
        _editingMembership = false;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Membership updated")),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = adminActionErrorMessage(e);
        _saving = false;
      });
    }
  }

  Future<void> _saveChildren() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await context.read<AdminController>().updateMemberProfile(
            widget.userId,
            kids: _editableKids.map((k) => k.toJson()).toList(),
          );
      if (!mounted) return;
      setState(() {
        _member = updated;
        _editingChildren = false;
        _kidController.clear();
        _kidBirthDate = null;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Children updated")),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = adminActionErrorMessage(e);
        _saving = false;
      });
    }
  }

  Future<void> _saveNotes() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await context.read<AdminController>().updateMemberProfile(
            widget.userId,
            adminNotes: _notesController.text.trim(),
          );
      if (!mounted) return;
      setState(() {
        _member = updated;
        _notesController.text = updated.adminNotes ?? "";
        _editingNotes = false;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Notes saved")),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = adminActionErrorMessage(e);
        _saving = false;
      });
    }
  }

  void _toggleMembershipEdit() {
    if (_saving) return;
    setState(() {
      _editingMembership = !_editingMembership;
      if (_editingMembership) {
        _selectedTier = _member?.membershipTier;
      }
    });
  }

  void _toggleChildrenEdit() {
    if (_saving) return;
    setState(() {
      _editingChildren = !_editingChildren;
      if (_editingChildren) {
        _editableKids = List<KidProfile>.from(_member?.kids ?? []);
        _kidController.clear();
        _kidBirthDate = null;
      }
    });
  }

  void _toggleNotesEdit() {
    if (_saving) return;
    setState(() {
      _editingNotes = !_editingNotes;
      if (_editingNotes) {
        _notesController.text = _member?.adminNotes ?? "";
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

  void _addKid() {
    final name = _kidController.text.trim();
    if (name.isEmpty || _kidBirthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a name and date of birth")),
      );
      return;
    }
    final date = _kidBirthDate!;
    setState(() {
      _editableKids = [
        ..._editableKids,
        KidProfile(
          name: name,
          birthDate: DateTime(date.year, date.month, date.day),
        ),
      ];
      _kidController.clear();
      _kidBirthDate = null;
    });
  }

  void _removeKid(int index) {
    setState(() {
      _editableKids = [
        ..._editableKids.sublist(0, index),
        ..._editableKids.sublist(index + 1),
      ];
    });
  }

  String _formatBirthDate(DateTime date) {
    const months = [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
    ];
    return "${date.day} ${months[date.month - 1]} ${date.year}";
  }

  String _roleLabel(AdminMemberDetail member) {
    if (member.role == "volunteer") return "Volunteer";
    return "Member";
  }

  String _membershipBadgeLabel(AdminMemberDetail member) {
    if (member.role == "volunteer") return "Volunteer";
    if (member.membershipTier == "duty" && !member.volunteerConfirmed) {
      return "Duty volunteer (pending)";
    }
    return membershipTierLabel(member.membershipTier);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final member = _member;
    final displayName = member?.displayName ??
        widget.initialMember?.displayName ??
        "Member";
    final email = member?.email ?? widget.initialMember?.email ?? "";

    return Scaffold(
      appBar: AppBar(
        title: const SizedBox.shrink(),
      ),
      body: _loading && member == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  const SizedBox(height: 12),
                ],
                Column(
                  children: [
                    ProfileAvatar(
                      fullName: displayName,
                      avatarPath: member?.avatarPath,
                      radius: AdminMemberProfileScreen.avatarRadius,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      displayName,
                      textAlign: TextAlign.center,
                      style: context.detailTitle,
                    ),
                    if (email.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        email,
                        textAlign: TextAlign.center,
                        style: context.profileSecondary,
                      ),
                    ],
                    if (member != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _roleLabel(member),
                        style: context.listSubtitle,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 28),
                _AdminProfileSection(
                  title: "Membership",
                  onEdit: _saving ? null : _toggleMembershipEdit,
                  editing: _editingMembership,
                  children: [
                    if (member != null && !_editingMembership) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Row(
                          children: [
                            Icon(
                              Icons.card_membership_outlined,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.55),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                membershipTierLabel(member.membershipTier),
                                style: context.cardTitle,
                              ),
                            ),
                            _MembershipBadge(
                              label: _membershipBadgeLabel(member),
                              style: membershipBadgeStyle(
                                label: _membershipBadgeLabel(member),
                                colors: theme.colorScheme,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Text(
                          "Started ${formatAdminDate(member.membershipStartedAt)}",
                          style: context.listSubtitle,
                        ),
                      ),
                    ],
                    if (_editingMembership) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedTier,
                          decoration: labeledInputDecoration(
                            context,
                            labelText: "Membership type",
                            fillColor: theme.colorScheme.surface,
                          ),
                          items: _tierOptions
                              .map(
                                (o) => DropdownMenuItem<String>(
                                  value: o.$1,
                                  child: Text(o.$2),
                                ),
                              )
                              .toList(),
                          onChanged: _saving
                              ? null
                              : (value) =>
                                  setState(() => _selectedTier = value),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: BrandChipButton(
                          label: _saving ? "Saving…" : "Save membership",
                          large: true,
                          onPressed: _saving ? null : _saveMembership,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 24),
                _AdminProfileSection(
                  title: "Children",
                  onEdit: _saving ? null : _toggleChildrenEdit,
                  editing: _editingChildren,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      child: _editingChildren
                          ? _ChildrenEditor(
                              kids: _editableKids,
                              kidController: _kidController,
                              kidBirthDate: _kidBirthDate,
                              saving: _saving,
                              onPickBirthDate: _pickKidBirthDate,
                              onAddKid: _addKid,
                              onRemoveKid: _removeKid,
                              onClearBirthDate: () =>
                                  setState(() => _kidBirthDate = null),
                              formatBirthDate: _formatBirthDate,
                              onSave: _saveChildren,
                            )
                          : member == null || member.kids.isEmpty
                              ? Text(
                                  "No children on file.",
                                  style: context.profileSecondary,
                                )
                              : Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: member.kids
                                      .map(
                                        (kid) => Chip(
                                          label: Text(kid.displayLabel),
                                        ),
                                      )
                                      .toList(),
                                ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _AdminProfileSection(
                  title: "Admin notes",
                  onEdit: _saving ? null : _toggleNotesEdit,
                  editing: _editingNotes,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      child: _editingNotes
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextField(
                                  controller: _notesController,
                                  style: fieldTextStyle(context),
                                  cursorColor: fieldCursorColor(context),
                                  maxLines: 4,
                                  decoration: labeledInputDecoration(
                                    context,
                                    labelText: "Private notes",
                                    helperText: "Visible to admins only.",
                                    fillColor: theme.colorScheme.surface,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                BrandChipButton(
                                  label: _saving ? "Saving…" : "Save notes",
                                  large: true,
                                  onPressed: _saving ? null : _saveNotes,
                                ),
                              ],
                            )
                          : Text(
                              (member?.adminNotes?.trim().isNotEmpty ?? false)
                                  ? member!.adminNotes!.trim()
                                  : "No notes yet.",
                              style: (member?.adminNotes?.trim().isNotEmpty ??
                                      false)
                                  ? context.bodyText
                                  : context.profileSecondary,
                            ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _ChildrenEditor extends StatelessWidget {
  const _ChildrenEditor({
    required this.kids,
    required this.kidController,
    required this.kidBirthDate,
    required this.saving,
    required this.onPickBirthDate,
    required this.onAddKid,
    required this.onRemoveKid,
    required this.onClearBirthDate,
    required this.formatBirthDate,
    required this.onSave,
  });

  final List<KidProfile> kids;
  final TextEditingController kidController;
  final DateTime? kidBirthDate;
  final bool saving;
  final VoidCallback onPickBirthDate;
  final VoidCallback onAddKid;
  final ValueChanged<int> onRemoveKid;
  final VoidCallback onClearBirthDate;
  final String Function(DateTime) formatBirthDate;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (kids.isEmpty)
          Text("Add a child below.", style: context.profileSecondary)
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kids.asMap().entries.map((entry) {
              return InputChip(
                label: Text(entry.value.displayLabel),
                deleteIcon: const Icon(Icons.close, size: 18),
                onDeleted: saving ? null : () => onRemoveKid(entry.key),
              );
            }).toList(),
          ),
        const SizedBox(height: 12),
        TextField(
          controller: kidController,
          style: fieldTextStyle(context),
          cursorColor: fieldCursorColor(context),
          decoration: labeledInputDecoration(
            context,
            labelText: "Child name",
            fillColor: theme.colorScheme.surface,
          ),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: saving ? null : onPickBirthDate,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: labeledInputDecoration(
              context,
              labelText: "Date of birth",
              fillColor: theme.colorScheme.surface,
              suffixIcon: kidBirthDate == null
                  ? Icon(
                      Icons.calendar_today_outlined,
                      size: 20,
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.55),
                    )
                  : IconButton(
                      tooltip: "Clear date",
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: saving ? null : onClearBirthDate,
                    ),
            ),
            child: Text(
              kidBirthDate == null
                  ? "Select date"
                  : formatBirthDate(kidBirthDate!),
              style: kidBirthDate == null
                  ? fieldPlaceholderStyle(context)
                  : fieldTextStyle(context),
            ),
          ),
        ),
        const SizedBox(height: 12),
        BrandChipButton(
          label: "Add child",
          onPressed: saving ? null : onAddKid,
        ),
        const SizedBox(height: 12),
        BrandChipButton(
          label: saving ? "Saving…" : "Save children",
          large: true,
          onPressed: saving ? null : onSave,
        ),
      ],
    );
  }
}

class _AdminProfileSection extends StatelessWidget {
  const _AdminProfileSection({
    required this.title,
    required this.children,
    this.onEdit,
    this.editing = false,
  });

  final String title;
  final List<Widget> children;
  final VoidCallback? onEdit;
  final bool editing;

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
              if (onEdit != null)
                IconButton(
                  tooltip: editing ? "Close" : "Edit",
                  onPressed: onEdit,
                  icon: Icon(editing ? Icons.close : Icons.edit_outlined),
                  visualDensity: VisualDensity.compact,
                ),
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
