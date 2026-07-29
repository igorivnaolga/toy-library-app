Future<List<int>> readLocalBytes(String path) async {
  throw UnsupportedError(
    "Reading local file paths is not supported on web. "
    "Use XFile.readAsBytes() instead.",
  );
}
