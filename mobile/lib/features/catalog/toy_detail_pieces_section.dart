import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../core/api_exception.dart";
import "../../core/app_input_field.dart";
import "../../core/app_text_styles.dart";
import "../../core/toy_pieces.dart";
import "catalog_provider.dart";
import "toy_detail_section.dart";

/// Expandable piece list for admin and volunteer toy detail (view + edit).
class ToyDetailPiecesSection extends StatefulWidget {
  const ToyDetailPiecesSection({
    super.key,
    required this.toyId,
    required this.pieceLines,
    this.totalPieces,
    this.missingPieces,
    this.canEdit = false,
    this.onSaved,
  });

  final String toyId;
  final List<ToyPieceLine> pieceLines;
  final int? totalPieces;
  final int? missingPieces;
  final bool canEdit;
  final VoidCallback? onSaved;

  @override
  State<ToyDetailPiecesSection> createState() => _ToyDetailPiecesSectionState();
}

class _ToyDetailPiecesSectionState extends State<ToyDetailPiecesSection> {
  bool _editing = false;
  bool _saving = false;
  late List<ToyPieceLine> _lines;
  final Set<int> _selected = {};
  final ExpansibleController _tileController = ExpansibleController();

  @override
  void initState() {
    super.initState();
    _lines = List<ToyPieceLine>.from(widget.pieceLines);
  }

