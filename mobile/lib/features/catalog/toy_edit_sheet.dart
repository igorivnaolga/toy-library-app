import "dart:io";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:image_picker/image_picker.dart";
import "package:provider/provider.dart";

import "../../core/api_exception.dart";
import "../../core/app_input_field.dart";
import "../../core/app_text_styles.dart";
import "../../core/brand_chip_button.dart";
import "../../core/toy_photo_url.dart";
import "catalog_models.dart";
import "catalog_provider.dart";
import "toy_photo_placeholder.dart";

/// Admin form to edit toy metadata via `PATCH /api/v1/admin/toys/{id}`.
Future<ToyItem?> showToyEditSheet(
  BuildContext context, {
  required ToyItem toy,
}) {
  return showToyFormSheet(context, toy: toy);
}

/// Admin form to add a toy via `POST /api/v1/admin/toys`.
Future<ToyItem?> showToyCreateSheet(BuildContext context) {
  return showToyFormSheet(context);
}

Future<ToyItem?> showToyFormSheet(
  BuildContext context, {
  ToyItem? toy,
}) async {
  return showModalBottomSheet<ToyItem>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _ToyFormSheet(toy: toy),
  );
}

class _ToyFormSheet extends StatefulWidget {
  const _ToyFormSheet({this.toy});

  final ToyItem? toy;

  bool get isCreate => toy == null;

  @override
  State<_ToyFormSheet> createState() => _ToyFormSheetState();
}

class _ToyFormSheetState extends State<_ToyFormSheet> {
  late final TextEditingController _name;
  late final TextEditingController _category;
  late final TextEditingController _ageRange;
  late final TextEditingController _status;
  late final TextEditingController _manufacturer;
  late final TextEditingController _description;
  late final TextEditingController _totalPieces;
  late final TextEditingController _missingPieces;
  late final TextEditingController _hireCharge;
  final ImagePicker _picker = ImagePicker();
  String? _pickedPhotoPath;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final t = widget.toy;
    _name = TextEditingController(text: t?.name ?? "");
    _category = TextEditingController(text: t?.category ?? "");
    _ageRange = TextEditingController(text: t?.ageRange ?? "");
    _status = TextEditingController(text: t?.status ?? "In library");
    _manufacturer = TextEditingController(text: t?.manufacturer ?? "");
    _description = TextEditingController(text: t?.description ?? "");
    _totalPieces = TextEditingController(
      text: t?.totalPieces?.toString() ?? "",
    );
    _missingPieces = TextEditingController(
      text: t?.missingPieces?.toString() ?? "",
    );
    final cents = t?.rentalPriceCents;
    _hireCharge = TextEditingController(
      text: cents == null ? "" : (cents / 100).toStringAsFixed(2),
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
    _hireCharge.dispose();
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

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Text(
                widget.isCreate ? "Add toy photo" : "Change toy photo",
                style: context.screenTitle,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(
                "Choose from gallery",
                style: context.listSecondary(),
              ),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(
                "Take a photo",
                style: context.listSecondary(),
              ),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 88,
    );
    if (picked == null || !mounted) return;
    setState(() => _pickedPhotoPath = picked.path);
  }

  int? _parseHireChargeCents() {
    final raw = _hireCharge.text.trim();
    if (raw.isEmpty) return null;
    final normalized = raw.replaceAll("\$", "").trim();
    final parsed = double.tryParse(normalized);
    if (parsed == null || parsed < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Hire charge must be a dollar amount.")),
      );
      return -1;
    }
    return (parsed * 100).round();
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
    final rentalPriceCents = _parseHireChargeCents();
    if (rentalPriceCents == -1) return;

    setState(() => _saving = true);
    final catalog = context.read<CatalogController>();
    try {
      ToyItem saved;
      if (widget.isCreate) {
        saved = await catalog.createToy(
          name: _name.text.trim(),
          category: _category.text.trim(),
          ageRange: _ageRange.text.trim(),
          status: _status.text.trim(),
          manufacturer: _manufacturer.text.trim(),
          description: _description.text.trim(),
          totalPieces: totalPieces,
          missingPieces: missingPieces,
          rentalPriceCents: rentalPriceCents,
        );
      } else {
        saved = await catalog.updateToy(
          widget.toy!.toyId,
          name: _name.text.trim(),
          category: _category.text.trim(),
          ageRange: _ageRange.text.trim(),
          status: _status.text.trim(),
          manufacturer: _manufacturer.text.trim(),
          description: _description.text.trim(),
          totalPieces: totalPieces,
          missingPieces: missingPieces,
          rentalPriceCents: rentalPriceCents,
        );
      }
      if (_pickedPhotoPath != null) {
        saved = await catalog.uploadToyPhoto(saved.toyId, _pickedPhotoPath!);
      }
      if (!mounted) return;
      Navigator.pop(context, saved);
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
              widget.isCreate ? "Add toy" : "Edit toy",
              style: context.screenTitle,
            ),
            if (!widget.isCreate) ...[
              const SizedBox(height: 4),
              Text(
                widget.toy!.toyId,
                style: context.listSubtitle,
              ),
            ],
            const SizedBox(height: 16),
            _ToyPhotoPicker(
              pickedPath: _pickedPhotoPath,
              existingToyId: widget.toy?.toyId,
              hasExistingPhoto: widget.toy?.photoFile != null &&
                  widget.toy!.photoFile!.isNotEmpty,
              onPick: _pickPhoto,
              onClear: _pickedPhotoPath == null
                  ? null
                  : () => setState(() => _pickedPhotoPath = null),
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
            const SizedBox(height: 12),
            TextField(
              controller: _hireCharge,
              style: fieldTextStyle(context),
              cursorColor: fieldCursorColor(context),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: labeledInputDecoration(
                context,
                labelText: "Hire charge (NZD)",
                helperText: "e.g. 1.00 — shown on shelf labels",
              ),
            ),
            const SizedBox(height: 20),
            BrandChipButton(
              label: _saving
                  ? (widget.isCreate ? "Adding…" : "Saving…")
                  : (widget.isCreate ? "Add toy" : "Save changes"),
              large: true,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _ToyPhotoPicker extends StatelessWidget {
  const _ToyPhotoPicker({
    required this.pickedPath,
    required this.onPick,
    this.existingToyId,
    this.hasExistingPhoto = false,
    this.onClear,
  });

  final String? pickedPath;
  final String? existingToyId;
  final bool hasExistingPhoto;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final hasPicked = pickedPath != null && pickedPath!.isNotEmpty;
    final showNetwork = !hasPicked && hasExistingPhoto && existingToyId != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text("Photo", style: context.formSectionLabel),
        const SizedBox(height: 8),
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 160,
              height: 160,
              child: hasPicked
                  ? Image.file(
                      File(pickedPath!),
                      fit: BoxFit.cover,
                    )
                  : showNetwork
                      ? Image.network(
                          toyPhotoHttpUrl(existingToyId!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const ToyPhotoPlaceholder(
                            expand: true,
                            borderRadius: 12,
                          ),
                        )
                      : const ToyPhotoPlaceholder(
                          expand: true,
                          borderRadius: 12,
                        ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onPick,
                icon: const Icon(Icons.photo_outlined, size: 18),
                label: Text(
                  hasPicked || hasExistingPhoto ? "Change photo" : "Add photo",
                  style: context.listSecondary().copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ),
            if (hasPicked && onClear != null) ...[
              const SizedBox(width: 8),
              IconButton(
                tooltip: "Remove selected photo",
                onPressed: onClear,
                icon: const Icon(Icons.close),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
