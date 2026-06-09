import "dart:typed_data";

import "package:http/http.dart" as http;
import "package:pdf/pdf.dart";
import "package:pdf/widgets.dart" as pw;
import "package:printing/printing.dart";

import "../../core/toy_photo_url.dart";
import "../info/library_info_copy.dart";
import "catalog_models.dart";

const _labelGrey = PdfColor.fromInt(0xFFD9D9D9);
const _labelDarkGrey = PdfColor.fromInt(0xFFBFBFBF);

const _conditionsText =
    "All pieces must be returned on the due date in a clean condition "
    "or a fee will apply in accordance with the Church Corner Toy Library "
    "Inc. Conditions of Membership.";

/// Builds and shares a toy shelf label PDF matching the Trinity Corner template.
Future<void> shareToyLabelPdf(ToyItem toy) async {
  final bytes = await buildToyLabelPdf(toy);
  await Printing.sharePdf(
    bytes: bytes,
    filename: "toy_${toy.toyId}_label.pdf",
  );
}

Future<Uint8List> buildToyLabelPdf(ToyItem toy) async {
  final photo = await _loadToyPhoto(toy);
  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (context) => _labelPage(toy, photo),
    ),
  );
  return doc.save();
}

Future<pw.MemoryImage?> _loadToyPhoto(ToyItem toy) async {
  try {
    final response = await http.get(Uri.parse(toyPhotoHttpUrl(toy.toyId)));
    if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
      return null;
    }
    return pw.MemoryImage(response.bodyBytes);
  } catch (_) {
    return null;
  }
}

pw.Widget _labelPage(ToyItem toy, pw.MemoryImage? photo) {
  final hireCharge = toy.rentalPriceLabel ?? "—";
  final pieces = toy.totalPieces?.toString() ?? "—";
  final displayArea = _dashIfEmpty(toy.category);
  final ageGroup = _dashIfEmpty(toy.ageRange);
  final pieceDescription = toy.description?.trim().isNotEmpty == true
      ? toy.description!.trim()
      : "—";

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          "ToyID ${toy.toyId}",
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
      ),
      pw.SizedBox(height: 8),
      pw.Center(
        child: pw.Column(
          children: [
            pw.Text(
              LibraryInfoCopy.locationAddressLine1,
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.center,
            ),
            pw.Text(
              LibraryInfoCopy.locationAddressLine2,
              style: const pw.TextStyle(fontSize: 9),
              textAlign: pw.TextAlign.center,
            ),
            pw.Text(
              "Christchurch",
              style: const pw.TextStyle(fontSize: 9),
              textAlign: pw.TextAlign.center,
            ),
            pw.Text(
              LibraryInfoCopy.coordinatorPhone,
              style: const pw.TextStyle(fontSize: 9),
              textAlign: pw.TextAlign.center,
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 12),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 220,
            height: 110,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 0.8),
            ),
            child: photo != null
                ? pw.Image(photo, fit: pw.BoxFit.cover)
                : pw.Center(
                    child: pw.Text(
                      "Photo",
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ),
          ),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Table(
              border: pw.TableBorder.all(color: PdfColors.black, width: 0.6),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.1),
                1: const pw.FlexColumnWidth(1.3),
              },
              children: [
                _labelRow("Toy Name", toy.name),
                _labelRow("Display Area", displayArea),
                _labelRow("Recommended Age Group", ageGroup),
                _labelRow("No. of pieces", pieces),
                _labelRow("Hire Charge", hireCharge),
              ],
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 14),
      _sectionHeader("PIECE DESCRIPTION for use in the toy library only"),
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.black, width: 0.6),
        ),
        child: pw.Text(pieceDescription, style: const pw.TextStyle(fontSize: 9)),
      ),
      pw.SizedBox(height: 12),
      _sectionHeader("CONDITIONS OF HIRE"),
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.black, width: 0.6),
        ),
        child: pw.Text(_conditionsText, style: const pw.TextStyle(fontSize: 8.5)),
      ),
    ],
  );
}

pw.TableRow _labelRow(String label, String value) {
  return pw.TableRow(
    children: [
      pw.Container(
        color: _labelGrey,
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: pw.Text(
          label,
          style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
        ),
      ),
      pw.Container(
        color: _labelDarkGrey,
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
      ),
    ],
  );
}

pw.Widget _sectionHeader(String title) {
  return pw.Container(
    width: double.infinity,
    margin: const pw.EdgeInsets.only(bottom: 4),
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    color: _labelGrey,
    child: pw.Text(
      title,
      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
    ),
  );
}

String _dashIfEmpty(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return "—";
  return trimmed;
}
