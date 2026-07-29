import "dart:io";

Future<List<int>> readLocalBytes(String path) async {
  final file = File(path);
  if (!await file.exists()) {
    throw StateError("Photo file not found on device.");
  }
  final bytes = await file.readAsBytes();
  if (bytes.isEmpty) {
    throw StateError("Photo file is empty.");
  }
  return bytes;
}
