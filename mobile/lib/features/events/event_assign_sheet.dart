import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../loans/desk_member.dart";
import "../../core/app_input_field.dart";
import "../../core/app_text_styles.dart";
import "../../core/app_theme.dart";
import "../../core/search_field.dart";
import "../../core/toy_loading_indicator.dart";
import "event_models.dart";
import "events_controller.dart";

Future<void> showEventAssignSheet(
  BuildContext context, {
  required EventSlotItem slot,
  required LibraryEventItem event,
}) async {
  if (!context.mounted) return;
  await Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => EventAssignScreen(slot: slot, event: event),
    ),
  );
}

/// Admin UI to book a volunteer or member onto an event slot.
class EventAssignScreen extends StatefulWidget {
  const EventAssignScreen({
    super.key,
    required this.slot,
    required this.event,
  });

  final EventSlotItem slot;
  final LibraryEventItem event;

  @override
  State<EventAssignScreen> createState() => _EventAssignScreenState();
}

class _EventAssignScreenState extends State<EventAssignScreen> {
  List<DeskMember> _rosterCache = [];
  bool _loadingRoster = false;
  bool _booking = false;
  String? _error;
  Future<List<DeskMember>>? _rosterLoad;

  String get _audience => widget.slot.audience;

  String get _audienceLabel =>
      _audience == "volunteer" ? "volunteer" : "member";

  String get _title =>
      _audience == "volunteer" ? "Book volunteer" : "Book member";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rosterLoad = _loadRosterCache();
    });
  }

  Future<List<DeskMember>> _loadRosterCache() async {
    setState(() {
      _loadingRoster = true;
      _error = null;
    });
    try {
      final members = await context
          .read<EventsController>()
          .searchEventAssignees(_audience, "");
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
        _error = eventActionErrorMessage(e);
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
        if (!mounted) return results;
        final remote = await context
            .read<EventsController>()
            .searchEventAssignees(_audience, q);
        results = _mergeResults(results, remote);
      } catch (e) {
        if (mounted && _error == null) {
          setState(() => _error = eventActionErrorMessage(e));
        }
      }
    }
    return results;
  }

  Future<void> _book(DeskMember member) async {
    setState(() {
      _booking = true;
      _error = null;
    });
    try {
      await context.read<EventsController>().adminBookSlot(
            widget.slot.slotId,
            member,
          );
      if (!mounted) return;
      setState(() => _booking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Booked ${member.displayLabel}")),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _booking = false;
        _error = eventActionErrorMessage(e);
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
            hintText: "Search $_audienceLabel name or email",
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
                  child: ToyLibraryLoadingIndicator.compact(),
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
    final theme = Theme.of(context);
    final slot = widget.slot;
    final canBook = !slot.isFull;

    return Scaffold(
      backgroundColor: kModalSurface,
      appBar: AppBar(
        title: Text(_title),
        backgroundColor: kModalSurface,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.event.name, style: context.cardTitle),
            const SizedBox(height: 4),
            Text(
              "${widget.event.dateLabel} · ${slot.timeRangeLabel}",
              style: context.listSubtitle,
            ),
            Text(
              "${slot.audienceLabel} · ${slot.bookedCount}/${slot.capacity} booked",
              style: context.listSubtitle.copyWith(fontSize: 12),
            ),
            if (!canBook) ...[
              const SizedBox(height: 16),
              Text(
                "This slot is fully booked.",
                style: context.emptyState,
              ),
            ] else ...[
              const SizedBox(height: 16),
              _memberSearchField(
                enabled: !_booking,
                suggestions: _memberSuggestions,
                onSelected: _book,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            if (_booking) ...[
              const SizedBox(height: 20),
              const Center(child: ToyLibraryLoadingIndicator.compact()),
            ],
          ],
        ),
      ),
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
