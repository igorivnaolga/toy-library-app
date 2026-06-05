import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:image_picker/image_picker.dart";
import "package:provider/provider.dart";

import "../../core/app_input_field.dart";
import "../../core/app_text_styles.dart";
import "../../core/modal_action_buttons.dart";
import "loan_desk_summary.dart";
import "loan_models.dart";
import "loans_controller.dart";

class DeskCheckInResult {
  const DeskCheckInResult({this.missingPieces});

  final int? missingPieces;
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
  String? _validationError;
  String? _estimateMessage;
  bool _estimating = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.loan.toyMissingPieces;
    _missingController = TextEditingController(
      text: initial?.toString() ?? "",
    );
  }

  @override
  void dispose() {
    _missingController.dispose();
    super.dispose();
  }

  Future<void> _estimateFromPhoto() async {
    if (_estimating) return;
    final XFile? shot = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (shot == null || !mounted) return;

    final controller = context.read<LoansController>();
    setState(() {
      _estimating = true;
      _estimateMessage = null;
    });
    try {
      final estimate = await controller.estimatePieces(
        toyId: widget.loan.toyId,
        imagePath: shot.path,
      );
      if (!mounted) return;
      setState(() {
        if (estimate.suggestedMissing != null) {
          _missingController.text = estimate.suggestedMissing.toString();
        }
        _estimateMessage = estimate.message;
        _validationError = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _estimateMessage =
              "Couldn't estimate from the photo. Enter missing pieces manually.";
        });
      }
    } finally {
      if (mounted) setState(() => _estimating = false);
    }
  }

  void _confirm() {
    final loan = widget.loan;
    final raw = _missingController.text.trim();
    int? missingPieces;

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
      if (loan.toyTotalPieces != null && parsed > loan.toyTotalPieces!) {
        setState(() {
          _validationError =
              "Missing pieces cannot exceed ${loan.toyTotalPieces}.";
        });
        return;
      }
      if (parsed == loan.toyMissingPieces) {
        missingPieces = null;
      } else {
        missingPieces = parsed;
      }
    }

    Navigator.pop(context, DeskCheckInResult(missingPieces: missingPieces));
  }

  @override
  Widget build(BuildContext context) {
    final loan = widget.loan;
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
            const SizedBox(height: 16),
            TextField(
              controller: _missingController,
              style: fieldTextStyle(context),
              cursorColor: fieldCursorColor(context),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: labeledInputDecoration(
                context,
                labelText: "Missing pieces",
                helperText: "Update if changed.",
                errorText: _validationError,
              ),
              onChanged: (_) {
                if (_validationError != null) {
                  setState(() => _validationError = null);
                }
              },
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _estimating ? null : _estimateFromPhoto,
                icon: _estimating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.camera_alt_outlined, size: 18),
                label: Text(_estimating ? "Checking…" : "Estimate from photo"),
              ),
            ),
            if (_estimateMessage != null) ...[
              const SizedBox(height: 6),
              Text(_estimateMessage!, style: fieldHelperStyle(context)),
            ],
            const SizedBox(height: 12),
            Text(
              "Confirm the toy matches what is being returned, then check it in.",
              style: fieldHelperStyle(context),
            ),
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
