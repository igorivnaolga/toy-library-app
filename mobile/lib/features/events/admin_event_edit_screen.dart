import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../core/app_input_field.dart";
import "../../core/app_text_styles.dart";
import "../../core/brand_chip_button.dart";
import "../../core/user_friendly_error.dart";
import "../bookings/booking_models.dart";
import "../duty/duty_session_models.dart";
import "event_models.dart";
import "events_controller.dart";

/// Admin form to create or edit a library event with time slots.
class AdminEventEditScreen extends StatefulWidget {
  const AdminEventEditScreen({super.key, this.event});

  final LibraryEventItem? event;

  @override
  State<AdminEventEditScreen> createState() => _AdminEventEditScreenState();
}

class _AdminEventEditScreenState extends State<AdminEventEditScreen> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _published = true;
  bool _saving = false;
  final List<_SlotDraft> _slots = [];

  bool get _isEdit => widget.event != null;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    _name = TextEditingController(text: event?.name ?? "");
    _description = TextEditingController(text: event?.description ?? "");
    _startDate = event?.eventDate;
    _endDate = event?.endDate ?? event?.eventDate;
    _published = event?.isPublished ?? true;
    if (event != null) {
      for (final slot in event.slots) {
        _slots.add(
          _SlotDraft(
            start: _parseTime(slot.startTime),
            end: _parseTime(slot.endTime),
            capacity: slot.capacity,
            audience: slot.audience,
          ),
        );
      }
    } else {
      _slots.add(_SlotDraft());
    }
  }

  TimeOfDay _parseTime(String raw) {
    final parts = raw.split(":");
    final hour = int.tryParse(parts.first) ?? 10;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return TimeOfDay(hour: hour, minute: minute);
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked == null) return;
    setState(() {
      _startDate = picked;
      if (_endDate == null || calendarDay(_endDate!).isBefore(calendarDay(picked))) {
        _endDate = picked;
      }
    });
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked == null) return;
    setState(() => _endDate = picked);
  }

  Map<String, dynamic> _buildPayload() {
    return {
      "name": _name.text.trim(),
      "description": _description.text.trim().isEmpty
          ? null
          : _description.text.trim(),
      "event_date": formatApiDate(_startDate!),
      "end_date": formatApiDate(_endDate!),
      "is_published": _published,
      "slots": [
        for (final slot in _slots)
          {
            "start_time": slot.startApiTime,
            "end_time": slot.endApiTime,
            "capacity": slot.capacity,
            "audience": slot.audience,
          },
      ],
    };
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      _showError("Enter an event name.");
      return;
    }
    if (_startDate == null) {
      _showError("Choose a start date.");
      return;
    }
    if (_endDate == null) {
      _showError("Choose a finish date.");
      return;
    }
    if (calendarDay(_endDate!).isBefore(calendarDay(_startDate!))) {
      _showError("Finish date must be on or after start date.");
      return;
    }
    if (_slots.isEmpty) {
      _showError("Add at least one time slot.");
      return;
    }
    for (final slot in _slots) {
      if (slot.capacity < 1) {
        _showError("Each slot needs capacity of at least 1.");
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final controller = context.read<EventsController>();
      if (_isEdit) {
        await controller.updateEvent(widget.event!.eventId, _buildPayload());
      } else {
        await controller.createEvent(_buildPayload());
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      _showError(
        friendlyErrorMessage(
          e,
          fallback: "Couldn't save this event. Please try again.",
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final metaStyle = context.listSubtitle.copyWith(
      fontSize: 13,
      color: colors.onSurface.withValues(alpha: 0.82),
      fontWeight: FontWeight.w600,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? "Edit event" : "New event"),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          TextField(
            controller: _name,
            decoration: labeledInputDecoration(context, labelText: "Event name"),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            minLines: 2,
            maxLines: 5,
            decoration: labeledInputDecoration(
              context,
              labelText: "Description",
              hintText: "What is this event about?",
            ),
          ),
          const SizedBox(height: 12),
          Text("Event dates", style: context.sectionHeader),
          const SizedBox(height: 4),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text("Start date", style: metaStyle),
            subtitle: Text(
              _startDate == null ? "Not set" : formatSessionDate(_startDate!),
              style: context.cardTitle.copyWith(fontSize: 15),
            ),
            trailing: const Icon(Icons.calendar_month_outlined),
            onTap: _pickStartDate,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text("Finish date", style: metaStyle),
            subtitle: Text(
              _endDate == null ? "Not set" : formatSessionDate(_endDate!),
              style: context.cardTitle.copyWith(fontSize: 15),
            ),
            trailing: const Icon(Icons.event_outlined),
            onTap: _pickEndDate,
          ),
          if (_startDate != null &&
              _endDate != null &&
              calendarDay(_endDate!).isBefore(calendarDay(_startDate!)))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                "Finish date must be on or after start date.",
                style: TextStyle(color: colors.error, fontSize: 12),
              ),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text("Published", style: context.cardTitle.copyWith(fontSize: 15)),
            subtitle: Text(
              "Members and volunteers can see and book slots",
              style: metaStyle,
            ),
            value: _published,
            onChanged: (value) => setState(() => _published = value),
          ),
          const SizedBox(height: 8),
          Text("Time slots", style: context.sectionHeader),
          const SizedBox(height: 8),
          for (var i = 0; i < _slots.length; i++) ...[
            _SlotEditor(
              slot: _slots[i],
              onChanged: () => setState(() {}),
              onRemove: _slots.length > 1
                  ? () => setState(() => _slots.removeAt(i))
                  : null,
            ),
            const SizedBox(height: 8),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _slots.add(_SlotDraft())),
              icon: const Icon(Icons.add),
              label: const Text("Add slot"),
            ),
          ),
          const SizedBox(height: 16),
          BrandChipButton(
            large: true,
            label: _saving ? "Saving…" : (_isEdit ? "Save changes" : "Create event"),
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}

