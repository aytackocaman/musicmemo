import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Initialize the local cache directory (native only).
Future<String?> initCacheDir() async {
  try {
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = '${appDir.path}/sound_cache';
    await Directory(cacheDir).create(recursive: true);
    return cacheDir;
  } catch (e) {
    return null;
  }
}

/// Check if a file exists at [path].
bool fileExists(String path) => File(path).existsSync();

/// Create a directory recursively.
Future<void> createDirectory(String path) async {
  await Directory(path).create(recursive: true);
}

/// Download bytes from [url] using dart:io HttpClient.
Future<List<int>?> httpGetBytes(String url) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();
    if (response.statusCode == 200) {
      final bytes = <int>[];
      await for (final chunk in response) {
        bytes.addAll(chunk);
      }
      return bytes;
    }
    return null;
  } finally {
    client.close();
  }
}

/// Write [bytes] to a file at [path].
Future<void> writeFile(String path, List<int> bytes) async {
  await File(path).writeAsBytes(bytes);
}
