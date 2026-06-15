import "dart:async";
import "dart:io";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:image_picker/image_picker.dart";
import "package:provider/provider.dart";

import "../../core/api_exception.dart";
import "../../core/app_input_field.dart";
import "../../core/toy_loading_indicator.dart";
import "../../core/app_text_styles.dart";
import "../../core/modal_action_buttons.dart";
import "../../core/toy_pieces.dart";
import "../catalog/catalog_provider.dart";
import "loan_desk_summary.dart";
import "loan_models.dart";
import "loans_controller.dart";

enum _MissingEntryMode { stepper, typedCount }

/// Desk photo count + learn at check-in. `false` = manual +/− only (CV code kept).
const bool kDeskCheckInCvEnabled = false;

class DeskCheckInPhotoLearn {
  const DeskCheckInPhotoLearn({
    required this.toyId,
    required this.imageBytes,
    required this.confirmedPieceCount,
  });

  final String toyId;
  final List<int> imageBytes;
  final int confirmedPieceCount;
}

class DeskCheckInResult {
  const DeskCheckInResult({
    this.missingPieces,
    this.missingPiecesDetail,
    this.photoLearn,
  });

  final int? missingPieces;
  final String? missingPiecesDetail;
  final DeskCheckInPhotoLearn? photoLearn;
}

/// Run after [LoansController.checkIn] so toy row updates do not race learning.
void runDeskPhotoLearnInBackground(
  LoansController controller,
  ScaffoldMessengerState messenger,
  DeskCheckInPhotoLearn learn,
) {
  controller
      .learnFromPhoto(
        toyId: learn.toyId,
        imageBytes: learn.imageBytes,
        confirmedPieceCount: learn.confirmedPieceCount,
        isCompleteSet: true,
      )
      .then((_) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text("Saved photo baseline for this toy."),
        duration: Duration(seconds: 2),
      ),
    );
  }).catchError((Object error) {
    final hint = error is ApiException
        ? (error.statusCode == 404
            ? "restart the backend server"
            : error.message)
        : error is TimeoutException
            ? "connection too slow"
            : error.toString();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          "Check-in completed. Photo baseline not saved ($hint).",
        ),
        duration: const Duration(seconds: 5),
      ),
    );
  });
}

Future<DeskCheckInResult?> showDeskCheckInDialog(
  BuildContext context,
  LoanItem loan,
) {
  return showDialog<DeskCheckInResult>(
    context: context,
    builder: (context) => _DeskCheckInDialog(loan: loan),
  );
}

class _DeskCheckInDialog extends StatefulWidget {
  const _DeskCheckInDialog({required this.loan});

  final LoanItem loan;

  @override
  State<_DeskCheckInDialog> createState() => _DeskCheckInDialogState();
}

class _DeskCheckInDialogState extends State<_DeskCheckInDialog> {
  final ImagePicker _picker = ImagePicker();
  late final TextEditingController _missingController;
  late final TextEditingController _missingNamesController;
  late int _piecesReturned;
  _MissingEntryMode _entryMode = _MissingEntryMode.stepper;
  List<ToyPieceLine> _pieceLines = const [];
  String? _validationError;
  String? _estimateMessage;
  bool _estimating = false;
  String? _lastPhotoPath;

  @override
  void initState() {
    super.initState();
    final loan = widget.loan;
    final total = loan.toyTotalPieces;
    final missing = loan.toyMissingPieces ?? 0;
    if (total != null) {
      _piecesReturned = (total - missing).clamp(0, total);
    } else {
      _piecesReturned = 0;
    }
    _missingController = TextEditingController(
      text: missing > 0 ? missing.toString() : "",
    );
    _missingNamesController = TextEditingController();
    _loadPieceLines();
  }

  Future<void> _loadPieceLines() async {
    try {
      final toy =
          await context.read<CatalogController>().fetchToy(widget.loan.toyId);
      if (!mounted) return;
      setState(() => _pieceLines = toy.pieceLines);
    } catch (_) {
      // SETLS breakdown is optional at check-in.
    }
  }

