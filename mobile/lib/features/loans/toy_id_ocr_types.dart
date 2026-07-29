class ToyIdScanResult {
  const ToyIdScanResult({
    required this.candidates,
    required this.rawText,
  });

  final List<String> candidates;
  final String rawText;

  bool get hasCandidates => candidates.isNotEmpty;
}