  @override
  void dispose() {
    _tileController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ToyDetailPiecesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing &&
        (oldWidget.pieceLines != widget.pieceLines ||
            oldWidget.totalPieces != widget.totalPieces ||
            oldWidget.missingPieces != widget.missingPieces)) {
      _lines = List<ToyPieceLine>.from(widget.pieceLines);
    }
  }

  int get _total =>
      widget.totalPieces ??
      _lines.fold<int>(0, (sum, line) => sum + line.quantity);

  int get _missing =>
      widget.missingPieces ??
      _lines.fold<int>(0, (sum, line) => sum + line.missing);

  List<String> get _summaryParts {
    final parts = <String>[];
    if (_lines.isNotEmpty) {
      parts.add("${_lines.length} unique");
    }
    parts.add("$_total total");
    if (_missing > 0) {
      parts.add("$_missing missing");
    }
    return parts;
  }

  bool get _allSelected =>
      _lines.isNotEmpty && _selected.length == _lines.length;

  void _startEditing() {
    _tileController.expand();
    setState(() {
      _editing = true;
      _selected.clear();
      _lines = List<ToyPieceLine>.from(widget.pieceLines);
    });
  }

  void _cancelEditing() {
    setState(() {
      _editing = false;
      _selected.clear();
      _lines = List<ToyPieceLine>.from(widget.pieceLines);
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await context.read<CatalogController>().updateToyPieces(
            widget.toyId,
            pieceLines: _lines,
          );
      if (!mounted) return;
      setState(() {
        _editing = false;
        _selected.clear();
        _saving = false;
      });
      widget.onSaved?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pieces saved")),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  void _toggleSelectAll(bool? value) {
    setState(() {
      if (value == true) {
        _selected
          ..clear()
          ..addAll(List.generate(_lines.length, (index) => index));
      } else {
        _selected.clear();
      }
    });
  }

  void _deleteSelected() {
    if (_selected.isEmpty) return;
    setState(() {
      _lines = [
        for (var i = 0; i < _lines.length; i++)
          if (!_selected.contains(i)) _lines[i],
      ];
      _selected.clear();
    });
  }

  void _deleteAt(int index) {
    setState(() {
      _lines.removeAt(index);
      _selected.remove(index);
      final next = <int>{};
      for (final i in _selected) {
        if (i > index) {
          next.add(i - 1);
        } else if (i < index) {
          next.add(i);
        }
      }
      _selected
        ..clear()
        ..addAll(next);
    });
  }

  void _toggleMissing(int index) {
    final line = _lines[index];
    setState(() {
      _lines[index] = line.copyWith(
        missing: line.isMissing ? 0 : line.quantity,
      );
    });
  }

  Future<void> _editLine(int index) async {
    final updated = await _showPieceEditorDialog(
      context,
      line: _lines[index],
    );
    if (updated == null || !mounted) return;
    setState(() => _lines[index] = updated);
  }

  Future<void> _addLine() async {
    final created = await _showPieceEditorDialog(context);
    if (created == null || !mounted) return;
    setState(() => _lines.add(created));
  }

  @override
  Widget build(BuildContext context) {
    return ToyDetailSectionCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          controller: _tileController,
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          title: Row(
            children: [
              const Expanded(child: ToyDetailSectionTitle(title: "Pieces")),
              if (!_editing && widget.canEdit)
                IconButton(
                  tooltip: "Edit pieces",
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: _startEditing,
                ),
            ],
          ),
          subtitle: Text(
            _lines.isEmpty && !_editing
                ? "No pieces listed"
                : _summaryParts.join(" · "),
            style: context.listSubtitle,
          ),
          children: [
            if (_editing) ...[
              Row(
                children: [
                  Checkbox(
                    value: _allSelected,
                    tristate: true,
                    onChanged: _lines.isEmpty ? null : _toggleSelectAll,
                  ),
                  Expanded(
                    child: Text(
                      "Select all",
                      style: context.listSecondary(),
                    ),
                  ),
                  TextButton(
                    onPressed: _selected.isEmpty ? null : _deleteSelected,
                    child: Text(
                      "Delete selected",
                      style: context.listSecondary().copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
            if (_lines.isEmpty && _editing)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  "Add piece lines below, then save.",
                  style: context.bodyPlaceholder,
                ),
              ),
            for (var i = 0; i < _lines.length; i++)
              _PieceRow(
                line: _lines[i],
                editing: _editing,
                selected: _selected.contains(i),
                onSelected: (value) {
                  setState(() {
                    if (value == true) {
                      _selected.add(i);
                    } else {
                      _selected.remove(i);
                    }
                  });
                },
                onTap: _editing ? () => _editLine(i) : null,
                onToggleMissing:
                    _editing ? () => _toggleMissing(i) : null,
                onDelete: _editing ? () => _deleteAt(i) : null,
              ),
            if (_editing) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _saving ? null : _addLine,
                icon: const Icon(Icons.add, size: 18),
                label: const Text("Add piece"),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : _cancelEditing,
                      child: const Text("Cancel"),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text("Save"),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PieceRow extends StatelessWidget {
  const _PieceRow({
    required this.line,
    required this.editing,
    required this.selected,
    required this.onSelected,
    this.onTap,
    this.onToggleMissing,
    this.onDelete,
  });

  final ToyPieceLine line;
  final bool editing;
  final bool selected;
  final ValueChanged<bool?> onSelected;
  final VoidCallback? onTap;
  final VoidCallback? onToggleMissing;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final textStyle = context.metaValue.copyWith(height: 1.35);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (editing) ...[
            Checkbox(
              value: selected,
              onChanged: onSelected,
            ),
          ] else
            Text("• ", style: textStyle),
          Expanded(
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        line.displayLabel,
                        style: textStyle,
                      ),
                    ),
                    if (line.isMissing) ...[
                      const SizedBox(width: 8),
                      PieceMissingBadge(label: line.missingBadgeLabel),
                    ],
                    if (editing && onToggleMissing != null) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: line.isMissing
                            ? "Mark present"
                            : "Mark missing",
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        icon: Icon(
                          line.isMissing
                              ? Icons.label_off_outlined
                              : Icons.label_outline,
                          size: 18,
                        ),
                        onPressed: onToggleMissing,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (editing && onDelete != null)
            IconButton(
              tooltip: "Delete piece",
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: const Icon(Icons.delete_outline, size: 18),
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}

/// Compact badge for a missing piece line.
class PieceMissingBadge extends StatelessWidget {
  const PieceMissingBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      labelStyle: context.listSubtitle.copyWith(
        color: const Color(0xFFB71C1C),
        fontWeight: FontWeight.w700,
      ),
      backgroundColor: const Color(0xFFFFCDD2),
      side: BorderSide.none,
      padding: EdgeInsets.zero,
    );
  }
}

Future<ToyPieceLine?> _showPieceEditorDialog(
  BuildContext context, {
  ToyPieceLine? line,
}) {
  final nameController = TextEditingController(text: line?.name ?? "");
  var quantity = line?.quantity ?? 1;
  var missing = line?.missing ?? 0;
  final isNew = line == null;

  return showDialog<ToyPieceLine>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          void clampMissing() {
            if (missing > quantity) {
              missing = quantity;
            }
          }

          return AlertDialog(
            title: Text(
              isNew ? "Add piece" : "Edit piece",
              style: context.screenTitle,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameController,
                  style: fieldTextStyle(context),
                  cursorColor: fieldCursorColor(context),
                  textCapitalization: TextCapitalization.characters,
                  decoration: labeledInputDecoration(
                    context,
                    labelText: "Piece name",
                    hintText: "e.g. H, L, wheel",
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                _StepperRow(
                  label: "Quantity",
                  value: quantity,
                  min: 1,
                  onChanged: (value) {
                    setDialogState(() {
                      quantity = value;
                      clampMissing();
                    });
                  },
                ),
                const SizedBox(height: 8),
                _StepperRow(
                  label: "Missing",
                  value: missing,
                  min: 0,
                  max: quantity,
                  onChanged: (value) {
                    setDialogState(() => missing = value);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text("Cancel"),
              ),
              FilledButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Enter a piece name")),
                    );
                    return;
                  }
                  Navigator.pop(
                    dialogContext,
                    ToyPieceLine(
                      name: name,
                      quantity: quantity,
                      missing: missing,
                    ),
                  );
                },
                child: Text(isNew ? "Add" : "Done"),
              ),
            ],
          );
        },
      );
    },
  );
}

class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max,
  });

  final String label;
  final int value;
  final int min;
  final int? max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final atMin = value <= min;
    final atMax = max != null && value >= max!;

    return Row(
      children: [
        Expanded(
          child: Text(label, style: context.listSecondary()),
        ),
        IconButton(
          onPressed: atMin ? null : () => onChanged(value - 1),
          icon: const Icon(Icons.remove_circle_outline),
        ),
        Text("$value", style: context.metaValue),
        IconButton(
          onPressed: atMax ? null : () => onChanged(value + 1),
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}