  @override
  void dispose() {
    _missingController.dispose();
    _missingNamesController.dispose();
    super.dispose();
  }

  void _setMissingCount(int missing) {
    final total = widget.loan.toyTotalPieces;
    if (total == null) {
      _missingController.text = missing > 0 ? missing.toString() : "";
      return;
    }
    setState(() {
      _piecesReturned = (total - missing).clamp(0, total);
      _missingController.text = missing > 0 ? missing.toString() : "";
      _validationError = null;
    });
  }

  void _appendPieceName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final current = _missingNamesController.text.trim();
    final parts = current.isEmpty
        ? <String>[]
        : current.split(RegExp(r"[,;\n]+")).map((p) => p.trim()).toList();
    if (parts.any((part) => part.toLowerCase() == trimmed.toLowerCase())) {
      return;
    }
    parts.add(trimmed);
    _missingNamesController.text = parts.join(", ");
    _missingNamesController.selection = TextSelection.collapsed(
      offset: _missingNamesController.text.length,
    );
    setState(() {});
  }

  int? get _missingFromStepper {
    final total = widget.loan.toyTotalPieces;
    if (total == null) return null;
    return total - _piecesReturned;
  }

  void _applyEstimate(int? estimatedCount, int? suggestedMissing) {
    final total = widget.loan.toyTotalPieces;
    if (total != null) {
      // Trust backend snap: when photo is close, treat as full set.
      if (suggestedMissing == 0) {
        _piecesReturned = total;
      } else if (estimatedCount != null) {
        _piecesReturned = estimatedCount.clamp(0, total);
      }
    } else if (suggestedMissing != null) {
      _missingController.text = suggestedMissing.toString();
    }
  }

  Future<bool> _confirmPhotoTips() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Photo tips"),
        content: const Text(
          "For a better count:\n"
          "• Take pieces out of the box/tray\n"
          "• Spread them on a plain background\n"
          "• Shoot from directly above\n"
          "• Use even lighting",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Open camera"),
          ),
        ],
      ),
    ).then((value) => value ?? false);
  }

  Future<void> _estimateFromPhoto() async {
    if (_estimating) return;
    if (!mounted) return;

    final proceed = await _confirmPhotoTips();
    if (!proceed || !mounted) return;

    final XFile? shot = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1000,
      imageQuality: 75,
    );
    if (shot == null || !mounted) return;
    // Keep a stable copy — the camera temp file can disappear before upload.
    try {
      final cached = File("${shot.path}.desk_learn.jpg");
      await File(shot.path).copy(cached.path);
      _lastPhotoPath = cached.path;
    } catch (_) {
      _lastPhotoPath = shot.path;
    }

    if (!mounted) return;
    final controller = context.read<LoansController>();
    final photoPath = _lastPhotoPath!;
    setState(() {
      _estimating = true;
      _estimateMessage = null;
    });
    try {
      final estimate = await controller.estimatePieces(
        toyId: widget.loan.toyId,
        imagePath: photoPath,
      );
      if (!mounted) return;
      setState(() {
        _applyEstimate(estimate.estimatedCount, estimate.suggestedMissing);
        _estimateMessage = estimate.message;
        _validationError = null;
      });
    } on ApiException catch (error) {
      if (mounted) {
        final status = error.statusCode;
        final hint = status == 403
            ? "You must be on duty to use photo counting."
            : status == 0
                ? error.message
                : error.message;
        setState(() {
          _estimateMessage =
              "Couldn't analyse the photo ($hint). Adjust the count manually.";
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _estimateMessage =
              "Couldn't analyse the photo ($error). Adjust the count manually.";
        });
      }
    } finally {
      if (mounted) setState(() => _estimating = false);
    }
  }

  Future<void> _confirm() async {
    final loan = widget.loan;
    final total = loan.toyTotalPieces;
    int? missingPieces;

    if (total != null) {
      missingPieces = _missingFromStepper;
      if (missingPieces == (loan.toyMissingPieces ?? 0)) {
        missingPieces = null;
      }
    } else {
      final raw = _missingController.text.trim();
      if (raw.isEmpty) {
        missingPieces = null;
      } else {
        final parsed = int.tryParse(raw);
        if (parsed == null || parsed < 0) {
          setState(() {
            _validationError = "Enter a whole number of missing pieces.";
          });
          return;
        }
        if (parsed == loan.toyMissingPieces) {
          missingPieces = null;
        } else {
          missingPieces = parsed;
        }
      }
    }

    DeskCheckInPhotoLearn? photoLearn;
    if (kDeskCheckInCvEnabled) {
      final photoPath = _lastPhotoPath;
      final missing = _missingFromStepper;
      final shouldLearn = photoPath != null &&
          total != null &&
          missing == 0 &&
          _piecesReturned >= total;

      List<int>? learnBytes;
      if (shouldLearn && File(photoPath).existsSync()) {
        learnBytes = await File(photoPath).readAsBytes();
      }
      if (learnBytes != null && learnBytes.isNotEmpty) {
        photoLearn = DeskCheckInPhotoLearn(
          toyId: loan.toyId,
          imageBytes: learnBytes,
          confirmedPieceCount: _piecesReturned,
        );
      }
    }

    String? missingPiecesDetail;
    final missingNow = total != null
        ? (_missingFromStepper ?? 0)
        : (missingPieces ?? 0);
    if (missingNow > 0) {
      final detail = _missingNamesController.text.trim();
      missingPiecesDetail = detail.isEmpty ? null : detail;
    }

    if (!mounted) return;
    Navigator.pop(
      context,
      DeskCheckInResult(
        missingPieces: missingPieces,
        missingPiecesDetail: missingPiecesDetail,
        photoLearn: photoLearn,
      ),
    );
  }

  Widget _buildEntryModeToggle(BuildContext context) {
    return SegmentedButton<_MissingEntryMode>(
      segments: const [
        ButtonSegment(
          value: _MissingEntryMode.stepper,
          label: Text("Use +/−"),
          icon: Icon(Icons.exposure_outlined, size: 18),
        ),
        ButtonSegment(
          value: _MissingEntryMode.typedCount,
          label: Text("Type count"),
          icon: Icon(Icons.edit_outlined, size: 18),
        ),
      ],
      selected: {_entryMode},
      onSelectionChanged: (selection) {
        setState(() {
          _entryMode = selection.first;
          _validationError = null;
          final missing = _missingFromStepper ??
              int.tryParse(_missingController.text.trim());
          if (missing != null) {
            _missingController.text = missing > 0 ? missing.toString() : "";
          }
        });
      },
    );
  }

  Widget _buildMissingNamesField(BuildContext context, int missing) {
    if (missing <= 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        TextField(
          controller: _missingNamesController,
          style: fieldTextStyle(context),
          cursorColor: fieldCursorColor(context),
          textCapitalization: TextCapitalization.sentences,
          decoration: labeledInputDecoration(
            context,
            labelText: "Which pieces are missing?",
            helperText: "Type piece names (e.g. H, L) or tap below.",
          ),
          minLines: 1,
          maxLines: 3,
        ),
        if (_pieceLines.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text("Tap to add", style: fieldHelperStyle(context)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _pieceLines
                .map(
                  (line) => ActionChip(
                    label: Text(line.name),
                    onPressed: () => _appendPieceName(line.name),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildPiecesStepper(BuildContext context, int total) {
    final missing = _missingFromStepper ?? 0;
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "Pieces returned",
          style: fieldHelperStyle(context).copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton.filledTonal(
              onPressed: _piecesReturned > 0
                  ? () => setState(() => _piecesReturned -= 1)
                  : null,
              icon: const Icon(Icons.remove),
            ),
            Expanded(
              child: Text(
                "$_piecesReturned of $total",
                textAlign: TextAlign.center,
                style: context.screenTitle.copyWith(fontSize: 22),
              ),
            ),
            IconButton.filledTonal(
              onPressed: _piecesReturned < total
                  ? () => setState(() => _piecesReturned += 1)
                  : null,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          missing == 0 ? "All $total pieces returned" : "$missing missing",
          textAlign: TextAlign.center,
          style: fieldHelperStyle(context).copyWith(
            color: missing == 0 ? colors.primary : colors.error,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final loan = widget.loan;
    final total = loan.toyTotalPieces;
    return AlertDialog(
      title: Text("Confirm check-in", style: context.screenTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LoanDeskSummary(
              loan: loan,
              showToyId: true,
              showPieces: true,
              showMemberAndDue: true,
              piecesAfterMember: false,
              loadPhoto: false,
            ),
            if (kDeskCheckInCvEnabled) ...[
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _estimating ? null : _estimateFromPhoto,
                  icon: _estimating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: ToyLibraryLoadingIndicator.compact(),
                        )
                      : const Icon(Icons.camera_alt_outlined, size: 18),
                  label: Text(_estimating ? "Analysing…" : "Count from photo"),
                ),
              ),
              if (_estimateMessage != null) ...[
                const SizedBox(height: 6),
                Text(_estimateMessage!, style: fieldHelperStyle(context)),
              ],
              const SizedBox(height: 12),
            ] else
              const SizedBox(height: 16),
            if (total != null) ...[
              _buildEntryModeToggle(context),
              const SizedBox(height: 12),
              if (_entryMode == _MissingEntryMode.stepper)
                _buildPiecesStepper(context, total)
              else
                TextField(
                  controller: _missingController,
                  style: fieldTextStyle(context),
                  cursorColor: fieldCursorColor(context),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: labeledInputDecoration(
                    context,
                    labelText: "Missing pieces",
                    helperText: "Enter how many pieces are missing.",
                    errorText: _validationError,
                  ),
                  onChanged: (value) {
                    final parsed = int.tryParse(value.trim());
                    if (parsed == null && value.trim().isNotEmpty) {
                      setState(() {
                        _validationError =
                            "Enter a whole number of missing pieces.";
                      });
                      return;
                    }
                    if (parsed != null) {
                      if (parsed > total) {
                        setState(() {
                          _validationError =
                              "Missing pieces cannot exceed $total.";
                        });
                        return;
                      }
                      _setMissingCount(parsed);
                    } else if (value.trim().isEmpty) {
                      _setMissingCount(0);
                    }
                  },
                ),
              _buildMissingNamesField(context, _missingFromStepper ?? 0),
            ] else ...[
              TextField(
                controller: _missingController,
                style: fieldTextStyle(context),
                cursorColor: fieldCursorColor(context),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: labeledInputDecoration(
                  context,
                  labelText: "Missing pieces",
                  helperText: "Enter missing pieces.",
                  errorText: _validationError,
                ),
                onChanged: (_) {
                  setState(() {
                    if (_validationError != null) {
                      _validationError = null;
                    }
                  });
                },
              ),
              _buildMissingNamesField(
                context,
                int.tryParse(_missingController.text.trim()) ?? 0,
              ),
            ],
            if (kDeskCheckInCvEnabled) ...[
              const SizedBox(height: 12),
              Text(
                "Spread pieces on a plain background. Use +/− to correct the count — "
                "the app learns each toy after you check in.",
                style: fieldHelperStyle(context),
              ),
            ],
            const SizedBox(height: 20),
            ModalEqualWidthButtonRow(
              secondaryLabel: "Cancel",
              primaryLabel: "Check in",
              onSecondary: () => Navigator.pop(context),
              onPrimary: _confirm,
            ),
          ],
        ),
      ),
    );
  }
}
