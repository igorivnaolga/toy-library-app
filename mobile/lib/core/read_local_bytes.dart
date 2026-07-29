import "read_local_bytes_stub.dart"
    if (dart.library.io) "read_local_bytes_io.dart" as impl;

/// Reads bytes from a local filesystem path (mobile/desktop).
/// On web, prefer [XFile.readAsBytes] instead — blob URLs are not files.
Future<List<int>> readLocalBytes(String path) => impl.readLocalBytes(path);
