import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "../../core/app_input_field.dart";
import "../../core/app_text_styles.dart";
import "../../core/modal_action_buttons.dart";
import "loan_desk_summary.dart";
import "loan_models.dart";

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
  late final TextEditingController _missingController;
  String? _validationError;

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
