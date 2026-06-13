import "dart:async";

import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../core/app_text_styles.dart";
import "../../core/app_input_field.dart";
import "../../core/search_field.dart";
import "../../core/brand_chip_button.dart";
import "../catalog/catalog_models.dart";
import "desk_member.dart";
import "desk_checkout_dialog.dart";
import "loans_controller.dart";
import "../payments/payment_models.dart";

/// Walk-in checkout: pick a member, then add one or more toys to check out.
class DeskWalkInPanel extends StatefulWidget {
  const DeskWalkInPanel({
    super.key,
    required this.loading,
    required this.onCheckedOut,
    this.onDraftChanged,
  });

  final bool loading;
  final VoidCallback onCheckedOut;

  /// Called when a member or toy is selected for walk-in (draft in progress).
  final ValueChanged<bool>? onDraftChanged;

  @override
  State<DeskWalkInPanel> createState() => _DeskWalkInPanelState();
}

class _DeskWalkInPanelState extends State<DeskWalkInPanel> {
  final _toyQuery = TextEditingController();
  final _memberQuery = TextEditingController();
  Timer? _toyDebounce;
  Timer? _memberDebounce;

  DeskMember? _selectedMember;
  final List<ToyItem> _selectedToys = [];
  List<ToyItem> _toyResults = [];
  List<DeskMember> _memberResults = [];
  bool _searchingToys = false;
  bool _searchingMembers = false;
  bool _submitting = false;
  String? _error;

  bool get _hasMember => _selectedMember != null;

  bool get _hasDraft => _hasMember || _selectedToys.isNotEmpty;

