import "toy_id_ocr_service_stub.dart"
    if (dart.library.io) "toy_id_ocr_service_io.dart" as impl;
import "toy_id_ocr_types.dart";

export "toy_id_ocr_types.dart";

/// On-device text recognition is only available on Android and iOS.
bool get toyIdOcrSupported => impl.toyIdOcrSupported;

/// Runs ML Kit OCR on [imagePath] and returns ranked toy id candidates.
Future<ToyIdScanResult> recognizeToyId(String imagePath) =>
    impl.recognizeToyId(imagePath);