class _SlotDraft {
  _SlotDraft({
    TimeOfDay? start,
    TimeOfDay? end,
    this.capacity = 5,
    this.audience = "volunteer",
  })  : start = start ?? const TimeOfDay(hour: 10, minute: 0),
        end = end ?? const TimeOfDay(hour: 12, minute: 0);

  TimeOfDay start;
  TimeOfDay end;
  int capacity;
  String audience;

  String get startApiTime =>
      "${start.hour.toString().padLeft(2, "0")}:${start.minute.toString().padLeft(2, "0")}:00";

  String get endApiTime =>
      "${end.hour.toString().padLeft(2, "0")}:${end.minute.toString().padLeft(2, "0")}:00";
}

class _SlotEditor extends StatelessWidget {
  const _SlotEditor({
    required this.slot,
    required this.onChanged,
    this.onRemove,
  });

  final _SlotDraft slot;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  Future<void> _pickTime(
    BuildContext context, {
    required bool start,
  }) async {
    final initial = start ? slot.start : slot.end;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked == null) return;
    if (start) {
      slot.start = picked;
    } else {
      slot.end = picked;
    }
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text("Slot", style: context.cardTitle.copyWith(fontSize: 14)),
              ),
              if (onRemove != null)
                IconButton(
                  tooltip: "Remove slot",
                  onPressed: onRemove,
                  icon: const Icon(Icons.close, size: 20),
                ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickTime(context, start: true),
                  child: Text("Start ${slot.start.format(context)}"),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickTime(context, start: false),
                  child: Text("End ${slot.end.format(context)}"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text("Capacity", style: Theme.of(context).textTheme.bodySmall),
              const Spacer(),
              IconButton(
                onPressed: slot.capacity > 1
                    ? () {
                        slot.capacity -= 1;
                        onChanged();
                      }
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text("${slot.capacity}"),
              IconButton(
                onPressed: () {
                  slot.capacity += 1;
                  onChanged();
                },
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          DropdownButtonFormField<String>(
            value: slot.audience,
            decoration: labeledInputDecoration(
              context,
              labelText: "Who can book",
            ),
            items: const [
              DropdownMenuItem(
                value: "volunteer",
                child: Text("Volunteers (help run event)"),
              ),
              DropdownMenuItem(
                value: "member",
                child: Text("Members (attend event)"),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              slot.audience = value;
              onChanged();
            },
          ),
        ],
      ),
    );
  }
}
