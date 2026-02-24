import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../providers/game_provider.dart';
import '../../services/audio_service.dart';
import '../../services/database_service.dart';
import '../../utils/game_utils.dart';
import 'single_player_game_screen.dart';
import 'local_player_setup_screen.dart';

/// Screen shown while sounds are being downloaded/cached before a game starts.
/// Fetches sounds for the selected category, preloads them locally, then
/// navigates to the appropriate game screen.
class PreloadScreen extends ConsumerStatefulWidget {
  final String category;
  final String gridSize;

  const PreloadScreen({
    super.key,
    required this.category,
    required this.gridSize,
  });

  @override
  ConsumerState<PreloadScreen> createState() => _PreloadScreenState();
}

class _PreloadScreenState extends ConsumerState<PreloadScreen> {
  double _progress = 0;
  String _statusText = 'Loading sounds...';
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _preload();
  }

  Future<void> _preload() async {
    try {
      // 1. Fetch sound metadata — either by app category or by tag
      setState(() => _statusText = 'Fetching sound list...');

      List<SoundModel> sounds;
      if (widget.category.startsWith('tag:')) {
        // Format: 'tag:{tagType}:{tagValue}' e.g. 'tag:mood:Relaxing'
        final parts = widget.category.split(':');
        final tagType = parts[1];
        final tagValue = parts.sublist(2).join(':'); // handles values with colons
        sounds = await DatabaseService.getSoundsByTag(tagType, tagValue);
      } else {
        sounds = await DatabaseService.getSoundsForCategory(widget.category);
      }

      if (!mounted) return;

      // Fall back to jazz sounds if the selected category has none yet
      if (sounds.isEmpty && widget.category != 'jazz') {
        sounds = await DatabaseService.getSoundsForCategory('jazz');
        if (!mounted) return;
      }

      if (sounds.isEmpty) {
        // No sounds at all — use mock IDs and proceed
        _navigateToGame(soundIds: null, soundPaths: {}, soundDurations: {});
        return;
      }

      // 2. Limit to only the sounds needed for this grid size.
      //    A grid of CxR has C*R/2 pairs → that many unique sounds required.
      final (cols, rows) = GameUtils.parseGridSize(widget.gridSize);
      final pairsNeeded = (cols * rows) ~/ 2;
      if (sounds.length > pairsNeeded) {
        sounds = (sounds..shuffle(Random())).take(pairsNeeded).toList();
      }

      // 3. Download / cache only those sounds.
      // Use the actual category the sounds belong to (may differ if falling back to piano)
      final actualCategoryId = sounds.first.categoryId;
      setState(() => _statusText = 'Downloading sounds...');
      final soundPaths = await AudioService.preloadCategory(
        categoryId: actualCategoryId,
        sounds: sounds,
        onProgress: (completed, total) {
          if (!mounted) return;
          setState(() {
            _progress = completed / total;
            _statusText = 'Downloading sounds ($completed/$total)';
          });
        },
      );

      if (!mounted) return;

      // Map soundId → local file path / duration for quick lookup during gameplay
      final soundIds = sounds.map((s) => s.id).toList();
      final soundDurations = {for (final s in sounds) s.id: s.durationMs};

      _navigateToGame(soundIds: soundIds, soundPaths: soundPaths, soundDurations: soundDurations);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _statusText = 'Failed to load sounds';
      });
    }
  }

  void _navigateToGame({
    required List<String>? soundIds,
    required Map<String, String> soundPaths,
    required Map<String, int> soundDurations,
  }) {
    final gameMode = ref.read(selectedGameModeProvider);

    if (gameMode == GameMode.singlePlayer) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SinglePlayerGameScreen(
            category: widget.category,
            gridSize: widget.gridSize,
            soundIds: soundIds,
            soundPaths: soundPaths,
            soundDurations: soundDurations,
          ),
        ),
      );
    } else if (gameMode == GameMode.localMultiplayer) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LocalPlayerSetupScreen(
            category: widget.category,
            gridSize: widget.gridSize,
            soundIds: soundIds,
            soundPaths: soundPaths,
            soundDurations: soundDurations,
          ),
        ),
      );
    } else {
      // Fallback — shouldn't happen but just navigate through
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Music icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.purple.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.headphones,
                    size: 40,
                    color: AppColors.purple,
                  ),
                ),
                const SizedBox(height: 32),

                Text(
                  'Preparing Game',
                  style: AppTypography.headline3(context),
                ),
                const SizedBox(height: 8),

                Text(
                  _statusText,
                  style: AppTypography.body(context).copyWith(color: context.colors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Progress bar
                if (!_hasError) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _progress > 0 ? _progress : null,
                      backgroundColor: context.colors.surface,
                      color: AppColors.purple,
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(_progress * 100).round()}%',
                    style: AppTypography.labelSmall(context),
                  ),
                ],

                // Error state
                if (_hasError) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _hasError = false;
                          _progress = 0;
                        });
                        _preload();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.purple,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.button),
                        ),
                      ),
                      child: Text('Retry', style: AppTypography.button),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Go Back',
                      style: AppTypography.buttonSecondary(context).copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
