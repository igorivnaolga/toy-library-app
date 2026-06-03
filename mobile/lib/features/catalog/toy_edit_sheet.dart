import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:provider/provider.dart";

import "../../core/api_exception.dart";
import "../../core/app_input_field.dart";
import "../../core/app_text_styles.dart";
import "../../core/brand_chip_button.dart";
import "catalog_models.dart";
import "catalog_provider.dart";

/// Admin form to edit toy metadata via `PATCH /api/v1/admin/toys/{id}`.
Future<ToyItem?> showToyEditSheet(
  BuildContext context, {
  required ToyItem toy,
}) async {
  return showModalBottomSheet<ToyItem>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _ToyEditSheet(toy: toy),
  );
}

class _ToyEditSheet extends StatefulWidget {
  const _ToyEditSheet({required this.toy});

  final ToyItem toy;

  @override
  State<_ToyEditSheet> createState() => _ToyEditSheetState();
}

class _ToyEditSheetState extends State<_ToyEditSheet> {
  late final TextEditingController _name;
  late final TextEditingController _category;
  late final TextEditingController _ageRange;
  late final TextEditingController _status;
  late final TextEditingController _manufacturer;
  late final TextEditingController _description;
  late final TextEditingController _totalPieces;
  late final TextEditingController _missingPieces;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final t = widget.toy;
    _name = TextEditingController(text: t.name);
    _category = TextEditingController(text: t.category ?? "");
    _ageRange = TextEditingController(text: t.ageRange ?? "");
    _status = TextEditingController(text: t.status ?? "");
    _manufacturer = TextEditingController(text: t.manufacturer ?? "");
    _description = TextEditingController(text: t.description ?? "");
    _totalPieces = TextEditingController(
      text: t.totalPieces?.toString() ?? "",
    );
    _missingPieces = TextEditingController(
      text: t.missingPieces?.toString() ?? "",
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _ageRange.dispose();
    _status.dispose();
    _manufacturer.dispose();
    _description.dispose();
    _totalPieces.dispose();
    _missingPieces.dispose();
    super.dispose();
  }

  int? _parseOptionalCount(TextEditingController controller, String label) {
    final raw = controller.text.trim();
    if (raw.isEmpty) return null;
    final parsed = int.tryParse(raw);
    if (parsed == null || parsed < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$label must be a whole number.")),
      );
      return -1;
    }
    return parsed;
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Name is required.")),
      );
      return;
    }

    final totalPieces = _parseOptionalCount(_totalPieces, "Total pieces");
    if (totalPieces == -1) return;
    final missingPieces =
        _parseOptionalCount(_missingPieces, "Missing pieces");
    if (missingPieces == -1) return;
    if (totalPieces != null &&
        missingPieces != null &&
        missingPieces > totalPieces) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Missing pieces cannot exceed total pieces."),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    final catalog = context.read<CatalogController>();
    try {
      final updated = await catalog.updateToy(
        widget.toy.toyId,
        name: _name.text.trim(),
        category: _category.text.trim(),
        ageRange: _ageRange.text.trim(),
        status: _status.text.trim(),
        manufacturer: _manufacturer.text.trim(),
        description: _description.text.trim(),
        totalPieces: totalPieces,
        missingPieces: missingPieces,
      );
      if (!mounted) return;
      Navigator.pop(context, updated);
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? e.message : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Edit toy",
              style: context.screenTitle,
            ),
            const SizedBox(height: 4),
            Text(
              widget.toy.toyId,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              style: fieldTextStyle(context),
              cursorColor: fieldCursorColor(context),
              decoration: labeledInputDecoration(context, labelText: "Name"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _category,
              style: fieldTextStyle(context),
              cursorColor: fieldCursorColor(context),
              decoration:
                  labeledInputDecoration(context, labelText: "Category"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ageRange,
              style: fieldTextStyle(context),
              cursorColor: fieldCursorColor(context),
              decoration:
                  labeledInputDecoration(context, labelText: "Age range"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _status,
              style: fieldTextStyle(context),
              cursorColor: fieldCursorColor(context),
              decoration: labeledInputDecoration(
                context,
                labelText: "Status",
                helperText: 'e.g. "In library", "On loan", "Reserved"',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _manufacturer,
              style: fieldTextStyle(context),
              cursorColor: fieldCursorColor(context),
              decoration: labeledInputDecoration(
                context,
                labelText: "Manufacturer",
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              style: fieldTextStyle(context),
              cursorColor: fieldCursorColor(context),
              decoration: labeledInputDecoration(
                context,
                labelText: "Description",
              ),
              minLines: 3,
              maxLines: 6,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _totalPieces,
              style: fieldTextStyle(context),
              cursorColor: fieldCursorColor(context),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: labeledInputDecoration(
                context,
                labelText: "Total pieces",
                helperText: "Leave blank if unknown",
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _missingPieces,
              style: fieldTextStyle(context),
              cursorColor: fieldCursorColor(context),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: labeledInputDecoration(
                context,
                labelText: "Missing pieces",
                helperText: "Leave blank if none or unknown",
              ),
            ),
            const SizedBox(height: 20),
            BrandChipButton(
              label: _saving ? "Saving…" : "Save changes",
              large: true,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
