import "dart:async";
import "dart:io";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:image_picker/image_picker.dart";
import "package:provider/provider.dart";

import "../../core/api_exception.dart";
import "../../core/app_input_field.dart";
import "../../core/app_text_styles.dart";
import "../../core/brand_chip_button.dart";
import "../../core/combobox_field.dart";
import "../../core/toy_photo_url.dart";
import "catalog_models.dart";
import "catalog_provider.dart";
import "toy_photo_placeholder.dart";

/// Result from the admin add/edit toy bottom sheet.
sealed class ToyFormSheetOutcome {
  const ToyFormSheetOutcome();
}

final class ToyFormSaved extends ToyFormSheetOutcome {
  const ToyFormSaved(this.toy);
  final ToyItem toy;
}

final class ToyFormDeleted extends ToyFormSheetOutcome {
  const ToyFormDeleted({
    required this.toyId,
    required this.toyName,
  });

  final String toyId;
  final String toyName;
}

/// Admin form to edit toy metadata via `PATCH /api/v1/admin/toys/{id}`.
Future<ToyFormSheetOutcome?> showToyEditSheet(
  BuildContext context, {
  required ToyItem toy,
}) {
  return showToyFormSheet(context, toy: toy);
}

/// Admin form to add a toy via `POST /api/v1/admin/toys`.
Future<ToyItem?> showToyCreateSheet(BuildContext context) async {
  final outcome = await showToyFormSheet(context);
  return outcome is ToyFormSaved ? outcome.toy : null;
}

