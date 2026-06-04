import "dart:io";

import "package:flutter/foundation.dart";
import "package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart";

class ToyIdScanResult {
  const ToyIdScanResult({
    required this.candidates,
    required this.rawText,
  });

  final List<String> candidates;
  final String rawText;

  bool get hasCandidates => candidates.isNotEmpty;
}

/// On-device text recognition is only available on Android and iOS.
bool get toyIdOcrSupported {
  if (kIsWeb) return false;
  return Platform.isAndroid || Platform.isIOS;
}

/// Runs ML Kit OCR on [imagePath] and returns ranked toy id candidates.
Future<ToyIdScanResult> recognizeToyId(String imagePath) async {
  final input = InputImage.fromFile(File(imagePath));
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final recognized = await recognizer.processImage(input);
    return ToyIdScanResult(
      candidates: _extractIdCandidates(recognized.text),
      rawText: recognized.text,
    );
  } finally {
    await recognizer.close();
  }
}

final RegExp _labelled = RegExp(r"id[:\s#.\-]*([0-9]{1,6})", caseSensitive: false);
final RegExp _bareNumber = RegExp(r"[0-9]{1,6}");

/// Pull likely toy ids from OCR text: labels like "ID 1029" rank first,
/// then any standalone numbers. Order preserved, duplicates removed.
List<String> _extractIdCandidates(String text) {
  final ranked = <String>[];

  void add(String value) {
    final trimmed = value.replaceFirst(RegExp(r"^0+(?=\d)"), "");
    if (trimmed.isEmpty) return;
    if (!ranked.contains(trimmed)) ranked.add(trimmed);
  }

  for (final match in _labelled.allMatches(text)) {
    final group = match.group(1);
    if (group != null) add(group);
  }
  for (final match in _bareNumber.allMatches(text)) {
    add(match.group(0)!);
  }

  return ranked.take(6).toList();
}
