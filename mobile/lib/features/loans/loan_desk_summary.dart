import "package:flutter/material.dart";

import "../../core/app_text_styles.dart";
import "../../core/toy_pieces.dart";
import "../catalog/toy_photo_placeholder.dart";
import "../catalog/toy_photo_tile.dart";
import "loan_models.dart";

class LoanDeskSummary extends StatelessWidget {
  const LoanDeskSummary({
    super.key,
    required this.loan,
    this.showToyId = false,
    this.showPieces = true,
    this.showMemberAndDue = true,
    this.piecesAfterMember = true,
    /// When false, shows a placeholder instead of loading the photo (e.g. in a dialog).
    this.loadPhoto = true,
    this.photoSize = 56,
  });

  final LoanItem loan;
  final bool showToyId;
  final bool showPieces;
  final bool showMemberAndDue;
  final bool loadPhoto;
  final bool piecesAfterMember;
  final double photoSize;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final subtitleStyle = context.listSubtitle;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        loadPhoto
            ? ToyPhotoTile(
                toyId: loan.toyId,
                photoFile: loan.photoFile,
                size: photoSize,
              )
            : ToyPhotoPlaceholder(size: photoSize),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loan.toyName ?? loan.toyId,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.cardTitle,
              ),
              if (showToyId && loan.toyId.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text("Toy id: ${loan.toyId}", style: subtitleStyle),
              ],
              if (!piecesAfterMember && showPieces) ...[
                const SizedBox(height: 4),
                Text(_checkInPiecesLine(loan), style: subtitleStyle),
              ],
              if (showMemberAndDue) ...[
                const SizedBox(height: 4),
                Text(
                  loan.deskSubtitle,
                  style: subtitleStyle.copyWith(
                    color: loan.isOverdue
                        ? colors.error
                        : subtitleStyle.color,
                  ),
                ),
              ],
              if (piecesAfterMember &&
                  showPieces &&
                  loan.piecesSummary.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(loan.piecesSummary, style: subtitleStyle),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

String _checkInPiecesLine(LoanItem loan) {
  if (!hasToyPiecesInfo(
    totalPieces: loan.toyTotalPieces,
    missingPieces: loan.toyMissingPieces,
  )) {
    return "Pieces: not recorded";
  }
  final summary = loan.piecesSummary;
  if (summary.isEmpty) {
    return "Pieces: not recorded";
  }
  return "Pieces: $summary";
}
