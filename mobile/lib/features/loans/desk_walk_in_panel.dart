import "dart:async";

import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../core/app_theme.dart";
import "../../core/brand_chip_button.dart";
import "../catalog/catalog_models.dart";
import "desk_member.dart";
import "loans_controller.dart";

/// Walk-in checkout: search toy + member, then check out for 2 weeks.
class DeskWalkInPanel extends StatefulWidget {
  const DeskWalkInPanel({
    super.key,
    required this.loading,
    required this.onCheckedOut,
  });

  final bool loading;
  final VoidCallback onCheckedOut;

  @override
  State<DeskWalkInPanel> createState() => _DeskWalkInPanelState();
}

class _DeskWalkInPanelState extends State<DeskWalkInPanel> {
  final _toyQuery = TextEditingController();
  final _memberQuery = TextEditingController();
  Timer? _toyDebounce;
  Timer? _memberDebounce;

  ToyItem? _selectedToy;
  DeskMember? _selectedMember;
  List<ToyItem> _toyResults = [];
  List<DeskMember> _memberResults = [];
  bool _searchingToys = false;
  bool _searchingMembers = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _toyDebounce?.cancel();
    _memberDebounce?.cancel();
    _toyQuery.dispose();
    _memberQuery.dispose();
    super.dispose();
  }

  void _scheduleToySearch() {
    _toyDebounce?.cancel();
    _toyDebounce = Timer(const Duration(milliseconds: 350), () async {
      final query = _toyQuery.text.trim();
      if (query.length < 2) {
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
        setState(() {
          _toyResults = results;
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
    final toy = _selectedToy;
    final member = _selectedMember;
    if (toy == null || member == null) return;

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await context.read<LoansController>().checkOutWalkIn(
            userId: member.userId,
            toyId: toy.toyId,
          );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _selectedToy = null;
        _selectedMember = null;
        _toyQuery.clear();
        _memberQuery.clear();
        _toyResults = [];
        _memberResults = [];
      });
      widget.onCheckedOut();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = loanActionErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final busy = widget.loading || _submitting;
    final canSubmit = _selectedToy != null && _selectedMember != null && !busy;

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
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: kBrandOnYellow,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _toyQuery,
              enabled: !busy,
              decoration: InputDecoration(
                labelText: "Toy id or name",
                suffixIcon: _searchingToys
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
              onChanged: (_) {
                setState(() => _selectedToy = null);
                _scheduleToySearch();
              },
            ),
            if (_selectedToy != null) ...[
              const SizedBox(height: 8),
              _SelectionChip(
                label: "${_selectedToy!.name} (${_selectedToy!.toyId})",
                onClear: busy
                    ? null
                    : () => setState(() {
                          _selectedToy = null;
                          _toyQuery.clear();
                          _toyResults = [];
                        }),
              ),
            ] else if (_toyResults.isNotEmpty) ...[
              const SizedBox(height: 8),
              ..._toyResults.map(
                (toy) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(toy.name),
                  subtitle: Text(toy.toyId),
                  onTap: busy
                      ? null
                      : () => setState(() {
                            _selectedToy = toy;
                            _toyQuery.text = toy.name;
                            _toyResults = [];
                          }),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _memberQuery,
              enabled: !busy,
              decoration: InputDecoration(
                labelText: "Member name or email",
                suffixIcon: _searchingMembers
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
              onChanged: (_) {
                setState(() => _selectedMember = null);
                _scheduleMemberSearch();
              },
            ),
            if (_selectedMember != null) ...[
              const SizedBox(height: 8),
              _SelectionChip(
                label: _selectedMember!.displayLabel,
                onClear: busy
                    ? null
                    : () => setState(() {
                          _selectedMember = null;
                          _memberQuery.clear();
                          _memberResults = [];
                        }),
              ),
            ] else if (_memberResults.isNotEmpty) ...[
              const SizedBox(height: 8),
              ..._memberResults.map(
                (member) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(member.displayLabel),
                  onTap: busy
                      ? null
                      : () => setState(() {
                            _selectedMember = member;
                            _memberQuery.text = member.displayLabel;
                            _memberResults = [];
                          }),
                ),
              ),
            ],
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
                label: "Check out",
                fixedWidth: 120,
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
