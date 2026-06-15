import "dart:ui";

import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../core/toy_loading_indicator.dart";
import "../../core/api_exception.dart";
import "../../core/app_input_field.dart";
import "../../core/app_text_styles.dart";
import "../../core/app_theme.dart";
import "../../core/brand_chip_button.dart";
import "../../core/section_header.dart";
import "../catalog/toy_detail_screen.dart";
import "../loans/loan_due_date_section.dart";
import "../loans/loan_list_tile.dart";
import "../loans/loan_models.dart";
import "../profile/kid_profile.dart";
import "../profile/contact_details_body.dart";
import "../profile/profile_avatar.dart";
import "../profile/profile_labels.dart";
import "../payments/payment_models.dart";
import "../payments/payment_list_by_date.dart";
import "../duty/volunteer_duty_shifts_section.dart";
import "admin_controller.dart";
import "admin_loans_screen.dart";
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
  List<PaymentItem> _payments = const [];
  List<LoanItem> _loans = const [];
  String? _selectedTier;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  bool _activeLoansExpanded = false;
  bool _returnedLoansExpanded = false;
  bool _paymentsExpanded = false;
  bool _dutyExpanded = false;
  bool _contactExpanded = false;
  String? _payingPaymentId;
  bool _recordingMembership = false;
  bool _recordingTopUp = false;
  bool _markingSelectedPayments = false;
  String? _loansLoadError;
  int _loadToken = 0;

  bool _editingMembership = false;
  bool _editingChildren = false;
  bool _editingNotes = false;

  final TextEditingController _notesController = TextEditingController();
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
    super.dispose();
  }

  Future<void> _load() async {
    final token = ++_loadToken;
    setState(() {
      _loading = true;
      _error = null;
      _loansLoadError = null;
    });
    try {
      final admin = context.read<AdminController>();
      final results = await Future.wait<Object>([
        admin.loadMemberDetail(widget.userId),
        admin.loadMemberPayments(widget.userId),
      ]);
      final member = results[0] as AdminMemberDetail;
      final payments = results[1] as List<PaymentItem>;
      List<LoanItem> loans = member.loans;
      String? loansError;
      if (loans.isEmpty) {
        try {
          loans = await admin.loadMemberLoans(widget.userId);
        } catch (e) {
          loansError = adminActionErrorMessage(e);
        }
      }
      if (!mounted || token != _loadToken) return;
      setState(() {
        _member = member;
        _payments = payments;
        _loans = loans;
        _loansLoadError = loansError;
        _selectedTier = member.membershipTier;
        if (!_editingNotes) {
          _notesController.text = member.adminNotes ?? "";
        }
        if (_editingChildren) {
          _editableKids = List<KidProfile>.from(member.kids);
        }
        if (payments.any((payment) => payment.isPending)) {
          _paymentsExpanded = true;
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted || token != _loadToken) return;
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

  Future<void> _saveKidsList(
    List<KidProfile> kids, {
    String? successMessage,
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!mounted) return;
    final admin = context.read<AdminController>();
    final kidsPayload = kids.map((k) => k.toJson()).toList();

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await admin.updateMemberProfile(
        widget.userId,
        kids: kidsPayload,
      );
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _member = updated;
          _editableKids = List<KidProfile>.from(updated.kids);
          _saving = false;
          _error = null;
        });
        if (successMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(successMessage)),
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (e is ApiException) {
          _error = e.message;
        }
        _saving = false;
      });
    }
  }

  Future<void> _addKid(String name, DateTime birthDate) async {
    final cleaned = name.trim();
    final date = DateTime(birthDate.year, birthDate.month, birthDate.day);
    final nextKids = [
      ..._editableKids,
      KidProfile(name: cleaned, birthDate: date),
    ];
    await _saveKidsList(nextKids, successMessage: "Added $cleaned");
  }

  Future<void> _removeKid(int index) async {
    if (index < 0 || index >= _editableKids.length) return;
    final nextKids = [
      ..._editableKids.sublist(0, index),
      ..._editableKids.sublist(index + 1),
    ];
    await _saveKidsList(nextKids);
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
    if (_editingChildren) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
    setState(() {
      _editingChildren = !_editingChildren;
      if (_editingChildren) {
        _editableKids = List<KidProfile>.from(_member?.kids ?? []);
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

  Future<void> _markMembershipPaid(String method) async {
    if (_recordingMembership) return;
    setState(() {
      _recordingMembership = true;
      _error = null;
    });
    try {
      final admin = context.read<AdminController>();
      final updated = await admin.markMembershipPaid(
        widget.userId,
        method: method,
      );
      final member = await admin.loadMemberDetail(widget.userId);
      if (!mounted) return;
      setState(() {
        _payments = updated;
        _member = member;
        _recordingMembership = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Membership payment recorded")),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = adminActionErrorMessage(e);
        _recordingMembership = false;
      });
    }
  }

  Future<void> _markPaymentPaid(PaymentItem payment, String method) async {
    if (_payingPaymentId != null || _markingSelectedPayments) return;
    setState(() {
      _payingPaymentId = payment.paymentId;
      _error = null;
    });
    try {
      final admin = context.read<AdminController>();
      await admin.markPaymentPaid(payment.paymentId, method: method);
      final member = await admin.loadMemberDetail(widget.userId);
      final payments = await admin.loadMemberPayments(widget.userId);
      if (!mounted) return;
      setState(() {
        _member = member;
        _payments = payments;
        _payingPaymentId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Recorded payment for ${payment.description ?? payment.typeLabel}",
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = adminActionErrorMessage(e);
        _payingPaymentId = null;
      });
    }
  }

  Future<void> _markSelectedPaymentsPaid(
    List<PaymentItem> payments,
    String method,
  ) async {
    if (_markingSelectedPayments ||
        _payingPaymentId != null ||
        payments.isEmpty) {
      return;
    }
    setState(() {
      _markingSelectedPayments = true;
      _error = null;
    });
    try {
      final admin = context.read<AdminController>();
      await admin.markPaymentsPaid(
        widget.userId,
        paymentIds: payments.map((p) => p.paymentId).toList(),
        method: method,
      );
      final member = await admin.loadMemberDetail(widget.userId);
      final updatedPayments = await admin.loadMemberPayments(widget.userId);
      if (!mounted) return;
      setState(() {
        _member = member;
        _payments = updatedPayments;
        _markingSelectedPayments = false;
      });
      final count = payments.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count == 1
                ? "Recorded payment for ${payments.first.description ?? payments.first.typeLabel}"
                : "Recorded payment for $count charges",
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = adminActionErrorMessage(e);
        _markingSelectedPayments = false;
      });
    }
  }

  void _showMarkPaidSheet({
    PaymentItem? payment,
    List<PaymentItem>? selectedPayments,
  }) {
    final selectedCount = selectedPayments?.length ?? 0;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selectedCount > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  "Mark $selectedCount charges as paid",
                  style: Theme.of(ctx).textTheme.titleSmall,
                ),
              ),
            ListTile(
              title: const Text("Cash"),
              onTap: () {
                Navigator.pop(ctx);
                if (selectedPayments != null && selectedPayments.isNotEmpty) {
                  _markSelectedPaymentsPaid(selectedPayments, "cash");
                } else if (payment != null) {
                  _markPaymentPaid(payment, "cash");
                } else {
                  _markMembershipPaid("cash");
                }
              },
            ),
            ListTile(
              title: const Text("EFTPOS"),
              onTap: () {
                Navigator.pop(ctx);
                if (selectedPayments != null && selectedPayments.isNotEmpty) {
                  _markSelectedPaymentsPaid(selectedPayments, "eftpos");
                } else if (payment != null) {
                  _markPaymentPaid(payment, "eftpos");
                } else {
                  _markMembershipPaid("eftpos");
                }
              },
            ),
            ListTile(
              title: const Text("Bank transfer"),
              onTap: () {
                Navigator.pop(ctx);
                if (selectedPayments != null && selectedPayments.isNotEmpty) {
                  _markSelectedPaymentsPaid(selectedPayments, "bank");
                } else if (payment != null) {
                  _markPaymentPaid(payment, "bank");
                } else {
                  _markMembershipPaid("bank");
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTopUpSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => _TopUpSheet(
        onSubmit: (amountCents, method) async {
          Navigator.pop(sheetContext);
          if (!mounted) return;
          await _recordTopUp(amountCents, method);
        },
      ),
    );
  }

  Future<void> _recordTopUp(int amountCents, String method) async {
    if (_recordingTopUp) return;
    setState(() {
      _recordingTopUp = true;
      _error = null;
    });
    try {
      final admin = context.read<AdminController>();
      await admin.recordMemberTopUp(
        widget.userId,
        amountCents: amountCents,
        method: method,
      );
      final member = await admin.loadMemberDetail(widget.userId);
      final payments = await admin.loadMemberPayments(widget.userId);
      if (!mounted) return;
      setState(() {
        _member = member;
        _payments = payments;
        _recordingTopUp = false;
        _paymentsExpanded = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Recorded top-up of ${formatDueCents(amountCents)}"),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = adminActionErrorMessage(e);
        _recordingTopUp = false;
      });
    }
  }

  Future<void> _reloadLoans() async {
    try {
      final loans = await context
          .read<AdminController>()
          .loadMemberLoans(widget.userId);
      if (!mounted) return;
      setState(() {
        _loans = loans;
        _loansLoadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loansLoadError = adminActionErrorMessage(e);
      });
    }
  }

  Future<void> _openCheckInForDueDate(DateTime dueDate) async {
    final name = _member?.displayName ??
        widget.initialMember?.displayName ??
        "Member";
    final initialLoans = _loans
        .where(
          (loan) =>
              loan.isActive && _loanSameDay(loan.returnSessionDate, dueDate),
        )
        .toList();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminMemberCheckInScreen(
          memberUserId: widget.userId,
          memberName: name,
          dueDate: dueDate,
          initialLoans: initialLoans,
        ),
      ),
    );
    if (!mounted) return;
    await _reloadLoans();
  }

  void _openToy(String toyId) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => ToyDetailScreen(toyId: toyId),
      ),
    );
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
    final parentBName = member?.contact.parentBName;
    final headingLabel = memberDisplayLabel(
      fullName: displayName,
      parentBName: parentBName,
    );
    final heading = headingLabel.isNotEmpty ? headingLabel : displayName;
    final email = member?.email ?? widget.initialMember?.email ?? "";
    final showSkeleton = _loading && member == null;

    return Scaffold(
      appBar: AppBar(
        title: const SizedBox.shrink(),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          ListView(
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
                      parentBName: parentBName,
                      avatarPath: member?.avatarPath,
                      radius: AdminMemberProfileScreen.avatarRadius,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      heading,
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
                if (showSkeleton)
                  const _ProfileSectionsSkeleton()
                else ...[
                _AdminProfileSection(
                  title: "Payments",
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      child: _AdminMemberPaymentsBody(
                        member: member,
                        payments: _payments,
                        expanded: _paymentsExpanded,
                        payingPaymentId: _payingPaymentId,
                        recordingMembership: _recordingMembership,
                        recordingTopUp: _recordingTopUp,
                        markingSelectedPayments: _markingSelectedPayments,
                        onToggle: () => setState(
                          () => _paymentsExpanded = !_paymentsExpanded,
                        ),
                        onMarkMembershipPaid: () => _showMarkPaidSheet(),
                        onMarkPaymentPaid: (payment) =>
                            _showMarkPaidSheet(payment: payment),
                        onMarkAllPendingPaid: (payments) =>
                            _showMarkPaidSheet(selectedPayments: payments),
                        onAddTopUp: _showTopUpSheet,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _AdminProfileSection(
                  title: "Loans",
                  children: [
                    if (_loansLoadError != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Text(
                          _loansLoadError!,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    if (_loans.isEmpty && _loansLoadError == null)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          "No loans yet.",
                          style: context.listSubtitle,
                        ),
                      )
                    else if (_loans.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: _AdminMemberLoansBody(
                          loans: _loans,
                          activeExpanded: _activeLoansExpanded,
                          onToggleActive: () => setState(
                            () => _activeLoansExpanded = !_activeLoansExpanded,
                          ),
                          returnedExpanded: _returnedLoansExpanded,
                          onToggleReturned: () => setState(
                            () => _returnedLoansExpanded =
                                !_returnedLoansExpanded,
                          ),
                          onOpenDueDate: _openCheckInForDueDate,
                          onOpenToy: _openToy,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                if (member != null &&
                    (member.role == "volunteer" ||
                        member.membershipTier == "duty")) ...[
                  CollapsibleSection(
                    title: adminDutyShiftsSectionTitle(
                      member.dutySessionsCompleted,
                    ),
                    titleColor: isDutyRequirementMet(member.dutySessionsCompleted)
                        ? kDutyCompleteFg
                        : null,
                    headerBackgroundColor:
                        isDutyRequirementMet(member.dutySessionsCompleted)
                            ? kDutyCompleteBg
                            : null,
                    headerBorderColor:
                        isDutyRequirementMet(member.dutySessionsCompleted)
                            ? kDutyCompleteBorder
                            : null,
                    expanded: _dutyExpanded,
                    onToggle: () =>
                        setState(() => _dutyExpanded = !_dutyExpanded),
                    children: [
                      VolunteerDutyShiftsBody(
                        active: _dutyExpanded,
                        loadSessions: () => context
                            .read<AdminController>()
                            .loadMemberDutySessions(widget.userId),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
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
                if (member != null) ...[
                  CollapsibleSection(
                    title: "Contact & membership form",
                    expanded: _contactExpanded,
                    onToggle: () =>
                        setState(() => _contactExpanded = !_contactExpanded),
                    children: [
                      ContactDetailsBody(contact: member.contact),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
                _AdminProfileSection(
                  title: "Children",
                  onEdit: _saving ? null : _toggleChildrenEdit,
                  editing: _editingChildren,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      child: _editingChildren
                          ? _ChildrenEditor(
                              key: const ValueKey("admin-children-editor"),
                              kids: _editableKids,
                              saving: _saving,
                              onAddKid: _addKid,
                              onRemoveKid: _removeKid,
                              formatBirthDate: _formatBirthDate,
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
              ],
            ),
          if (_loading)
            Positioned.fill(
              child: IgnorePointer(
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                    child: ColoredBox(
                      color: theme.scaffoldBackgroundColor.withValues(alpha: 0.55),
                      child: const Center(
                        child: ToyLibraryLoadingIndicator(
                          message: "Loading profile…",
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfileSectionsSkeleton extends StatelessWidget {
  const _ProfileSectionsSkeleton();

  static const _titles = [
    "Payments",
    "Loans",
    "Membership",
    "Contact & membership form",
    "Children",
    "Admin notes",
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < _titles.length; i++) ...[
          if (i > 0) SizedBox(height: i == 3 || i == 4 ? 24 : 20),
          _ProfileSectionSkeleton(title: _titles[i]),
        ],
      ],
    );
  }
}

class _ProfileSectionSkeleton extends StatelessWidget {
  const _ProfileSectionSkeleton({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final fill = Theme.of(context)
        .colorScheme
        .onSurface
        .withValues(alpha: 0.08);

    return _AdminProfileSection(
      title: title,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 14,
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 10),
              FractionallySizedBox(
                widthFactor: 0.62,
                alignment: Alignment.centerLeft,
                child: Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: fill,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AdminMemberPaymentsBody extends StatelessWidget {
  const _AdminMemberPaymentsBody({
    required this.member,
    required this.payments,
    required this.expanded,
    required this.payingPaymentId,
    required this.recordingMembership,
    required this.recordingTopUp,
    required this.markingSelectedPayments,
    required this.onToggle,
    required this.onMarkMembershipPaid,
    required this.onMarkPaymentPaid,
    required this.onMarkAllPendingPaid,
    required this.onAddTopUp,
  });

  final AdminMemberDetail? member;
  final List<PaymentItem> payments;
  final bool expanded;
  final String? payingPaymentId;
  final bool recordingMembership;
  final bool recordingTopUp;
  final bool markingSelectedPayments;
  final VoidCallback onToggle;
  final VoidCallback onMarkMembershipPaid;
  final ValueChanged<PaymentItem> onMarkPaymentPaid;
  final ValueChanged<List<PaymentItem>> onMarkAllPendingPaid;
  final VoidCallback onAddTopUp;

  bool _isMembershipCharge(PaymentItem payment) =>
      payment.paymentType == "membership" || payment.paymentType == "bond";

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final balanceCents = member?.balanceDueCents ?? 0;
    final creditCents = member?.creditBalanceCents ?? 0;
    final pendingPayments = payments.where((p) => p.isPending).toList();
    final pendingCount = pendingPayments.length;
    final pendingTotalCents = pendingPayments.fold<int>(
      0,
      (sum, payment) => sum + payment.amountCents,
    );
    final pendingMembershipCharges =
        pendingPayments.where(_isMembershipCharge).toList();
    final showMembershipSummary = member != null &&
        !member!.membershipFeesPaid &&
        member!.membershipDueCents > 0 &&
        pendingMembershipCharges.isEmpty;
    final chargesLabel = pendingCount > 0
        ? "Charges ($pendingCount pending)"
        : "Charges (${payments.length})";
    final paymentActionsBusy = payingPaymentId != null ||
        recordingMembership ||
        recordingTopUp ||
        markingSelectedPayments;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              color: balanceCents > 0
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    balanceCents > 0
                        ? "Balance owing: ${formatDueCents(balanceCents)}"
                        : creditCents > 0
                            ? "Account credit: ${formatDueCents(creditCents)}"
                            : "Nothing owing",
                    style: context.cardTitle.copyWith(
                      color: balanceCents > 0 ? theme.colorScheme.error : null,
                    ),
                  ),
                  if (creditCents > 0 && balanceCents > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        "Account credit: ${formatDueCents(creditCents)}",
                        style: context.listSubtitle,
                      ),
                    ),
                  if (pendingCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        pendingCount == 1
                            ? "1 pending charge below"
                            : "$pendingCount pending charges below",
                        style: context.listSubtitle,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (pendingMembershipCharges.length > 1) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: paymentActionsBusy ? null : onMarkMembershipPaid,
              child: Text(
                recordingMembership
                    ? "Recording membership payment…"
                    : "Mark all membership paid",
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
        BrandChipButton(
          label: recordingTopUp ? "Recording top-up…" : "Add top-up",
          onPressed: paymentActionsBusy ? null : onAddTopUp,
        ),
        if (pendingCount > 1) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: BrandChipButton(
              large: true,
              variant: BrandChipButtonVariant.outlined,
              backgroundColor: Colors.white,
              label: markingSelectedPayments
                  ? "Recording payment…"
                  : "Mark all pending paid · ${formatDueCents(pendingTotalCents)}",
              onPressed: paymentActionsBusy
                  ? null
                  : () => onMarkAllPendingPaid(pendingPayments),
            ),
          ),
        ],
        const SizedBox(height: 12),
        CollapsibleSection(
          title: payments.isEmpty ? "Charges" : chargesLabel,
          expanded: expanded,
          onToggle: onToggle,
          children: [
            if (showMembershipSummary) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text("Membership", style: context.bodyText),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          formatDueCents(member!.membershipDueCents),
                          style: context.bodyText.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const BookingStatusChip(status: "pending", width: 88),
                        const Spacer(),
                        _AdminMarkPaidChip(
                          processing: recordingMembership,
                          enabled: !paymentActionsBusy,
                          onPressed: onMarkMembershipPaid,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (payments.isNotEmpty)
                Divider(
                  height: 1,
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
            ],
            if (payments.isEmpty &&
                (member == null ||
                    member!.membershipFeesPaid ||
                    !showMembershipSummary))
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                child: Text(
                  "No payment records yet.",
                  style: context.listSubtitle,
                ),
              )
            else if (payments.isNotEmpty)
              PaymentsGroupedByDate(
                payments: payments,
                itemBuilder: (payment) => _AdminPaymentRow(
                  payment: payment,
                  processing: payingPaymentId == payment.paymentId,
                  actionsEnabled: !paymentActionsBusy,
                  onMarkPaid: () => onMarkPaymentPaid(payment),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _AdminPaymentRow extends StatelessWidget {
  const _AdminPaymentRow({
    required this.payment,
    required this.processing,
    required this.actionsEnabled,
    required this.onMarkPaid,
  });

  final PaymentItem payment;
  final bool processing;
  final bool actionsEnabled;
  final VoidCallback onMarkPaid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = payment.description ?? payment.typeLabel;
    final amountColor = payment.isCreditGrant && !payment.isPending
        ? theme.colorScheme.primary
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(title, style: context.bodyText),
              ),
              const SizedBox(width: 12),
              Text(
                payment.displayAmountLabel,
                style: context.bodyText.copyWith(
                  fontWeight: FontWeight.w700,
                  color: amountColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (payment.isPending)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: kGroupHeaderBackground,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kGroupHeaderBorder),
                  ),
                  child: Text(
                    "Pending",
                    style: context.listSubtitle.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                    ),
                  ),
                )
              else
                Text(
                  payment.statusLabel,
                  style: context.listSubtitle.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              const Spacer(),
              if (payment.isPending)
                _AdminMarkPaidChip(
                  processing: processing,
                  enabled: actionsEnabled,
                  onPressed: onMarkPaid,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdminMarkPaidChip extends StatelessWidget {
  const _AdminMarkPaidChip({
    required this.processing,
    required this.enabled,
    required this.onPressed,
  });

  final bool processing;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (processing) {
      return const SizedBox(
        width: 100,
        height: 32,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: ToyLibraryLoadingIndicator.compact(),
          ),
        ),
      );
    }

    return BrandChipButton(
      label: "Mark paid",
      fixedWidth: 100,
      variant: BrandChipButtonVariant.filled,
      onPressed: enabled ? onPressed : null,
    );
  }
}

bool _loanSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class _AdminMemberLoansBody extends StatelessWidget {
  const _AdminMemberLoansBody({
    required this.loans,
    required this.activeExpanded,
    required this.onToggleActive,
    required this.returnedExpanded,
    required this.onToggleReturned,
    required this.onOpenDueDate,
    required this.onOpenToy,
  });

  final List<LoanItem> loans;
  final bool activeExpanded;
  final VoidCallback onToggleActive;
  final bool returnedExpanded;
  final VoidCallback onToggleReturned;
  final ValueChanged<DateTime> onOpenDueDate;
  final ValueChanged<String> onOpenToy;

  @override
  Widget build(BuildContext context) {
    final sections = groupLoansBySection(loans);
    final activeCount = sections.activeByDueDate.fold<int>(
      0,
      (sum, group) => sum + group.loans.length,
    );

    Widget activeGroups() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var g = 0; g < sections.activeByDueDate.length; g++) ...[
            if (g > 0) const SizedBox(height: 12),
            LoanDueDateSection(
              group: sections.activeByDueDate[g],
              onHeaderTap: () =>
                  onOpenDueDate(sections.activeByDueDate[g].dueDate),
              children: [
                for (final loan in sections.activeByDueDate[g].loans)
                  LoanListTile(
                    item: loan,
                    loading: false,
                    inGroup: true,
                    onOpen: () {},
                  ),
              ],
            ),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (activeCount > 0)
          CollapsibleSection(
            title: "Active ($activeCount)",
            expanded: activeExpanded,
            onToggle: onToggleActive,
            children: [activeGroups()],
          ),
        if (activeCount > 0 && sections.returned.isNotEmpty)
          const SizedBox(height: 16),
        if (sections.returned.isNotEmpty)
          CollapsibleSection(
            title: "Loan history (${sections.returned.length})",
            expanded: returnedExpanded,
            onToggle: onToggleReturned,
            children: [
              for (var i = 0; i < sections.returned.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                LoanListTile(
                  item: sections.returned[i],
                  loading: false,
                  onOpen: () => onOpenToy(sections.returned[i].toyId),
                ),
              ],
            ],
          ),
        if (activeCount == 0 &&
            sections.returned.isEmpty &&
            loans.isNotEmpty) ...[
          const SectionHeader("Loans"),
          for (var i = 0; i < loans.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            LoanListTile(
              item: loans[i],
              loading: false,
              onOpen: loans[i].isActive ? () {} : () => onOpenToy(loans[i].toyId),
            ),
          ],
        ],
      ],
    );
  }
}

class _ChildrenEditor extends StatefulWidget {
  const _ChildrenEditor({
    super.key,
    required this.kids,
    required this.saving,
    required this.onAddKid,
    required this.onRemoveKid,
    required this.formatBirthDate,
  });

  final List<KidProfile> kids;
  final bool saving;
  final Future<void> Function(String name, DateTime birthDate) onAddKid;
  final Future<void> Function(int index) onRemoveKid;
  final String Function(DateTime) formatBirthDate;

  @override
  State<_ChildrenEditor> createState() => _ChildrenEditorState();
}

class _ChildrenEditorState extends State<_ChildrenEditor> {
  late final TextEditingController _nameController;
  DateTime? _birthDate;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final picked = await showDatePicker(
      context: context,
      useRootNavigator: true,
      initialDate: _birthDate ?? DateTime(DateTime.now().year - 5),
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
      helpText: "Child date of birth",
    );
    if (picked != null && mounted) {
      setState(() => _birthDate = picked);
    }
  }

  Future<void> _submitKid() async {
    if (_adding || widget.saving) return;
    final name = _nameController.text.trim();
    final birthDate = _birthDate;
    if (name.isEmpty || birthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a name and date of birth")),
      );
      return;
    }
    setState(() => _adding = true);
    try {
      await widget.onAddKid(name, birthDate);
    } finally {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _nameController.clear();
        setState(() {
          _birthDate = null;
          _adding = false;
        });
      });
    }
  }

  Future<void> _removeKid(int index) async {
    if (_adding || widget.saving) return;
    setState(() => _adding = true);
    try {
      await widget.onRemoveKid(index);
    } finally {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _adding = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kids = widget.kids;
    final busy = widget.saving || _adding;
    final birthDate = _birthDate;

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
                onDeleted: busy ? null : () => _removeKid(entry.key),
              );
            }).toList(),
          ),
        const SizedBox(height: 12),
        TextField(
          controller: _nameController,
          enabled: !busy,
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
          onTap: busy ? null : _pickBirthDate,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: labeledInputDecoration(
              context,
              labelText: "Date of birth",
              fillColor: theme.colorScheme.surface,
              suffixIcon: birthDate == null
                  ? Icon(
                      Icons.calendar_today_outlined,
                      size: 20,
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.55),
                    )
                  : GestureDetector(
                      onTap: busy ? null : () => setState(() => _birthDate = null),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Icon(
                          Icons.clear,
                          size: 20,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.55),
                        ),
                      ),
                    ),
            ),
            child: Text(
              birthDate == null
                  ? "Select date"
                  : widget.formatBirthDate(birthDate),
              style: birthDate == null
                  ? fieldPlaceholderStyle(context)
                  : fieldTextStyle(context),
            ),
          ),
        ),
        const SizedBox(height: 12),
        BrandChipButton(
          label: busy ? "Saving…" : "Add child",
          onPressed: busy ? null : _submitKid,
        ),
      ],
    );
  }
}

class _TopUpSheet extends StatefulWidget {
  const _TopUpSheet({
    required this.onSubmit,
  });

  final Future<void> Function(int amountCents, String method) onSubmit;

  @override
  State<_TopUpSheet> createState() => _TopUpSheetState();
}

class _TopUpSheetState extends State<_TopUpSheet> {
  late final TextEditingController _amountController;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit(String method) async {
    if (_submitting) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final cents = parseDollarAmountToCents(_amountController.text);
    if (cents == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a valid dollar amount.")),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(cents, method);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(0, 0, 0, bottomInset),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Text("Add top-up", style: context.cardTitle),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: TextField(
                controller: _amountController,
                autofocus: true,
                enabled: !_submitting,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: fieldTextStyle(context),
                cursorColor: fieldCursorColor(context),
                decoration: labeledInputDecoration(
                  context,
                  labelText: "Amount (NZD)",
                  hintText: "e.g. 20.00",
                  fillColor: theme.colorScheme.surface,
                ),
                textInputAction: TextInputAction.done,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text(
                "Payment method",
                style: context.groupLabel,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.payments_outlined),
              title: const Text("Cash"),
              enabled: !_submitting,
              onTap: _submitting ? null : () => _submit("cash"),
            ),
            ListTile(
              leading: const Icon(Icons.credit_card_outlined),
              title: const Text("EFTPOS"),
              enabled: !_submitting,
              onTap: _submitting ? null : () => _submit("eftpos"),
            ),
            ListTile(
              leading: const Icon(Icons.account_balance_outlined),
              title: const Text("Bank transfer"),
              enabled: !_submitting,
              onTap: _submitting ? null : () => _submit("bank"),
            ),
            if (_submitting)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: ToyLibraryLoadingIndicator()),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
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