Future<ToyFormSheetOutcome?> showToyFormSheet(
  BuildContext context, {
  ToyItem? toy,
}) async {
  await context.read<CatalogController>().loadFormOptions();
  if (!context.mounted) return null;

  return showModalBottomSheet<ToyFormSheetOutcome>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useRootNavigator: true,
    builder: (sheetContext) {
      final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.92;
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: _ToyFormSheet(toy: toy),
      );
    },
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
  bool _deleting = false;
  bool _renamingCategory = false;
  Timer? _nameDuplicateDebounce;
  String? _nameDuplicateMessage;
  bool _checkingNameDuplicate = false;
  int _nameDuplicateRequestId = 0;

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
    _category.addListener(_onCategoryFieldChanged);
    _name.addListener(_onNameChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(context.read<CatalogController>().loadFormOptions());
    });
  }

  void _onCategoryFieldChanged() {
    if (mounted) setState(() {});
  }

  String _duplicateNameMessage(String name, String toyId) =>
      'A toy named "$name" already exists (ID $toyId).';

  void _onNameChanged() {
    if (!widget.isCreate) return;

    _nameDuplicateDebounce?.cancel();
    final name = _name.text.trim();
    if (name.isEmpty) {
      if (!mounted) return;
      setState(() {
        _nameDuplicateMessage = null;
        _checkingNameDuplicate = false;
      });
      return;
    }

    final local =
        context.read<CatalogController>().toyWithExactName(name);
    if (local != null) {
      if (!mounted) return;
      setState(() {
        _nameDuplicateMessage = _duplicateNameMessage(name, local.toyId);
        _checkingNameDuplicate = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _nameDuplicateMessage = null;
      _checkingNameDuplicate = true;
    });
    _nameDuplicateDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_checkNameDuplicateRemote(name));
    });
  }

  Future<void> _checkNameDuplicateRemote(String name) async {
    final requestId = ++_nameDuplicateRequestId;
    try {
      final existing =
          await context.read<CatalogController>().findToyByExactName(name);
      if (!mounted ||
          requestId != _nameDuplicateRequestId ||
          _name.text.trim() != name) {
        return;
      }
      setState(() {
        _checkingNameDuplicate = false;
        _nameDuplicateMessage = existing == null
            ? null
            : _duplicateNameMessage(name, existing.toyId);
      });
    } catch (_) {
      if (!mounted || requestId != _nameDuplicateRequestId) return;
      setState(() => _checkingNameDuplicate = false);
    }
  }

  Future<void> _renameSelectedCategory() async {
    final selected = context.read<CatalogController>().categoryMatchingLabel(
          _category.text,
        );
    if (selected == null || _renamingCategory) return;

    final renameController = TextEditingController(text: selected.label);
    final newLabel = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Rename category"),
          content: TextField(
            controller: renameController,
            autofocus: true,
            style: fieldTextStyle(context),
            cursorColor: fieldCursorColor(context),
            decoration: labeledInputDecoration(
              context,
              labelText: "Category name",
              helperText: "Updates this category for all toys in the catalog.",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context, renameController.text.trim()),
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
    renameController.dispose();
    if (newLabel == null || newLabel.isEmpty || newLabel == selected.label) {
      return;
    }

    setState(() => _renamingCategory = true);
    final catalog = context.read<CatalogController>();
    try {
      final updated = await catalog.updateCategoryLabel(
        code: selected.code,
        label: newLabel,
      );
      if (!mounted) return;
      _category.text = updated.label;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Category renamed to "${updated.label}".')),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? e.message : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => _renamingCategory = false);
    }
  }

  @override
  void dispose() {
    _nameDuplicateDebounce?.cancel();
    _name.removeListener(_onNameChanged);
    _category.removeListener(_onCategoryFieldChanged);
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

    if (widget.isCreate) {
      if (_nameDuplicateMessage != null) return;
      final existing = await context
          .read<CatalogController>()
          .findToyByExactName(_name.text.trim());
      if (!mounted) return;
      if (existing != null) {
        setState(() {
          _nameDuplicateMessage =
              _duplicateNameMessage(_name.text.trim(), existing.toyId);
        });
        return;
      }
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
      Navigator.pop(context, ToyFormSaved(saved));
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

  Future<void> _confirmDelete() async {
    final toy = widget.toy;
    if (toy == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (_) => _DeleteToyConfirmDialog(toy: toy),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    final catalog = context.read<CatalogController>();
    try {
      await catalog.deleteToy(toy.toyId, notify: false);
      if (!mounted) return;
      Navigator.pop(
        context,
        ToyFormDeleted(toyId: toy.toyId, toyName: toy.name),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? e.message : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final catalog = context.watch<CatalogController>();
    final categoryOptions = mergeComboboxOptions(
      catalog.categories.map((item) => item.label),
      currentValue: _category.text,
    );
    final ageRangeOptions = mergeComboboxOptions(
      catalog.ageRangeOptions,
      currentValue: _ageRange.text,
    );
    final manufacturerOptions = mergeComboboxOptions(
      catalog.manufacturerOptions,
      currentValue: _manufacturer.text,
    );
    final selectedCategory = catalog.categoryMatchingLabel(_category.text);

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
              existingPhotoFile: widget.toy?.photoFile,
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
              decoration: labeledInputDecoration(
                context,
                labelText: "Name",
                errorText: _nameDuplicateMessage,
                helperText: widget.isCreate &&
                        _checkingNameDuplicate &&
                        _nameDuplicateMessage == null
                    ? "Checking name…"
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            ComboboxField(
              controller: _category,
              labelText: "Category",
              options: categoryOptions,
              helperText: selectedCategory == null
                  ? "Pick an existing category or type a new one"
                  : "Tap the pencil to rename this category for all toys",
              trailing: selectedCategory == null
                  ? null
                  : IconButton(
                      tooltip: "Rename category",
                      onPressed:
                          _renamingCategory ? null : _renameSelectedCategory,
                      icon: _renamingCategory
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.edit_outlined, size: 20),
                    ),
            ),
            const SizedBox(height: 12),
            ComboboxField(
              controller: _ageRange,
              labelText: "Age range",
              options: ageRangeOptions,
              helperText: "Pick an existing age range or type a new one",
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
            ComboboxField(
              controller: _manufacturer,
              labelText: "Manufacturer",
              options: manufacturerOptions,
              helperText: "Pick an existing manufacturer or type a new one",
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
              onPressed: (_saving ||
                      _deleting ||
                      _checkingNameDuplicate ||
                      _nameDuplicateMessage != null)
                  ? null
                  : _save,
            ),
            if (!widget.isCreate) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: (_saving || _deleting) ? null : _confirmDelete,
                icon: _deleting
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      )
                    : Icon(
                        Icons.delete_outline,
                        color: Theme.of(context).colorScheme.error,
                      ),
                label: Text(
                  _deleting ? "Deleting…" : "Delete toy",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _DeleteToyConfirmDialog extends StatefulWidget {
  const _DeleteToyConfirmDialog({required this.toy});

  final ToyItem toy;

  @override
  State<_DeleteToyConfirmDialog> createState() =>
      _DeleteToyConfirmDialogState();
}

class _DeleteToyConfirmDialogState extends State<_DeleteToyConfirmDialog> {
  late final TextEditingController _idController;

  @override
  void initState() {
    super.initState();
    _idController = TextEditingController();
  }

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  bool get _matches => _idController.text.trim() == widget.toy.toyId;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final toy = widget.toy;

    return AlertDialog(
      title: const Text("Delete toy?"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'This will permanently remove "${toy.name}" from the catalog.',
            style: context.listSecondary(),
          ),
          const SizedBox(height: 12),
          Text(
            "Type ${toy.toyId} below to confirm.",
            style: context.listSubtitle.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _idController,
            autofocus: true,
            style: fieldTextStyle(context),
            cursorColor: fieldCursorColor(context),
            decoration: labeledInputDecoration(
              context,
              labelText: "Toy ID",
              hintText: toy.toyId,
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: _matches ? (_) => Navigator.pop(context, true) : null,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text("Cancel"),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: colors.error),
          onPressed: _matches ? () => Navigator.pop(context, true) : null,
          child: const Text("Delete permanently"),
        ),
      ],
    );
  }
}

class _ToyPhotoPicker extends StatelessWidget {
  const _ToyPhotoPicker({
    required this.pickedPath,
    required this.onPick,
    this.existingToyId,
    this.existingPhotoFile,
    this.hasExistingPhoto = false,
    this.onClear,
  });

  final String? pickedPath;
  final String? existingToyId;
  final String? existingPhotoFile;
  final bool hasExistingPhoto;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final hasPicked = pickedPath != null && pickedPath!.isNotEmpty;
    final showNetwork = !hasPicked && hasExistingPhoto && existingToyId != null;
    final photoCacheSize =
        (160 * MediaQuery.of(context).devicePixelRatio).round();

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
                          toyPhotoUrl(
                            existingToyId!,
                            photoFile: existingPhotoFile,
                          )!,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.medium,
                          cacheWidth: photoCacheSize,
                          cacheHeight: photoCacheSize,
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
