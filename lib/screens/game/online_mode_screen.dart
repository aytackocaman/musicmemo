import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../config/theme.dart';
import '../../services/database_service.dart';
import '../../services/multiplayer_service.dart';
import '../../services/supabase_service.dart';
import '../../utils/game_utils.dart';
import '../../providers/game_provider.dart';
import '../../providers/user_provider.dart';
import '../../utils/app_dialogs.dart';
import '../grand_category_screen.dart';
import '../home_screen.dart';
import 'online_game_screen.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/responsive.dart';

/// Grid options — difficulty keys are resolved via l10n at render time.
final List<Map<String, dynamic>> _gridOptions = [
  if (kDebugMode) {'id': '2x3', 'label': '2x3', 'pairs': 3, 'difficultyKey': 'test'},
  {'id': '4x5', 'label': '4x5', 'pairs': 10, 'difficultyKey': 'easy'},
  {'id': '5x6', 'label': '5x6', 'pairs': 15, 'difficultyKey': 'medium'},
  {'id': '6x7', 'label': '6x7', 'pairs': 21, 'difficultyKey': 'hard'},
];

/// Turn time options (ms → label).
const List<Map<String, dynamic>> _turnTimeOptions = [
  {'ms': 12000, 'label': '12s'},
  {'ms': 15000, 'label': '15s'},
  {'ms': 18000, 'label': '18s'},
  {'ms': 21000, 'label': '21s'},
];


