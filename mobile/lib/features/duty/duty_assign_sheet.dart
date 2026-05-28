import "dart:async";

import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../loans/desk_member.dart";
import "duty_controller.dart";
import "duty_session_models.dart";

Future<void> showDutyAssignSheet(
  BuildContext context,
  String sessionId,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _DutyAssignSheet(sessionId: sessionId),
  );
}

class _DutyAssignSheet extends StatefulWidget {
  const _DutyAssignSheet({required this.sessionId});

  final String sessionId;

  @override
  State<_DutyAssignSheet> createState() => _DutyAssignSheetState();
}

class _DutyAssignSheetState extends State<_DutyAssignSheet> {
  final _query = TextEditingController();
  Timer? _debounce;
  List<DeskMember> _members = [];
  bool _loading = false;
  bool _assigning = false;
  String? _error;

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
      final session = _session(context.read<DutyController>());
      if (session != null && session.isOpen) {
        _loadMembers();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final members = await context
          .read<DutyController>()
          .searchRosterMembers(_query.text);
      if (!mounted) return;
      setState(() {
        _members = members;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _scheduleSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _loadMembers);
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
      _query.clear();
      await _loadMembers();
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

  @override
  Widget build(BuildContext context) {
    return Consumer<DutyController>(
      builder: (context, controller, _) {
        final session = _session(controller);
        if (session == null) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Text("Duty slot not found."),
          );
        }

        final theme = Theme.of(context);
        final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
        final assigned = !session.isOpen;

        return Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                session.dateLabel,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(session.timeRangeLabel),
              if (assigned) ...[
                const SizedBox(height: 8),
                Text(
                  "Assigned to ${session.assigneeDisplayName}",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _assigning ? null : _clear,
                  child: const Text("Clear assignment"),
                ),
              ] else ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _query,
                  enabled: !_assigning,
                  decoration: const InputDecoration(
                    labelText: "Search member name or email",
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (_) => _scheduleSearch(),
                ),
                const SizedBox(height: 12),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _error!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  SizedBox(
                    height: 280,
                    child: _members.isEmpty
                        ? const Center(child: Text("No members found."))
                        : ListView.separated(
                            itemCount: _members.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final member = _members[index];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(member.displayLabel),
                                trailing: FilledButton(
                                  onPressed: _assigning
                                      ? null
                                      : () => _assign(member),
                                  child: const Text("Add"),
                                ),
                              );
                            },
                          ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}
