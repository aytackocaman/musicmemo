import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../services/audio_service.dart';
import '../../services/daily_challenge_service.dart';
import '../../services/database_service.dart';
import 'daily_challenge_game_screen.dart';

/// Preload screen for the daily challenge.
/// Uses deterministic sound selection and card layout from [DailyChallengeService].
class DailyChallengePreloadScreen extends ConsumerStatefulWidget {
  final String categoryId;
  final String gridSize;
  final int seed;
  final String date;

  const DailyChallengePreloadScreen({
    super.key,
    required this.categoryId,
    required this.gridSize,
    required this.seed,
    required this.date,
  });

  @override
  ConsumerState<DailyChallengePreloadScreen> createState() =>
      _DailyChallengePreloadScreenState();
}

class _DailyChallengePreloadScreenState
    extends ConsumerState<DailyChallengePreloadScreen> {
  double _progress = 0;
  String? _statusText;
  bool _hasError = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _preload();
    }
  }

  Future<void> _preload() async {
    try {
      final l10n = AppLocalizations.of(context)!;
      setState(() => _statusText = l10n.fetchingSoundList);

      // Fetch sounds for the challenge category
      List<SoundModel> sounds;
      if (widget.categoryId.startsWith('tag:')) {
        final parts = widget.categoryId.split(':');
        final tagType = parts[1];
        final tagValue = parts.sublist(2).join(':');
        sounds = await DatabaseService.getSoundsByTag(tagType, tagValue);
      } else {
        sounds = await DatabaseService.getSoundsForCategory(widget.categoryId);
      }

      if (!mounted) return;

      // Fallback to jazz if category has too few sounds
      final pairsNeeded = DailyChallengeService.pairsForGridSize(widget.gridSize);
      if (sounds.length < pairsNeeded && widget.categoryId != 'jazz') {
        sounds = await DatabaseService.getSoundsForCategory('jazz');
        if (!mounted) return;
      }

      if (sounds.isEmpty) {
        _navigateToGame(soundIds: null, soundPaths: {}, soundDurations: {});
        return;
      }

      // Deterministically pick sounds using the daily seed
      final allIds = sounds.map((s) => s.id).toList();
      print('[DailyChallenge] seed=${widget.seed} date=${widget.date} category=${widget.categoryId}');
      print('[DailyChallenge] totalSounds=${allIds.length} pairsNeeded=$pairsNeeded');
      print('[DailyChallenge] first3sorted=${(List<String>.from(allIds)..sort()).take(3).toList()}');
      final pickedIds = DailyChallengeService.pickSoundIds(
        allIds,
        widget.seed,
        pairsNeeded,
      );
      print('[DailyChallenge] pickedIds=$pickedIds');

      // Filter sounds to only the picked ones
      final pickedSounds = sounds.where((s) => pickedIds.contains(s.id)).toList();

      // Preload audio files
      final actualCategoryId = pickedSounds.first.categoryId;
      setState(() => _statusText = l10n.pleaseWait);
      final soundPaths = await AudioService.preloadCategory(
        categoryId: actualCategoryId,
        sounds: pickedSounds,
        onProgress: (completed, total) {
          if (!mounted) return;
          setState(() {
            _progress = completed / total;
          });
        },
      );

      if (!mounted) return;

      final soundDurations = {for (final s in pickedSounds) s.id: s.durationMs};

      _navigateToGame(
        soundIds: pickedIds,
        soundPaths: soundPaths,
        soundDurations: soundDurations,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _statusText = AppLocalizations.of(context)!.failedToLoadSounds;
      });
    }
  }

  void _navigateToGame({
    required List<String>? soundIds,
    required Map<String, String> soundPaths,
    required Map<String, int> soundDurations,
  }) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => DailyChallengeGameScreen(
          categoryId: widget.categoryId,
          gridSize: widget.gridSize,
          seed: widget.seed,
          date: widget.date,
          soundIds: soundIds,
          soundPaths: soundPaths,
          soundDurations: soundDurations,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: context.colors.accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.calendar_today,
                    size: 40,
                    color: context.colors.accent,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  l10n.dailyChallenge,
                  style: AppTypography.headline3(context),
                ),
                const SizedBox(height: 8),
                Text(
                  _statusText ?? l10n.fetchingSoundList,
                  style: AppTypography.body(context)
                      .copyWith(color: context.colors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                if (!_hasError) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _progress > 0 ? _progress : null,
                      backgroundColor: context.colors.surface,
                      color: context.colors.accent,
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(_progress * 100).round()}%',
                    style: AppTypography.labelSmall(context),
                  ),
                ],
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
                        backgroundColor: context.colors.accent,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadius.button),
                        ),
                      ),
                      child: Text(l10n.retry, style: AppTypography.button(context)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      l10n.goBack,
                      style: AppTypography.buttonSecondary(context)
                          .copyWith(color: context.colors.textSecondary),
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