Widget _buildOptionRow({
  required BuildContext context,
  required List<Map<String, dynamic>> options,
  required int selectedValue,
  required ValueChanged<int> onSelect,
}) {
  return Row(
    children: options.map((opt) {
      final ms = opt['ms'] as int;
      final isSelected = selectedValue == ms;
      return Expanded(
        child: GestureDetector(
          onTap: () => onSelect(ms),
          child: Container(
            margin: EdgeInsets.only(
              right: opt != options.last ? 8 : 0,
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? context.colors.accent : context.colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? context.colors.accent : context.colors.elevated,
              ),
            ),
            child: Center(
              child: Text(
                opt['label'] as String,
                style: AppTypography.bodyLarge(context).copyWith(
                  color: isSelected ? Colors.white : context.colors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      );
    }).toList(),
  );
}

String _resolveDifficulty(AppLocalizations l10n, String key) {
  switch (key) {
    case 'test': return l10n.test;
    case 'easy': return l10n.easy;
    case 'medium': return l10n.medium;
    case 'hard': return l10n.hard;
    default: return key;
  }
}

class OnlineModeScreen extends ConsumerStatefulWidget {
  final String? initialInviteCode;
  const OnlineModeScreen({super.key, this.initialInviteCode});

  @override
  ConsumerState<OnlineModeScreen> createState() => _OnlineModeScreenState();
}

class _OnlineModeScreenState extends ConsumerState<OnlineModeScreen> {
  // Screen states
  bool _isCreateMode = false;
  bool _isJoinMode = false;
  bool _isFindOpponentMode = false;
  bool _isSearchingForOpponent = false;
  bool _isWaitingForOpponent = false;
  bool _isOpponentJoined = false;  // Host: opponent joined, ready to start
  bool _isWaitingForHostToStart = false;  // Joiner: waiting for host
  bool _isLoading = false;
  bool _isStartingGame = false;
  bool _isPublicSession = false; // Track if current session is public

  // Form controllers
  final _nameController = TextEditingController(text: 'Player');
  final _codeController = TextEditingController();
  bool _nameSetFromProfile = false;

  // Selections
  String _selectedCategory = 'piano';
  String _selectedGrid = '4x5';
  int _selectedTurnTimeMs = 15000;

  // Session data
  String? _inviteCode;
  String? _sessionId;
  String? _opponentName;
  OnlineSession? _currentSession;
  String? _errorMessage;
  bool _navigatingToGame = false;  // Track if we're navigating to game

  StreamSubscription<OnlineSession>? _sessionSubscription;
  StreamSubscription<MultiplayerConnectionState>? _connectionSubscription;
  MultiplayerConnectionState _connectionState = MultiplayerConnectionState.connected;

  @override
  void initState() {
    super.initState();
    // Prefer saved display name; fall back to email prefix
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final profileState = ref.read(userProfileNotifierProvider);
      final displayName = profileState.valueOrNull?.displayName;
      if (displayName != null && displayName.isNotEmpty) {
        _nameController.text = displayName.substring(0, displayName.length.clamp(0, 20));
      } else {
        final user = SupabaseService.currentUser;
        if (user?.email != null) {
          final prefix = user!.email!.split('@').first;
          _nameController.text = prefix.substring(0, prefix.length.clamp(0, 20));
        }
      }
    });
    if (widget.initialInviteCode != null) {
      _codeController.text = widget.initialInviteCode!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showJoinOptions());
    }
  }

  void _startConnectionListener() {
    _connectionSubscription?.cancel();
    _connectionSubscription =
        MultiplayerService.connectionStateStream.listen((state) {
      if (!mounted) return;
      setState(() => _connectionState = state);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _sessionSubscription?.cancel();
    _connectionSubscription?.cancel();
    // Only cleanup if NOT navigating to game (user backed out)
    if (!_navigatingToGame) {
      if (_sessionId != null && _isWaitingForOpponent) {
        MultiplayerService.deleteSession(_sessionId!);
      }
      MultiplayerService.unsubscribeFromSession();
    }
    super.dispose();
  }


  void _showJoinOptions() {
    setState(() {
      _isCreateMode = false;
      _isJoinMode = true;
      _errorMessage = null;
    });
  }

  void _goBack() {
    if (_isWaitingForOpponent) {
      _cancelWaiting();
    } else if (_isCreateMode || _isJoinMode || _isFindOpponentMode) {
      setState(() {
        _isCreateMode = false;
        _isJoinMode = false;
        _isFindOpponentMode = false;
        _isSearchingForOpponent = false;
        _errorMessage = null;
      });
    } else {
      _popOrHome();
    }
  }

  /// Pop if there's a route behind, otherwise go to HomeScreen
  void _popOrHome() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  Future<void> _searchForOpponent() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _errorMessage = AppLocalizations.of(context)!.pleaseEnterYourName);
      return;
    }

    setState(() {
      _isSearchingForOpponent = true;
      _errorMessage = null;
    });

    // Look for an existing public session
    final publicSession = await MultiplayerService.findPublicSession();

    if (publicSession != null) {
      // Found one — join it
      final joined = await MultiplayerService.joinSessionById(
        sessionId: publicSession.id,
        playerName: _nameController.text.trim(),
      );

      if (joined != null) {
        // Successfully joined — wait for host to auto-start
        _currentSession = joined;
        _sessionId = joined.id;

        setState(() {
          _isSearchingForOpponent = false;
          _isFindOpponentMode = false;
          _isWaitingForHostToStart = true;
        });

        _sessionSubscription =
            MultiplayerService.subscribeToSession(joined.id).listen(
          (updatedSession) {
            _currentSession = updatedSession;
            if (updatedSession.isPlaying) {
              _navigateToGame(updatedSession);
            }
          },
        );
        _startConnectionListener();
        return;
      }
    }

    // No public session found — show category/grid picker so user can create one
    setState(() {
      _isSearchingForOpponent = false;
    });
  }

  Future<void> _createPublicGame() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _errorMessage = AppLocalizations.of(context)!.pleaseEnterYourName);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final session = await MultiplayerService.createSession(
      category: _selectedCategory,
      gridSize: _selectedGrid,
      playerName: _nameController.text.trim(),
      isPublic: true,
      turnTimeLimitMs: _selectedTurnTimeMs,
    );

    if (session == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = AppLocalizations.of(context)!.failedToCreateGame;
      });
      return;
    }

    setState(() {
      _isLoading = false;
      _isFindOpponentMode = false;
      _isWaitingForOpponent = true;
      _isPublicSession = true;
      _inviteCode = session.inviteCode;
      _sessionId = session.id;
    });

    // Subscribe — auto-start when someone joins
    _sessionSubscription =
        MultiplayerService.subscribeToSession(session.id).listen(
      (updatedSession) {
        _currentSession = updatedSession;

        if (updatedSession.isReady && updatedSession.hasOpponent) {
          // Someone joined our public session — auto-start the game
          _opponentName = updatedSession.player2Name;
          _hostStartGame();
        } else if (updatedSession.isPlaying) {
          _navigateToGame(updatedSession);
        }
      },
    );
    _startConnectionListener();
  }

  Future<void> _createGame() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _errorMessage = AppLocalizations.of(context)!.pleaseEnterYourName);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final session = await MultiplayerService.createSession(
      category: _selectedCategory,
      gridSize: _selectedGrid,
      playerName: _nameController.text.trim(),
      turnTimeLimitMs: _selectedTurnTimeMs,
    );

    if (session == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = AppLocalizations.of(context)!.failedToCreateGame;
      });
      return;
    }

    setState(() {
      _isLoading = false;
      _isWaitingForOpponent = true;
      _inviteCode = session.inviteCode;
      _sessionId = session.id;
    });

    // Subscribe to session updates
    _sessionSubscription =
        MultiplayerService.subscribeToSession(session.id).listen(
      (updatedSession) {
        _currentSession = updatedSession;

        if (updatedSession.isReady && updatedSession.hasOpponent) {
          // Opponent joined - show "Start Game" button to host
          setState(() {
            _isOpponentJoined = true;
            _opponentName = updatedSession.player2Name;
          });
        } else if (updatedSession.isPlaying) {
          // Game started - navigate to game
          _navigateToGame(updatedSession);
        } else if (_isOpponentJoined && updatedSession.isWaiting && !updatedSession.hasOpponent) {
          // Opponent left before game started — go back to waiting
          setState(() {
            _isOpponentJoined = false;
            _opponentName = null;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) showAppSnackBar(context, AppLocalizations.of(context)!.opponentLeftTheGame);
          });
        }
      },
    );
    _startConnectionListener();
  }

  Future<void> _joinGame() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _errorMessage = AppLocalizations.of(context)!.pleaseEnterYourName);
      return;
    }

    final code = _codeController.text.trim();
    if (code.isEmpty || code.length != 6) {
      setState(() => _errorMessage = AppLocalizations.of(context)!.pleaseEnterValidCode);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final session = await MultiplayerService.joinSession(
      inviteCode: code,
      playerName: _nameController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (session == null) {
      setState(() {
        _errorMessage = AppLocalizations.of(context)!.gameNotFoundCheckCode;
      });
      return;
    }

    // Store session and show waiting for host screen
    _currentSession = session;
    _sessionId = session.id;

    FocusScope.of(context).unfocus(); // dismiss keyboard before showing waiting screen
    setState(() {
      _isWaitingForHostToStart = true;
    });

    // Subscribe to session updates to know when host starts the game
    _sessionSubscription =
        MultiplayerService.subscribeToSession(session.id).listen(
      (updatedSession) {
        if (updatedSession.isCancelled) {
          _sessionSubscription?.cancel();
          _connectionSubscription?.cancel();
          MultiplayerService.unsubscribeFromSession();
          setState(() => _isWaitingForHostToStart = false);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) showAppSnackBar(context, AppLocalizations.of(context)!.hostCancelledGame);
          });
          return;
        }
        _currentSession = updatedSession;
        if (updatedSession.isPlaying) {
          // Host started the game - navigate
          _navigateToGame(updatedSession);
        }
      },
    );
    _startConnectionListener();
  }

  void _navigateToGame(OnlineSession session) {
    _navigatingToGame = true;  // Don't cleanup subscription in dispose
    _sessionSubscription?.cancel();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => OnlineGameScreen(
          session: session,
          playerName: _nameController.text.trim(),
        ),
      ),
    );
  }

  void _cancelWaiting() async {
    if (_sessionId != null) {
      if (_isOpponentJoined) {
        // Joiner is present — update status to 'cancelled' so their polling
        // detects it as a status change within 500 ms.
        await MultiplayerService.cancelSession(_sessionId!);
      } else {
        await MultiplayerService.deleteSession(_sessionId!);
      }
    }
    _sessionSubscription?.cancel();
    await MultiplayerService.unsubscribeFromSession();

    setState(() {
      _isWaitingForOpponent = false;
      _isOpponentJoined = false;
      _isPublicSession = false;
      _inviteCode = null;
      _sessionId = null;
      _opponentName = null;
    });
  }

  void _copyInviteCode() {
    if (_inviteCode != null) {
      Clipboard.setData(ClipboardData(text: _inviteCode!));
      showAppSnackBar(context, AppLocalizations.of(context)!.codeCopied);
    }
  }

  Future<void> _shareInviteCode() async {
    if (_inviteCode == null) return;
    final box = context.findRenderObject() as RenderBox?;
    await Share.share(
      'Join my Music Memo game! Enter code $_inviteCode or tap: https://musicmemo.app/join?code=$_inviteCode',
      subject: 'Music Memo - Game Invite',
      sharePositionOrigin: box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : null,
    );
  }

  Future<void> _hostStartGame() async {
    if (_currentSession == null || _sessionId == null) return;

    setState(() => _isStartingGame = true);

    // Fetch real sound IDs from the database (fall back to piano if empty)
    List<SoundModel> sounds;
    if (_selectedCategory.startsWith('tag:')) {
      final parts = _selectedCategory.split(':');
      sounds = await DatabaseService.getSoundsByTag(parts[1], parts.sublist(2).join(':'));
    } else {
      sounds = await DatabaseService.getSoundsForCategory(_selectedCategory);
    }
    if (sounds.isEmpty && _selectedCategory != 'piano') {
      sounds = await DatabaseService.getSoundsForCategory('piano');
    }
    final soundIds = sounds.map((s) => s.id).toList();

    // Generate cards with real sound IDs
    final cards = GameUtils.generateCards(
      gridSize: _selectedGrid,
      category: _selectedCategory,
      soundIds: soundIds.isNotEmpty ? soundIds : null,
    );

    // Start the game
    final success = await MultiplayerService.startGame(
      sessionId: _sessionId!,
      cards: cards,
      hostId: SupabaseService.currentUser?.id ?? '',
    );

    if (!success) {
      setState(() {
        _isStartingGame = false;
        _errorMessage = AppLocalizations.of(context)!.failedToStartGame;
      });
      return;
    }

    // Navigation will happen via the subscription when status changes to 'playing'
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<UserProfile?>>(userProfileNotifierProvider,
        (prev, next) {
      if (!_nameSetFromProfile) {
        final name = next.valueOrNull?.displayName;
        if (name != null && name.isNotEmpty) {
          _nameController.text = name.substring(0, name.length.clamp(0, 20));
          _nameSetFromProfile = true;
        }
      }
    });

    // System back (iOS swipe, Android hardware back) should dismiss the
    // current sub-mode instead of popping the whole screen — same behavior
    // as the in-screen back button. Only let the route pop when we're on
    // the main view with no sub-mode active.
    final inSubMode = _isCreateMode ||
        _isJoinMode ||
        _isFindOpponentMode ||
        _isWaitingForOpponent ||
        _isWaitingForHostToStart ||
        _isOpponentJoined;

    return PopScope(
      canPop: !inSubMode,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _goBack();
      },
      child: Scaffold(
        backgroundColor: context.colors.background,
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SafeArea(
          child: ResponsiveBody(
            child: _isWaitingForHostToStart
                ? _buildWaitingForHostScreen()
                : _isOpponentJoined
                    ? _buildOpponentJoinedScreen()
                    : _isWaitingForOpponent
                        ? _buildWaitingScreen()
                        : _isFindOpponentMode
                            ? _buildFindOpponentScreen()
                            : _isCreateMode
                                ? _buildCreateScreen()
                                : _isJoinMode
                                    ? _buildJoinScreen()
                                    : _buildMainScreen(),
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildMainScreen() {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBackButton(),
          const SizedBox(height: AppSpacing.xl),

          Text(l10n.onlineMultiplayerTitle, style: AppTypography.headline3(context)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.playWithFriendsRealtime,
            style: AppTypography.body(context).copyWith(color: context.colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xxl),

          // Find Opponent option
          _buildOptionCard(
            icon: Icons.person_search,
            iconColor: AppColors.pink,
            title: l10n.findOpponent,
            subtitle: l10n.findOpponentDescription,
            onTap: () {
              ref.read(selectedGameModeProvider.notifier).state =
                  GameMode.onlineMultiplayer;
              ref.read(selectedCategoryProvider.notifier).state = null;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GrandCategoryScreen(
                    onCategoryPicked: (ctx, category) {
                      Navigator.of(ctx).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              _FindOpponentScreen(category: category),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),

          // Create Game option
          _buildOptionCard(
            icon: Icons.add_circle_outline,
            iconColor: context.colors.accent,
            title: l10n.createPrivateGame,
            subtitle: l10n.startNewGameInviteFriend,
            onTap: () {
              ref.read(selectedGameModeProvider.notifier).state =
                  GameMode.onlineMultiplayer;
              ref.read(selectedCategoryProvider.notifier).state = null;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GrandCategoryScreen(
                    onCategoryPicked: (ctx, category) {
                      Navigator.of(ctx).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              _CreatePrivateGameScreen(category: category),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),

          // Join Game option
          _buildOptionCard(
            icon: Icons.login,
            iconColor: AppColors.teal,
            title: l10n.joinPrivateGame,
            subtitle: l10n.enterCodeToJoinFriend,
            onTap: _showJoinOptions,
          ),
        ],
      ),
    );
  }

  Widget _buildFindOpponentScreen() {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBackButton(),
          const SizedBox(height: AppSpacing.xl),

          Text(l10n.findOpponent, style: AppTypography.headline3(context)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _isSearchingForOpponent
                ? l10n.searchingForPlayers
                : l10n.noPlayersFoundCreateGame,
            style: AppTypography.body(context).copyWith(color: context.colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xl),

          if (_isSearchingForOpponent)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    const CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.pink),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.lookingForOpponents,
                      style: AppTypography.body(context)
                          .copyWith(color: context.colors.textSecondary),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            if (_errorMessage != null) _buildErrorMessage(),

            // Name input
            _buildSectionTitle(l10n.yourName),
            const SizedBox(height: 8),
            _buildTextField(_nameController, l10n.enterYourName),
            const SizedBox(height: AppSpacing.xl),

            // Grid selection
            _buildSectionTitle(l10n.gridSizeLabel),
            const SizedBox(height: 8),
            _buildGridSelector(),
            const SizedBox(height: AppSpacing.xl),

            // Turn time
            _buildSectionTitle(l10n.turnTimeLimit),
            const SizedBox(height: 8),
            _buildOptionRow(
              context: context,
              options: _turnTimeOptions,
              selectedValue: _selectedTurnTimeMs,
              onSelect: (v) => setState(() => _selectedTurnTimeMs = v),
            ),
            const SizedBox(height: AppSpacing.xxl),

            // Create public game button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _createPublicGame,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.pink,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.button),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(l10n.createAndWaitForOpponent,
                        style: AppTypography.button(context)),
              ),
            ),
            const SizedBox(height: 12),

            // Retry search button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton(
                onPressed: _searchForOpponent,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: context.colors.elevated),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.button),
                  ),
                ),
                child:
                    Text(l10n.searchAgain, style: AppTypography.buttonSecondary(context)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCreateScreen() {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBackButton(),
          const SizedBox(height: AppSpacing.xl),

          Text(l10n.createGame, style: AppTypography.headline3(context)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.setupGameInviteFriend,
            style: AppTypography.body(context).copyWith(color: context.colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xl),

          if (_errorMessage != null) _buildErrorMessage(),

          // Name input
          _buildSectionTitle(l10n.yourName),
          const SizedBox(height: 8),
          _buildTextField(_nameController, l10n.enterYourName),
          const SizedBox(height: AppSpacing.xl),

          // Grid selection
          _buildSectionTitle(l10n.gridSizeLabel),
          const SizedBox(height: 8),
          _buildGridSelector(),
          const SizedBox(height: AppSpacing.xl),

          // Turn time
          _buildSectionTitle(l10n.turnTimeLimit),
          const SizedBox(height: 8),
          _buildOptionRow(
            context: context,
            options: _turnTimeOptions,
            selectedValue: _selectedTurnTimeMs,
            onSelect: (v) => setState(() => _selectedTurnTimeMs = v),
          ),
          const SizedBox(height: AppSpacing.xxl),

          // Create button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _createGame,
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(l10n.createGame, style: AppTypography.button(context)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinScreen() {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBackButton(),
                const SizedBox(height: AppSpacing.xl),

                Text(l10n.joinGame, style: AppTypography.headline3(context)),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.enterTheCodeFromFriend,
                  style: AppTypography.body(context).copyWith(color: context.colors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.xl),

                if (_errorMessage != null) _buildErrorMessage(),

                // Name input
                _buildSectionTitle(l10n.yourName),
                const SizedBox(height: 8),
                _buildTextField(_nameController, l10n.enterYourName),
                const SizedBox(height: AppSpacing.xl),

                // Code input
                _buildSectionTitle(l10n.inviteCodeLabel),
                const SizedBox(height: 8),
                TextField(
                  controller: _codeController,
                  style: AppTypography.body(context).copyWith(
                    letterSpacing: 8,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(
                    hintText: l10n.codePlaceholder,
                    hintStyle: AppTypography.body(context).copyWith(
                      letterSpacing: 8,
                      color: context.colors.textTertiary,
                    ),
                    counterText: '',
                    filled: true,
                    fillColor: context.colors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Join button — stays above keyboard
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _joinGame,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.teal,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(l10n.joinGame, style: AppTypography.button(context)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWaitingScreen() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: _cancelWaiting,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(Icons.close, size: 24, color: context.colors.textPrimary),
              ),
            ),
          ),
          const Spacer(),

          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: context.colors.accent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(context.colors.accent),
              ),
            ),
          ),
          const SizedBox(height: 32),

          Text(
            l10n.waitingForOpponent,
            style: AppTypography.headline3(context),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _isPublicSession
                ? l10n.someoneWillJoinSoon
                : l10n.shareCodeWithFriend,
            style: AppTypography.body(context).copyWith(color: context.colors.textSecondary),
          ),
          const SizedBox(height: 24),

          _buildConnectionBanner(),

          if (!_isPublicSession) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.colors.elevated),
              ),
              child: Text(
                _inviteCode ?? '',
                style: AppTypography.headline3(context).copyWith(
                  letterSpacing: 6,
                  color: context.colors.accent,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: _copyInviteCode,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.button),
                      border: Border.all(color: context.colors.elevated),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.copy, size: 18, color: context.colors.textSecondary),
                        const SizedBox(width: 8),
                        Text(l10n.copy, style: AppTypography.bodySmall(context)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _shareInviteCode,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: context.colors.accent,
                      borderRadius: BorderRadius.circular(AppRadius.button),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.share, size: 18, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(l10n.share, style: AppTypography.bodySmall(context).copyWith(color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.pink.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Icon(Icons.public, size: 32, color: AppColors.pink),
                  const SizedBox(height: 8),
                  Text(
                    l10n.publicGame,
                    style: AppTypography.bodyLarge(context).copyWith(
                      color: AppColors.pink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.anyoneCanJoinThisGame,
                    style: AppTypography.bodySmall(context).copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const Spacer(),

          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton(
              onPressed: _cancelWaiting,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: context.colors.elevated),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
              ),
              child: Text(l10n.cancel, style: AppTypography.buttonSecondary(context)),
            ),
          ),
        ],
      ),
    );
  }

  /// Screen shown to HOST when opponent joins - shows "Start Game" button
  Widget _buildOpponentJoinedScreen() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Spacer(),

          Text(
            l10n.opponentJoinedTitle,
            style: AppTypography.headline3(context),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.readyToPlay,
            style: AppTypography.body(context).copyWith(color: context.colors.textSecondary),
          ),
          const SizedBox(height: 40),

          _VsPlayersWidget(
            player1Name: _nameController.text.isNotEmpty ? _nameController.text : l10n.youFallbackName,
            player2Name: _opponentName ?? l10n.opponent,
          ),
          const SizedBox(height: 32),

          // Game settings — values only, no labels
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_formatCategoryName(_selectedCategory),
                    style: AppTypography.bodySmall(context)
                        .copyWith(color: context.colors.textSecondary)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Container(
                    width: 4, height: 4,
                    decoration: BoxDecoration(
                      color: context.colors.textSecondary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Text(_selectedGrid,
                    style: AppTypography.bodySmall(context)
                        .copyWith(color: context.colors.textSecondary)),
              ],
            ),
          ),

          const Spacer(),

          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isStartingGame ? null : _hostStartGame,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.teal,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
              ),
              child: _isStartingGame
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(l10n.startGame, style: AppTypography.button(context)),
            ),
          ),
          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton(
              onPressed: _cancelWaiting,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: context.colors.elevated),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
              ),
              child: Text(l10n.cancel, style: AppTypography.buttonSecondary(context)),
            ),
          ),
        ],
      ),
    );
  }

  /// Screen shown to JOINER while waiting for host to start the game
  Widget _buildWaitingForHostScreen() {
    final l10n = AppLocalizations.of(context)!;
    final hostName = _currentSession?.player1Name ?? l10n.opponent;
    final myName = _nameController.text.isNotEmpty ? _nameController.text : l10n.youFallbackName;
    final category = _currentSession?.category;
    final gridSize = _currentSession?.gridSize ?? '4x5';

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Stack(
        children: [
          // Leave button — pinned to bottom
          Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton(
                onPressed: () async {
                  if (_sessionId != null) {
                    await MultiplayerService.removeJoiner(_sessionId!);
                  }
                  _sessionSubscription?.cancel();
                  _connectionSubscription?.cancel();
                  MultiplayerService.unsubscribeFromSession();
                  _popOrHome();
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: context.colors.elevated),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.button),
                  ),
                ),
                child: Text(l10n.leave, style: AppTypography.buttonSecondary(context)),
              ),
            ),
          ),

          // Main content — centered, scrollable on small screens
          Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.waitingForHostToStart,
                    style: AppTypography.headline3(context),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.joinedSuccessfully,
                    style: AppTypography.body(context).copyWith(color: context.colors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  _VsPlayersWidget(player1Name: hostName, player2Name: myName),
                  const SizedBox(height: 32),

                  // Game settings — values only, no labels
                  if (category != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatCategoryName(category),
                            style: AppTypography.bodySmall(context)
                                .copyWith(color: context.colors.textSecondary),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Container(
                              width: 4, height: 4,
                              decoration: BoxDecoration(
                                color: context.colors.textSecondary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          Text(
                            gridSize,
                            style: AppTypography.bodySmall(context)
                                .copyWith(color: context.colors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),

                  _buildConnectionBanner(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackButton() {
    return GestureDetector(
      onTap: _goBack,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Icon(Icons.arrow_back, size: 24, color: context.colors.textPrimary),
      ),
    );
  }

  Widget _buildOptionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.colors.elevated),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.bodyLarge(context)),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTypography.bodySmall(context).copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: context.colors.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: AppTypography.label(context));
  }

  Widget _buildTextField(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      maxLength: 20,
      onTap: () {
        controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: controller.text.length,
        );
      },
      style: AppTypography.body(context),
      decoration: InputDecoration(
        hintText: hint,
        counterText: '',
        filled: true,
        fillColor: context.colors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildGridSelector() {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: _gridOptions.map((grid) {
        final isSelected = _selectedGrid == grid['id'];
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedGrid = grid['id']),
            child: Container(
              margin: EdgeInsets.only(
                right: grid != _gridOptions.last ? 8 : 0,
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? context.colors.accent : context.colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? context.colors.accent : context.colors.elevated,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    grid['label'],
                    style: AppTypography.bodyLarge(context).copyWith(
                      color: isSelected ? Colors.white : context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _resolveDifficulty(l10n, grid['difficultyKey']),
                    style: AppTypography.labelSmall(context).copyWith(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.8)
                          : context.colors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildConnectionBanner() {
    final l10n = AppLocalizations.of(context)!;
    if (_connectionState == MultiplayerConnectionState.connected) {
      return const SizedBox.shrink();
    }
    final isDisconnected =
        _connectionState == MultiplayerConnectionState.disconnected;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: (isDisconnected ? Colors.red : Colors.orange)
            .withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                isDisconnected ? Colors.red : Colors.orange,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            isDisconnected ? l10n.connectionLost : l10n.reconnecting,
            style: AppTypography.bodySmall(context).copyWith(
              color: isDisconnected ? Colors.red : Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: AppTypography.bodySmall(context).copyWith(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  String _formatCategoryName(String category) {
    final raw = category.startsWith('tag:')
        ? (category.split(':').elementAtOrNull(2) ?? category)
        : category;
    return raw
        .split('_')
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Create Private Game screen — pushed on top of GrandCategoryScreen so that
// the back button correctly returns to category selection.
// ─────────────────────────────────────────────────────────────────────────────

class _CreatePrivateGameScreen extends ConsumerStatefulWidget {
  final String category;
  const _CreatePrivateGameScreen({required this.category});

  @override
  ConsumerState<_CreatePrivateGameScreen> createState() =>
      _CreatePrivateGameScreenState();
}

class _CreatePrivateGameScreenState
    extends ConsumerState<_CreatePrivateGameScreen> {
  final _nameController = TextEditingController();
  bool _nameSetFromProfile = false;
  String _selectedGrid = '4x5';
  int _selectedTurnTimeMs = 15000;

  bool _isLoading = false;
  bool _isWaiting = false;
  bool _isOpponentJoined = false;
  bool _isStartingGame = false;
  bool _navigatingToGame = false;

  String? _inviteCode;
  String? _sessionId;
  String? _opponentName;
  OnlineSession? _currentSession;
  String? _errorMessage;

  StreamSubscription<OnlineSession>? _sessionSubscription;
  StreamSubscription<MultiplayerConnectionState>? _connectionSubscription;
  MultiplayerConnectionState _connectionState =
      MultiplayerConnectionState.connected;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final profile = ref.read(userProfileNotifierProvider).valueOrNull;
      if (profile?.displayName != null && profile!.displayName!.isNotEmpty) {
        final dn = profile.displayName!;
        _nameController.text = dn.substring(0, dn.length.clamp(0, 20));
      } else {
        final user = SupabaseService.currentUser;
        if (user?.email != null) {
          final prefix = user!.email!.split('@').first;
          _nameController.text = prefix.substring(0, prefix.length.clamp(0, 20));
        }
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _sessionSubscription?.cancel();
    _connectionSubscription?.cancel();
    if (!_navigatingToGame && _isWaiting && _sessionId != null) {
      MultiplayerService.deleteSession(_sessionId!);
      MultiplayerService.unsubscribeFromSession();
    }
    super.dispose();
  }

  void _startConnectionListener() {
    _connectionSubscription?.cancel();
    _connectionSubscription =
        MultiplayerService.connectionStateStream.listen((state) {
      if (!mounted) return;
      setState(() => _connectionState = state);
    });
  }

  Future<void> _createGame() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _errorMessage = AppLocalizations.of(context)!.pleaseEnterYourName);
      return;
    }
    setState(() { _isLoading = true; _errorMessage = null; });

    final session = await MultiplayerService.createSession(
      category: widget.category,
      gridSize: _selectedGrid,
      playerName: _nameController.text.trim(),
      turnTimeLimitMs: _selectedTurnTimeMs,
    );

    if (session == null) {
      setState(() { _isLoading = false; _errorMessage = AppLocalizations.of(context)!.failedToCreateGame; });
      return;
    }

    setState(() {
      _isLoading = false;
      _isWaiting = true;
      _inviteCode = session.inviteCode;
      _sessionId = session.id;
    });

    _sessionSubscription =
        MultiplayerService.subscribeToSession(session.id).listen(
      (updatedSession) {
        _currentSession = updatedSession;
        if (updatedSession.isReady && updatedSession.hasOpponent) {
          setState(() {
            _isOpponentJoined = true;
            _opponentName = updatedSession.player2Name;
          });
        } else if (updatedSession.isPlaying) {
          _navigateToGame(updatedSession);
        } else if (_isOpponentJoined && updatedSession.isWaiting && !updatedSession.hasOpponent) {
          // Opponent left before game started — go back to waiting
          setState(() {
            _isOpponentJoined = false;
            _opponentName = null;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) showAppSnackBar(context, AppLocalizations.of(context)!.opponentLeftTheGame);
          });
        }
      },
    );
    _startConnectionListener();
  }

  Future<void> _hostStartGame() async {
    if (_currentSession == null || _sessionId == null) return;
    setState(() => _isStartingGame = true);

    List<SoundModel> sounds;
    if (widget.category.startsWith('tag:')) {
      final parts = widget.category.split(':');
      sounds = await DatabaseService.getSoundsByTag(
          parts[1], parts.sublist(2).join(':'));
    } else {
      sounds = await DatabaseService.getSoundsForCategory(widget.category);
    }
    if (sounds.isEmpty && widget.category != 'piano') {
      sounds = await DatabaseService.getSoundsForCategory('piano');
    }

    final cards = GameUtils.generateCards(
      gridSize: _selectedGrid,
      category: widget.category,
      soundIds: sounds.isNotEmpty ? sounds.map((s) => s.id).toList() : null,
    );

    final success = await MultiplayerService.startGame(
      sessionId: _sessionId!,
      cards: cards,
      hostId: SupabaseService.currentUser?.id ?? '',
    );

    if (!success) {
      setState(() { _isStartingGame = false; _errorMessage = AppLocalizations.of(context)!.failedToStartGame; });
    }
  }

  void _navigateToGame(OnlineSession session) {
    _navigatingToGame = true;
    _sessionSubscription?.cancel();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => OnlineGameScreen(
          session: session,
          playerName: _nameController.text.trim(),
        ),
      ),
    );
  }

  Future<void> _cancelAndPop() async {
    _sessionSubscription?.cancel();
    if (_sessionId != null) {
      if (_isOpponentJoined) {
        await MultiplayerService.cancelSession(_sessionId!);
      } else {
        MultiplayerService.deleteSession(_sessionId!);
      }
    }
    MultiplayerService.unsubscribeFromSession();
    if (mounted) {
      setState(() { _isWaiting = false; _isOpponentJoined = false; _sessionId = null; });
      Navigator.pop(context);
    }
  }

  void _copyInviteCode() {
    if (_inviteCode != null) {
      Clipboard.setData(ClipboardData(text: _inviteCode!));
      showAppSnackBar(context, AppLocalizations.of(context)!.codeCopied);
    }
  }

  Future<void> _shareInviteCode() async {
    if (_inviteCode == null) return;
    final box = context.findRenderObject() as RenderBox?;
    await Share.share(
      'Join my Music Memo game! Enter code $_inviteCode or tap: https://musicmemo.app/join?code=$_inviteCode',
      subject: 'Music Memo - Game Invite',
      sharePositionOrigin:
          box != null ? box.localToGlobal(Offset.zero) & box.size : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<UserProfile?>>(userProfileNotifierProvider,
        (prev, next) {
      if (!_nameSetFromProfile) {
        final name = next.valueOrNull?.displayName;
        if (name != null && name.isNotEmpty) {
          _nameController.text = name.substring(0, name.length.clamp(0, 20));
          _nameSetFromProfile = true;
        }
      }
    });

    return Scaffold(
      backgroundColor: context.colors.background,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: ResponsiveBody(
            child: _isOpponentJoined
                ? _buildOpponentJoinedScreen()
                : _isWaiting
                    ? _buildWaitingScreen()
                    : _buildCreateForm(),
          ),
        ),
      ),
    );
  }

  // ── Create form ─────────────────────────────────────────────────────────────

  Widget _buildCreateForm() {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBackButton(),
          const SizedBox(height: AppSpacing.xl),
          Text(l10n.createGame, style: AppTypography.headline3(context)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.setupGameInviteFriend,
            style: AppTypography.body(context)
                .copyWith(color: context.colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xl),
          if (_errorMessage != null) _buildErrorMessage(),
          _buildSectionTitle(l10n.yourName),
          const SizedBox(height: 8),
          _buildTextField(_nameController, l10n.enterYourName),
          const SizedBox(height: AppSpacing.xl),
          _buildSectionTitle(l10n.gridSizeLabel),
          const SizedBox(height: 8),
          _buildGridSelector(),
          const SizedBox(height: AppSpacing.xl),
          _buildSectionTitle(l10n.turnTimeLimit),
          const SizedBox(height: 8),
          _buildOptionRow(
            context: context,
            options: _turnTimeOptions,
            selectedValue: _selectedTurnTimeMs,
            onSelect: (v) => setState(() => _selectedTurnTimeMs = v),
          ),
          const SizedBox(height: AppSpacing.xxl),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _createGame,
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.accent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.button)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white)))
                  : Text(l10n.createGame, style: AppTypography.button(context)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Waiting for opponent ─────────────────────────────────────────────────────

  Widget _buildWaitingScreen() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: _cancelAndPop,
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: BorderRadius.circular(22)),
                child: Icon(Icons.close, size: 24, color: context.colors.textPrimary),
              ),
            ),
          ),
          const Spacer(),
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
                color: context.colors.accent.withValues(alpha: 0.1),
                shape: BoxShape.circle),
            child: Center(
              child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(context.colors.accent)),
            ),
          ),
          const SizedBox(height: 32),
          Text(l10n.waitingForOpponent, style: AppTypography.headline3(context), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(l10n.shareCodeWithFriend,
              style: AppTypography.body(context)
                  .copyWith(color: context.colors.textSecondary)),
          const SizedBox(height: 24),
          _buildConnectionBanner(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.colors.elevated)),
            child: Text(
              _inviteCode ?? '',
              style: AppTypography.headline3(context)
                  .copyWith(letterSpacing: 6, color: context.colors.accent),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _copyInviteCode,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.button),
                      border: Border.all(color: context.colors.elevated)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.copy, size: 18, color: context.colors.textSecondary),
                    const SizedBox(width: 8),
                    Text(l10n.copy, style: AppTypography.bodySmall(context)),
                  ]),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _shareInviteCode,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                      color: context.colors.accent,
                      borderRadius: BorderRadius.circular(AppRadius.button)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.share, size: 18, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(l10n.share,
                        style: AppTypography.bodySmall(context)
                            .copyWith(color: Colors.white)),
                  ]),
                ),
              ),
            ],
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity, height: 56,
            child: OutlinedButton(
              onPressed: _cancelAndPop,
              style: OutlinedButton.styleFrom(
                  side: BorderSide(color: context.colors.elevated),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.button))),
              child: Text(l10n.cancel, style: AppTypography.buttonSecondary(context)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Opponent joined ──────────────────────────────────────────────────────────

  Widget _buildOpponentJoinedScreen() {
    final l10n = AppLocalizations.of(context)!;
    final categoryName = _formatCategoryName(widget.category);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Spacer(),

          Text(l10n.opponentJoinedTitle, style: AppTypography.headline3(context), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            l10n.readyToPlay,
            style: AppTypography.body(context).copyWith(color: context.colors.textSecondary),
          ),
          const SizedBox(height: 40),

          _VsPlayersWidget(
            player1Name: _nameController.text.isNotEmpty ? _nameController.text : l10n.youFallbackName,
            player2Name: _opponentName ?? l10n.opponent,
          ),
          const SizedBox(height: 32),

          // Game settings — values only, no labels
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(12)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(categoryName,
                    style: AppTypography.bodySmall(context)
                        .copyWith(color: context.colors.textSecondary)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Container(
                    width: 4, height: 4,
                    decoration: BoxDecoration(
                      color: context.colors.textSecondary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Text(_selectedGrid,
                    style: AppTypography.bodySmall(context)
                        .copyWith(color: context.colors.textSecondary)),
              ],
            ),
          ),

          const Spacer(),
          if (_errorMessage != null) ...[_buildErrorMessage(), const SizedBox(height: 8)],
          SizedBox(
            width: double.infinity, height: 56,
            child: ElevatedButton(
              onPressed: _isStartingGame ? null : _hostStartGame,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.button))),
              child: _isStartingGame
                  ? const SizedBox(
                      width: 24, height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                  : Text(l10n.startGame, style: AppTypography.button(context)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity, height: 56,
            child: OutlinedButton(
              onPressed: _cancelAndPop,
              style: OutlinedButton.styleFrom(
                  side: BorderSide(color: context.colors.elevated),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.button))),
              child: Text(l10n.cancel, style: AppTypography.buttonSecondary(context)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  Widget _buildBackButton() {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(22)),
        child: Icon(Icons.arrow_back, size: 24, color: context.colors.textPrimary),
      ),
    );
  }

  Widget _buildSectionTitle(String title) =>
      Text(title, style: AppTypography.label(context));

  Widget _buildTextField(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      maxLength: 20,
      onTap: () {
        controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: controller.text.length,
        );
      },
      style: AppTypography.body(context),
      decoration: InputDecoration(
        hintText: hint,
        counterText: '',
        filled: true,
        fillColor: context.colors.surface,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildGridSelector() {
    return Row(
      children: _gridOptions.map((grid) {
        final isSelected = _selectedGrid == grid['id'];
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedGrid = grid['id']),
            child: Container(
              margin: EdgeInsets.only(right: grid != _gridOptions.last ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? context.colors.accent : context.colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: isSelected
                        ? context.colors.accent
                        : context.colors.elevated),
              ),
              child: Column(children: [
                Text(grid['label'],
                    style: AppTypography.bodyLarge(context).copyWith(
                        color: isSelected
                            ? Colors.white
                            : context.colors.textPrimary)),
                const SizedBox(height: 2),
                Text(_resolveDifficulty(AppLocalizations.of(context)!, grid['difficultyKey']),
                    style: AppTypography.labelSmall(context).copyWith(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.8)
                            : context.colors.textTertiary)),
              ]),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildConnectionBanner() {
    final l10n = AppLocalizations.of(context)!;
    if (_connectionState == MultiplayerConnectionState.connected) {
      return const SizedBox.shrink();
    }
    final isDisconnected =
        _connectionState == MultiplayerConnectionState.disconnected;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: (isDisconnected ? Colors.red : Colors.orange)
              .withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        SizedBox(
          width: 14, height: 14,
          child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                  isDisconnected ? Colors.red : Colors.orange)),
        ),
        const SizedBox(width: 10),
        Text(isDisconnected ? l10n.connectionLost : l10n.reconnecting,
            style: AppTypography.bodySmall(context)
                .copyWith(color: isDisconnected ? Colors.red : Colors.orange)),
      ]),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        const Icon(Icons.error_outline, color: Colors.red, size: 20),
        const SizedBox(width: 8),
        Expanded(
            child: Text(_errorMessage!,
                style: AppTypography.bodySmall(context)
                    .copyWith(color: Colors.red))),
      ]),
    );
  }

  String _formatCategoryName(String category) {
    final raw = category.startsWith('tag:')
        ? (category.split(':').elementAtOrNull(2) ?? category)
        : category;
    return raw
        .split('_')
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Find Opponent screen — pushed on top of GrandCategoryScreen after a category
// is picked. Handles the public-session flow: auto-search on entry, then
// either join a waiting public session, or show a form to create one.
// ─────────────────────────────────────────────────────────────────────────────

enum _FindPhase { searching, form, waitingForOpponent, waitingForHost }

class _FindOpponentScreen extends ConsumerStatefulWidget {
  final String category;
  const _FindOpponentScreen({required this.category});

  @override
  ConsumerState<_FindOpponentScreen> createState() =>
      _FindOpponentScreenState();
}

class _FindOpponentScreenState extends ConsumerState<_FindOpponentScreen> {
  final _nameController = TextEditingController();
  bool _nameSetFromProfile = false;
  String _selectedGrid = '4x5';
  int _selectedTurnTimeMs = 15000;

  _FindPhase _phase = _FindPhase.searching;
  bool _isLoading = false;
  bool _navigatingToGame = false;

  String? _sessionId;
  OnlineSession? _currentSession;
  String? _errorMessage;

  StreamSubscription<OnlineSession>? _sessionSubscription;
  StreamSubscription<MultiplayerConnectionState>? _connectionSubscription;
  MultiplayerConnectionState _connectionState =
      MultiplayerConnectionState.connected;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final profile = ref.read(userProfileNotifierProvider).valueOrNull;
      if (profile?.displayName != null && profile!.displayName!.isNotEmpty) {
        final dn = profile.displayName!;
        _nameController.text = dn.substring(0, dn.length.clamp(0, 20));
      } else {
        final user = SupabaseService.currentUser;
        if (user?.email != null) {
          final prefix = user!.email!.split('@').first;
          _nameController.text = prefix.substring(0, prefix.length.clamp(0, 20));
        }
      }
      // Auto-search as soon as the screen opens.
      _searchForOpponent();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _sessionSubscription?.cancel();
    _connectionSubscription?.cancel();
    if (!_navigatingToGame && _sessionId != null &&
        _phase == _FindPhase.waitingForOpponent) {
      MultiplayerService.deleteSession(_sessionId!);
      MultiplayerService.unsubscribeFromSession();
    }
    super.dispose();
  }

  void _startConnectionListener() {
    _connectionSubscription?.cancel();
    _connectionSubscription =
        MultiplayerService.connectionStateStream.listen((state) {
      if (!mounted) return;
      setState(() => _connectionState = state);
    });
  }

  Future<void> _searchForOpponent() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() {
        _phase = _FindPhase.form;
        _errorMessage =
            AppLocalizations.of(context)!.pleaseEnterYourName;
      });
      return;
    }

    setState(() {
      _phase = _FindPhase.searching;
      _errorMessage = null;
    });

    final publicSession = await MultiplayerService.findPublicSession();
    if (!mounted) return;

    if (publicSession != null) {
      final joined = await MultiplayerService.joinSessionById(
        sessionId: publicSession.id,
        playerName: _nameController.text.trim(),
      );
      if (!mounted) return;

      if (joined != null) {
        _currentSession = joined;
        _sessionId = joined.id;
        setState(() => _phase = _FindPhase.waitingForHost);

        _sessionSubscription =
            MultiplayerService.subscribeToSession(joined.id).listen(
          (updatedSession) {
            if (updatedSession.isCancelled) {
              _sessionSubscription?.cancel();
              _connectionSubscription?.cancel();
              MultiplayerService.unsubscribeFromSession();
              if (!mounted) return;
              setState(() => _phase = _FindPhase.form);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  showAppSnackBar(
                      context,
                      AppLocalizations.of(context)!.hostCancelledGame);
                }
              });
              return;
            }
            _currentSession = updatedSession;
            if (updatedSession.isPlaying) {
              _navigateToGame(updatedSession);
            }
          },
        );
        _startConnectionListener();
        return;
      }
    }

    // No public session found — drop to form so the user can create one.
    setState(() => _phase = _FindPhase.form);
  }

  Future<void> _createPublicGame() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _errorMessage =
          AppLocalizations.of(context)!.pleaseEnterYourName);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final session = await MultiplayerService.createSession(
      category: widget.category,
      gridSize: _selectedGrid,
      playerName: _nameController.text.trim(),
      isPublic: true,
      turnTimeLimitMs: _selectedTurnTimeMs,
    );
    if (!mounted) return;

    if (session == null) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            AppLocalizations.of(context)!.failedToCreateGame;
      });
      return;
    }

    setState(() {
      _isLoading = false;
      _phase = _FindPhase.waitingForOpponent;
      _sessionId = session.id;
    });

    _sessionSubscription =
        MultiplayerService.subscribeToSession(session.id).listen(
      (updatedSession) {
        _currentSession = updatedSession;
        if (updatedSession.isReady && updatedSession.hasOpponent) {
          // Someone joined — auto-start the game.
          _hostStartGame();
        } else if (updatedSession.isPlaying) {
          _navigateToGame(updatedSession);
        }
      },
    );
    _startConnectionListener();
  }

  Future<void> _hostStartGame() async {
    if (_currentSession == null || _sessionId == null) return;

    List<SoundModel> sounds;
    if (widget.category.startsWith('tag:')) {
      final parts = widget.category.split(':');
      sounds = await DatabaseService.getSoundsByTag(
          parts[1], parts.sublist(2).join(':'));
    } else {
      sounds = await DatabaseService.getSoundsForCategory(widget.category);
    }
    if (sounds.isEmpty && widget.category != 'piano') {
      sounds = await DatabaseService.getSoundsForCategory('piano');
    }

    final cards = GameUtils.generateCards(
      gridSize: _selectedGrid,
      category: widget.category,
      soundIds: sounds.isNotEmpty ? sounds.map((s) => s.id).toList() : null,
    );

    await MultiplayerService.startGame(
      sessionId: _sessionId!,
      cards: cards,
      hostId: SupabaseService.currentUser?.id ?? '',
    );
    // Navigation happens via the subscription when status becomes 'playing'.
  }

  void _navigateToGame(OnlineSession session) {
    _navigatingToGame = true;
    _sessionSubscription?.cancel();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => OnlineGameScreen(
          session: session,
          playerName: _nameController.text.trim(),
        ),
      ),
    );
  }

  Future<void> _cancelAndPop() async {
    _sessionSubscription?.cancel();
    if (_sessionId != null && _phase == _FindPhase.waitingForOpponent) {
      await MultiplayerService.deleteSession(_sessionId!);
    } else if (_sessionId != null && _phase == _FindPhase.waitingForHost) {
      await MultiplayerService.removeJoiner(_sessionId!);
    }
    MultiplayerService.unsubscribeFromSession();
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<UserProfile?>>(userProfileNotifierProvider,
        (prev, next) {
      if (!_nameSetFromProfile) {
        final name = next.valueOrNull?.displayName;
        if (name != null && name.isNotEmpty) {
          _nameController.text =
              name.substring(0, name.length.clamp(0, 20));
          _nameSetFromProfile = true;
        }
      }
    });

    return PopScope(
      canPop: _phase == _FindPhase.form || _phase == _FindPhase.searching,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _cancelAndPop();
      },
      child: Scaffold(
        backgroundColor: context.colors.background,
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SafeArea(
            child: ResponsiveBody(
              child: switch (_phase) {
                _FindPhase.searching => _buildSearchingView(),
                _FindPhase.form => _buildForm(),
                _FindPhase.waitingForOpponent => _buildWaitingForOpponent(),
                _FindPhase.waitingForHost => _buildWaitingForHost(),
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchingView() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBackButton(),
          const Spacer(),
          Center(
            child: Column(
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.pink),
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.lookingForOpponents,
                  style: AppTypography.body(context)
                      .copyWith(color: context.colors.textSecondary),
                ),
              ],
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildForm() {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBackButton(),
          const SizedBox(height: AppSpacing.xl),
          Text(l10n.findOpponent, style: AppTypography.headline3(context)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.noPlayersFoundCreateGame,
            style: AppTypography.body(context)
                .copyWith(color: context.colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xl),
          if (_errorMessage != null) _buildErrorMessage(),
          _buildSectionTitle(l10n.yourName),
          const SizedBox(height: 8),
          _buildTextField(_nameController, l10n.enterYourName),
          const SizedBox(height: AppSpacing.xl),
          _buildSectionTitle(l10n.gridSizeLabel),
          const SizedBox(height: 8),
          _buildGridSelector(),
          const SizedBox(height: AppSpacing.xl),
          _buildSectionTitle(l10n.turnTimeLimit),
          const SizedBox(height: 8),
          _buildOptionRow(
            context: context,
            options: _turnTimeOptions,
            selectedValue: _selectedTurnTimeMs,
            onSelect: (v) => setState(() => _selectedTurnTimeMs = v),
          ),
          const SizedBox(height: AppSpacing.xxl),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _createPublicGame,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.pink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(l10n.createAndWaitForOpponent,
                      style: AppTypography.button(context)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton(
              onPressed: _searchForOpponent,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: context.colors.elevated),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
              ),
              child: Text(l10n.searchAgain,
                  style: AppTypography.buttonSecondary(context)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingForOpponent() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: _cancelAndPop,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(Icons.close,
                    size: 24, color: context.colors.textPrimary),
              ),
            ),
          ),
          const Spacer(),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: context.colors.accent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(context.colors.accent),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            l10n.waitingForOpponent,
            style: AppTypography.headline3(context),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.someoneWillJoinSoon,
            style: AppTypography.body(context)
                .copyWith(color: context.colors.textSecondary),
          ),
          const SizedBox(height: 24),
          _buildConnectionBanner(),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.pink.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Icon(Icons.public, size: 32, color: AppColors.pink),
                const SizedBox(height: 8),
                Text(
                  l10n.publicGame,
                  style: AppTypography.bodyLarge(context).copyWith(
                    color: AppColors.pink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.anyoneCanJoinThisGame,
                  style: AppTypography.bodySmall(context)
                      .copyWith(color: context.colors.textSecondary),
                ),
              ],
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton(
              onPressed: _cancelAndPop,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: context.colors.elevated),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
              ),
              child: Text(l10n.cancel,
                  style: AppTypography.buttonSecondary(context)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingForHost() {
    final l10n = AppLocalizations.of(context)!;
    final hostName = _currentSession?.player1Name ?? l10n.opponent;
    final myName = _nameController.text.isNotEmpty
        ? _nameController.text
        : l10n.youFallbackName;
    final category = _currentSession?.category;
    final gridSize = _currentSession?.gridSize ?? '4x5';

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Stack(
        children: [
          Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton(
                onPressed: _cancelAndPop,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: context.colors.elevated),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.button),
                  ),
                ),
                child: Text(l10n.leave,
                    style: AppTypography.buttonSecondary(context)),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.waitingForHostToStart,
                    style: AppTypography.headline3(context),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.joinedSuccessfully,
                    style: AppTypography.body(context)
                        .copyWith(color: context.colors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  _VsPlayersWidget(
                      player1Name: hostName, player2Name: myName),
                  const SizedBox(height: 32),
                  if (category != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatCategoryName(category),
                            style: AppTypography.bodySmall(context).copyWith(
                                color: context.colors.textSecondary),
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 10),
                            child: Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: context.colors.textSecondary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          Text(
                            gridSize,
                            style: AppTypography.bodySmall(context).copyWith(
                                color: context.colors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  _buildConnectionBanner(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers (duplicated from _CreatePrivateGameScreen for isolation) ─────

  Widget _buildBackButton() {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(22),
        ),
        child:
            Icon(Icons.arrow_back, size: 24, color: context.colors.textPrimary),
      ),
    );
  }

  Widget _buildSectionTitle(String title) =>
      Text(title, style: AppTypography.label(context));

  Widget _buildTextField(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      maxLength: 20,
      onTap: () {
        controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: controller.text.length,
        );
      },
      style: AppTypography.body(context),
      decoration: InputDecoration(
        hintText: hint,
        counterText: '',
        filled: true,
        fillColor: context.colors.surface,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildGridSelector() {
    return Row(
      children: _gridOptions.map((grid) {
        final isSelected = _selectedGrid == grid['id'];
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedGrid = grid['id']),
            child: Container(
              margin: EdgeInsets.only(right: grid != _gridOptions.last ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color:
                    isSelected ? context.colors.accent : context.colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: isSelected
                        ? context.colors.accent
                        : context.colors.elevated),
              ),
              child: Column(children: [
                Text(grid['label'],
                    style: AppTypography.bodyLarge(context).copyWith(
                        color: isSelected
                            ? Colors.white
                            : context.colors.textPrimary)),
                const SizedBox(height: 2),
                Text(
                    _resolveDifficulty(
                        AppLocalizations.of(context)!, grid['difficultyKey']),
                    style: AppTypography.labelSmall(context).copyWith(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.8)
                            : context.colors.textTertiary)),
              ]),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildConnectionBanner() {
    final l10n = AppLocalizations.of(context)!;
    if (_connectionState == MultiplayerConnectionState.connected) {
      return const SizedBox.shrink();
    }
    final isDisconnected =
        _connectionState == MultiplayerConnectionState.disconnected;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: (isDisconnected ? Colors.red : Colors.orange)
              .withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                  isDisconnected ? Colors.red : Colors.orange)),
        ),
        const SizedBox(width: 10),
        Text(isDisconnected ? l10n.connectionLost : l10n.reconnecting,
            style: AppTypography.bodySmall(context)
                .copyWith(color: isDisconnected ? Colors.red : Colors.orange)),
      ]),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        const Icon(Icons.error_outline, color: Colors.red, size: 20),
        const SizedBox(width: 8),
        Expanded(
            child: Text(_errorMessage!,
                style: AppTypography.bodySmall(context)
                    .copyWith(color: Colors.red))),
      ]),
    );
  }

  String _formatCategoryName(String category) {
    final raw = category.startsWith('tag:')
        ? (category.split(':').elementAtOrNull(2) ?? category)
        : category;
    return raw
        .split('_')
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }
}

/// Two player avatars with an animated pulsing VS badge between them.
class _VsPlayersWidget extends StatefulWidget {
  final String player1Name;
  final String player2Name;

  const _VsPlayersWidget({required this.player1Name, required this.player2Name});

  @override
  State<_VsPlayersWidget> createState() => _VsPlayersWidgetState();
}

class _VsPlayersWidgetState extends State<_VsPlayersWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);
    _scaleAnim = Tween<double>(begin: 0.88, end: 1.12).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildAvatar(widget.player1Name, context.colors.accent, context),
        const SizedBox(width: 20),
        ScaleTransition(
          scale: _scaleAnim,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: context.colors.accent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: context.colors.accent.withValues(alpha: 0.45),
                  blurRadius: 14,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Center(
              child: Text(
                'VS',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 20),
        _buildAvatar(widget.player2Name, AppColors.teal, context),
      ],
    );
  }

  Widget _buildAvatar(String name, Color color, BuildContext context) {
    return Column(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.4), width: 2),
          ),
          child: Icon(Icons.person_rounded, size: 38, color: color),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 80,
          child: Text(
            name,
            style: AppTypography.bodySmall(context)
                .copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