  void _notifyDraftChanged() {
    widget.onDraftChanged?.call(_hasDraft);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _notifyDraftChanged());
  }

  @override
  void dispose() {
    _toyDebounce?.cancel();
    _memberDebounce?.cancel();
    _toyQuery.dispose();
    _memberQuery.dispose();
    super.dispose();
  }

  void _clearMember() {
    setState(() {
      _selectedMember = null;
      _selectedToys.clear();
      _memberQuery.clear();
      _memberResults = [];
      _toyQuery.clear();
      _toyResults = [];
      _error = null;
    });
    _notifyDraftChanged();
  }

  void _selectMember(DeskMember member) {
    setState(() {
      _selectedMember = member;
      _memberQuery.clear();
      _memberResults = [];
      _error = null;
    });
    _notifyDraftChanged();
  }

  void _addToy(ToyItem toy) {
    if (_selectedToys.any((item) => item.toyId == toy.toyId)) return;
    setState(() {
      _selectedToys.add(toy);
      _toyQuery.clear();
      _toyResults = [];
      _error = null;
    });
    _notifyDraftChanged();
  }

  void _removeToy(String toyId) {
    setState(() {
      _selectedToys.removeWhere((item) => item.toyId == toyId);
      _error = null;
    });
    _notifyDraftChanged();
  }

  void _scheduleToySearch() {
    if (!_hasMember) return;
    _toyDebounce?.cancel();
    _toyDebounce = Timer(const Duration(milliseconds: 350), () async {
      final query = _toyQuery.text.trim();
      if (!_isSearchableToyQuery(query)) {
        if (!mounted) return;
        setState(() {
          _toyResults = [];
          _searchingToys = false;
        });
        return;
      }
      setState(() {
        _searchingToys = true;
        _error = null;
      });
      try {
        final results =
            await context.read<LoansController>().searchDeskToys(query);
        if (!mounted) return;
        final selectedIds = _selectedToys.map((t) => t.toyId).toSet();
        setState(() {
          _toyResults =
              results.where((toy) => !selectedIds.contains(toy.toyId)).toList();
          _searchingToys = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _toyResults = [];
          _searchingToys = false;
          _error = e.toString();
        });
      }
    });
  }

  void _scheduleMemberSearch() {
    _memberDebounce?.cancel();
    _memberDebounce = Timer(const Duration(milliseconds: 350), () async {
      final query = _memberQuery.text.trim();
      if (query.length < 2) {
        if (!mounted) return;
        setState(() {
          _memberResults = [];
          _searchingMembers = false;
        });
        return;
      }
      setState(() {
        _searchingMembers = true;
        _error = null;
      });
      try {
        final results =
            await context.read<LoansController>().searchDeskMembers(query);
        if (!mounted) return;
        setState(() {
          _memberResults = results;
          _searchingMembers = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _memberResults = [];
          _searchingMembers = false;
          _error = e.toString();
        });
      }
    });
  }

  Future<void> _submit() async {
    final member = _selectedMember;
    if (member == null || _selectedToys.isEmpty) return;

    final checkout = await showDeskCheckoutDialog(
      context,
      memberLabel: member.displayLabel,
      memberBalanceDueCents: member.balanceDueCents,
      memberCreditBalanceCents: member.creditBalanceCents,
      lines: _selectedToys
          .map(
            (toy) => DeskCheckoutLine(
              toyId: toy.toyId,
              toyName: toy.name,
              rentalPriceCents: toy.rentalPriceCents,
            ),
          )
          .toList(),
    );
    if (checkout == null || !mounted) return;

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final controller = context.read<LoansController>();
      for (final toy in _selectedToys) {
        await controller.checkOutWalkIn(
          userId: member.userId,
          toyId: toy.toyId,
          rentalPayment: checkout.rentalPayment,
          paymentMethod: checkout.paymentMethod,
        );
      }
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _selectedMember = null;
        _selectedToys.clear();
        _toyQuery.clear();
        _memberQuery.clear();
        _toyResults = [];
        _memberResults = [];
      });
      _notifyDraftChanged();
      widget.onCheckedOut();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = loanActionErrorMessage(e);
      });
    }
  }

  String _toyChipLabel(ToyItem toy) {
    final price = toy.rentalPriceCents != null && toy.rentalPriceCents! > 0
        ? formatDueCents(toy.rentalPriceCents!)
        : null;
    if (price != null) {
      return "${toy.name} (${toy.toyId}) · $price";
    }
    return "${toy.name} (${toy.toyId})";
  }

  String get _checkoutLabel {
    final count = _selectedToys.length;
    if (count <= 1) return "Check out";
    return "Check out ($count)";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final busy = widget.loading || _submitting;
    final canSubmit = _hasMember && _selectedToys.isNotEmpty && !busy;

    return Material(
      color: theme.colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Walk-in checkout",
              style: context.panelTitle,
            ),
            const SizedBox(height: 10),
            Text(
              "Member",
              style: context.groupLabel,
            ),
            const SizedBox(height: 6),
            if (_hasMember)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SelectionChip(
                    label: _selectedMember!.displayLabel,
                    onClear: busy ? null : _clearMember,
                  ),
                  if (_selectedMember!.creditBalanceCents > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      "Account credit: "
                      "${formatDueCents(_selectedMember!.creditBalanceCents)}",
                      style: context.listSubtitle.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                  if (_selectedMember!.balanceDueCents > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      "Balance owing: "
                      "${formatDueCents(_selectedMember!.balanceDueCents)}",
                      style: context.listSubtitle.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ],
              )
            else ...[
              TextField(
                controller: _memberQuery,
                enabled: !busy,
                style: fieldTextStyle(context),
                cursorColor: fieldCursorColor(context),
                decoration: searchInputDecoration(
                  context,
                  hintText: "Search name or email",
                  suffixIcon: _searchingMembers
                      ? searchLoadingSuffix()
                      : null,
                ),
                onChanged: (_) => _scheduleMemberSearch(),
              ),
              if (_memberResults.isNotEmpty) ...[
                const SizedBox(height: 8),
                ..._memberResults.map(
                  (member) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(member.displayLabel),
                    onTap: busy ? null : () => _selectMember(member),
                  ),
                ),
              ],
            ],
            if (_hasMember) ...[
              const SizedBox(height: 16),
              Text(
                "Toys",
                style: context.groupLabel,
              ),
              const SizedBox(height: 6),
              if (_selectedToys.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _selectedToys
                      .map(
                        (toy) => _SelectionChip(
                          label: _toyChipLabel(toy),
                          onClear:
                              busy ? null : () => _removeToy(toy.toyId),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 8),
              ],
              TextField(
                controller: _toyQuery,
                enabled: !busy,
                style: fieldTextStyle(context),
                cursorColor: fieldCursorColor(context),
                decoration: searchInputDecoration(
                  context,
                  hintText: "Search toy id or name to add",
                  suffixIcon:
                      _searchingToys ? searchLoadingSuffix() : null,
                ),
                onChanged: (_) => _scheduleToySearch(),
              ),
              if (_toyResults.isNotEmpty) ...[
                const SizedBox(height: 8),
                ..._toyResults.map(
                  (toy) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(toy.name),
                    subtitle: Text(toy.toyId),
                    onTap: busy ? null : () => _addToy(toy),
                  ),
                ),
              ] else if (_selectedToys.isEmpty &&
                  !_isSearchableToyQuery(_toyQuery.text))
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    "Add one or more toys for this member.",
                    style: context.listSubtitle,
                  ),
                ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  "Select a member first, then add toys.",
                  style: context.listSubtitle,
                ),
              ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: BrandChipButton(
                label: _checkoutLabel,
                fixedWidth: 140,
                onPressed: canSubmit ? _submit : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectionChip extends StatelessWidget {
  const _SelectionChip({required this.label, this.onClear});

  final String label;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      label: Text(label),
      onDeleted: onClear,
    );
  }
}

bool _isSearchableToyQuery(String query) {
  final q = query.trim();
  if (q.isEmpty) return false;
  if (q.length >= 2) return true;
  return RegExp(r"^\d+$").hasMatch(q);
}
