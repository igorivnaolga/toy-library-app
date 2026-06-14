import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../loans/desk_member.dart";
import "../../core/app_text_styles.dart";
import "../../core/app_theme.dart";
import "../../core/app_input_field.dart";
import "../../core/search_field.dart";
import "../../core/brand_chip_button.dart";
import "duty_controller.dart";
import "duty_session_models.dart";

Future<void> showDutyAssignSheet(
  BuildContext context,
  String sessionId,
) async {
  if (!context.mounted) return;
  await Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => DutyAssignScreen(sessionId: sessionId),
    ),
  );
}

/// Admin UI to assign or clear a volunteer on a duty slot.
class DutyAssignScreen extends StatefulWidget {
  const DutyAssignScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  State<DutyAssignScreen> createState() => _DutyAssignScreenState();
}

class _DutyAssignScreenState extends State<DutyAssignScreen> {
  List<DeskMember> _rosterCache = [];
  bool _loadingRoster = false;
  bool _assigning = false;
  String? _error;
  Future<List<DeskMember>>? _rosterLoad;

  DutySessionItem? _session(DutyController controller) {
    for (final item in controller.sessions) {
      if (item.sessionId == widget.sessionId) return item;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rosterLoad = _loadRosterCache();
    });
  }

  Future<List<DeskMember>> _loadRosterCache() async {
    final session = _session(context.read<DutyController>());
    if (session == null || !session.isOpen) return [];

    setState(() {
      _loadingRoster = true;
      _error = null;
    });
    try {
      final members =
          await context.read<DutyController>().searchRosterMembers("");
      if (!mounted) return members;
      setState(() {
        _rosterCache = members;
        _loadingRoster = false;
      });
      return members;
    } catch (e) {
      if (!mounted) return [];
      setState(() {
        _loadingRoster = false;
        _error = dutyActionErrorMessage(e);
      });
      return [];
    }
  }

  Future<void> _ensureRosterLoaded() async {
    _rosterLoad ??= _loadRosterCache();
    await _rosterLoad;
  }

  List<DeskMember> _filterLocal(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return _rosterCache
        .where(
          (m) =>
              m.fullName.toLowerCase().contains(q) ||
              m.email.toLowerCase().contains(q) ||
              m.userId.toLowerCase().contains(q),
        )
        .toList();
  }

  List<DeskMember> _mergeResults(
    List<DeskMember> local,
    List<DeskMember> remote,
  ) {
    final seen = <String>{};
    final merged = <DeskMember>[];
    for (final member in [...local, ...remote]) {
      if (member.userId.isEmpty || seen.contains(member.userId)) continue;
      seen.add(member.userId);
      merged.add(member);
    }
    return merged;
  }

  Future<Iterable<DeskMember>> _memberSuggestions(String query) async {
    await _ensureRosterLoaded();
    final q = query.trim();
    if (q.isEmpty) return const [];

    var results = _filterLocal(q);
    if (q.isNotEmpty) {
      try {
        final remote =
            await context.read<DutyController>().searchRosterMembers(q);
        results = _mergeResults(results, remote);
      } catch (e) {
        if (mounted && _error == null) {
          setState(() => _error = dutyActionErrorMessage(e));
        }
      }
    }
    return results;
  }

  Future<void> _assign(DeskMember member) async {
    setState(() {
      _assigning = true;
      _error = null;
    });
    try {
      await context.read<DutyController>().assignMember(
            widget.sessionId,
            member,
          );
      if (!mounted) return;
      setState(() => _assigning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Assigned ${member.displayLabel}")),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _assigning = false;
        _error = dutyActionErrorMessage(e);
      });
    }
  }

  Future<void> _clear() async {
    setState(() {
      _assigning = true;
      _error = null;
    });
    try {
      await context
          .read<DutyController>()
          .clearAssignment(widget.sessionId);
      if (!mounted) return;
      _rosterLoad = _loadRosterCache();
      await _rosterLoad;
      if (!mounted) return;
      setState(() => _assigning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Duty slot cleared")),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _assigning = false;
        _error = dutyActionErrorMessage(e);
      });
    }
  }

  Widget _memberSearchField({
    required bool enabled,
    required Future<Iterable<DeskMember>> Function(String) suggestions,
    required void Function(DeskMember) onSelected,
  }) {
    return Autocomplete<DeskMember>(
      displayStringForOption: (member) => member.displayLabel,
      optionsBuilder: (value) => suggestions(value.text),
      onSelected: onSelected,
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          autofocus: true,
          style: fieldTextStyle(context),
          cursorColor: fieldCursorColor(context),
          textCapitalization: TextCapitalization.words,
          decoration: searchInputDecoration(
            context,
            hintText: "Search member name or email",
          ),
          onSubmitted: (_) => onFieldSubmitted(),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final theme = Theme.of(context);
        final items = options.toList();

        if (_loadingRoster && items.isEmpty) {
          return _SuggestionPanel(
            child: const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          );
        }

        if (items.isEmpty) {
          return const SizedBox.shrink();
        }

        return _SuggestionPanel(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            itemCount: items.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
            itemBuilder: (context, index) {
              final member = items[index];
              return ListTile(
                title: Text(member.displayLabel),
                dense: true,
                onTap: () => onSelected(member),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DutyController>(
      builder: (context, controller, _) {
        final session = _session(controller);
        if (session == null) {
          return Scaffold(
            appBar: AppBar(title: const Text("Assign volunteer")),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text("Duty slot not found."),
              ),
            ),
          );
        }

        final theme = Theme.of(context);
        final assigned = !session.isOpen;

        return Scaffold(
          backgroundColor: kModalSurface,
          appBar: AppBar(
            title: const Text("Assign volunteer"),
            backgroundColor: kModalSurface,
          ),
          body: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(session.dateLabel, style: context.cardTitle),
                const SizedBox(height: 4),
                Text(session.timeRangeLabel, style: context.listSubtitle),
                if (assigned) ...[
                  const SizedBox(height: 12),
                  Text(
                    "Assigned to ${session.assigneeDisplayName}",
                    style: context.listSecondaryEmphasis,
                  ),
                  const SizedBox(height: 20),
                  BrandChipButton(
                    label: _assigning ? "Clearing…" : "Clear assignment",
                    large: true,
                    variant: BrandChipButtonVariant.outlined,
                    onPressed: _assigning ? null : _clear,
                  ),
                ] else ...[
                  const SizedBox(height: 16),
                  _memberSearchField(
                    enabled: !_assigning,
                    suggestions: _memberSuggestions,
                    onSelected: _assign,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SuggestionPanel extends StatelessWidget {
  const _SuggestionPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width - 40;

    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 6,
        color: Theme.of(context).colorScheme.surface,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: 280, maxWidth: width),
          child: child,
        ),
      ),
    );
  }
}
