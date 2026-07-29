import "toy_id_ocr_types.dart";

bool get toyIdOcrSupported => false;

Future<ToyIdScanResult> recognizeToyId(String imagePath) async {
  throw UnsupportedError("Toy ID OCR is not available on this platform.");
}
