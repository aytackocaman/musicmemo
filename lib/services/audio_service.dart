import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'database_service.dart';

// Conditional imports: dart:io is only available on native platforms.
// On web, _cacheDir stays null and we fall back to URL-based playback.
import 'audio_service_native.dart' if (dart.library.html) 'audio_service_web.dart'
    as platform;

/// Service for downloading, caching, and playing sound files.
///
/// On native (iOS/Android): downloads from Supabase Storage, caches locally,
/// plays from local files.
/// On web: plays directly from Supabase Storage public URLs (no caching).
class AudioService {
  static const int maxCacheSizeBytes = 200 * 1024 * 1024; // 200 MB

  static AudioPlayer? _player;
  static String? _cacheDir;

  /// Initialize the audio service — call once at app start.
  static Future<void> init() async {
    _player = AudioPlayer();
    _cacheDir = await platform.initCacheDir();
  }

  /// Download a single sound and cache it locally (native) or return its URL (web).
  static Future<String?> downloadSound(SoundModel sound) async {
    final url = DatabaseService.getSoundFileUrl(sound.filePath);

    if (_cacheDir == null) {
      // Web or cache init failed — use URL directly
      return url;
    }

    final filename = sound.filePath.split('/').last;
    final localPath = '$_cacheDir/${sound.categoryId}/$filename';

    if (platform.fileExists(localPath)) return localPath;

    try {
      await platform.createDirectory('$_cacheDir/${sound.categoryId}');
      final bytes = await platform.httpGetBytes(url);
      if (bytes != null) {
        await platform.writeFile(localPath, bytes);
        return localPath;
      }
      return url; // Fallback to streaming
    } catch (e) {
      debugPrint('Error downloading sound ${sound.name}: $e');
      return url; // Fallback to streaming
    }
  }

  /// Download all sounds for a category.
  /// Returns a map of soundId → path/URL for playback.
  static Future<Map<String, String>> preloadCategory({
    required String categoryId,
    required List<SoundModel> sounds,
    void Function(int completed, int total)? onProgress,
  }) async {
    final result = <String, String>{};
    var completed = 0;

    final futures = <Future<void>>[];
    for (final sound in sounds) {
      futures.add(() async {
        final path = await downloadSound(sound);
        if (path != null) {
          result[sound.id] = path;
        }
        completed++;
        onProgress?.call(completed, sounds.length);
      }());

      // Batch 4 at a time
      if (futures.length >= 4) {
        await Future.wait(futures);
        futures.clear();
      }
    }
    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }

    return result;
  }

  /// Play a sound from a local file path or URL.
  static Future<void> play(String pathOrUrl) async {
    _player ??= AudioPlayer();

    try {
      await _player!.stop();
      if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
        await _player!.play(UrlSource(pathOrUrl));
      } else {
        await _player!.play(DeviceFileSource(pathOrUrl));
      }
    } catch (e) {
      debugPrint('Error playing sound: $e');
    }
  }

  /// Stop any currently playing sound.
  static Future<void> stop() async {
    try {
      await _player?.stop();
    } catch (e) {
      debugPrint('Error stopping sound: $e');
    }
  }

  /// Dispose the audio player.
  static Future<void> dispose() async {
    await _player?.dispose();
    _player = null;
  }
}
