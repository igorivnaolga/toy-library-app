import "package:flutter/material.dart";

import "package:flutter/services.dart";



import "../../core/app_text_styles.dart";

import "../../core/modal_action_buttons.dart";
import "../catalog/toy_photo_tile.dart";

import "loan_models.dart";



/// Result from the desk check-in confirmation dialog.

class DeskCheckInResult {

  const DeskCheckInResult({this.missingPieces});



  /// When set, sent to the check-in API to update the toy record.

  final int? missingPieces;

}



/// Confirm toy details before checking a loan back in at the desk.

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

    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    final piecesSummary = loan.piecesSummary;

    final hasTotal = loan.toyTotalPieces != null;



    return AlertDialog(

      title: const Text("Confirm check-in"),

      content: SingleChildScrollView(

        child: Column(

          mainAxisSize: MainAxisSize.min,

          crossAxisAlignment: CrossAxisAlignment.stretch,

          children: [

            Row(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                ToyPhotoTile(toyId: loan.toyId),

                const SizedBox(width: 12),

                Expanded(

                  child: Column(

                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [

                      Text(

                        loan.toyName ?? loan.toyId,

                        style: context.cardTitle,

                      ),

                      const SizedBox(height: 4),

                      Text("Toy id: ${loan.toyId}"),

                      const SizedBox(height: 4),

                      Text("Member: ${loan.memberLabel}"),

                      const SizedBox(height: 4),

                      Text("Due ${formatDisplayDate(loan.dueDate)}"),

                      if (piecesSummary.isNotEmpty) ...[

                        const SizedBox(height: 4),

                        Text(

                          piecesSummary,

                          style: context.listSubtitle.copyWith(

                            fontWeight: FontWeight.w600,

                          ),

                        ),

                      ],

                    ],

                  ),

                ),

              ],

            ),

            const SizedBox(height: 16),

            TextField(

              controller: _missingController,

              keyboardType: TextInputType.number,

              inputFormatters: [FilteringTextInputFormatter.digitsOnly],

              decoration: InputDecoration(

                labelText: "Missing pieces",

                helperText: hasTotal

                    ? "Set of ${loan.toyTotalPieces} pieces — update if anything is missing."

                    : "Update the missing piece count after inspection.",

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

              style: theme.textTheme.bodySmall?.copyWith(

                color: colors.onSurfaceVariant,

              ),

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


