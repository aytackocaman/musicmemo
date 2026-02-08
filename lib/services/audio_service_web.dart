// Web stub — no local file caching on web.
// AudioService falls back to URL-based playback when cacheDir is null.

Future<String?> initCacheDir() async => null;

bool fileExists(String path) => false;

Future<void> createDirectory(String path) async {}

Future<List<int>?> httpGetBytes(String url) async => null;

Future<void> writeFile(String path, List<int> bytes) async {}
