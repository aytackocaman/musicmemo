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

/// Grid options
final List<Map<String, dynamic>> _gridOptions = [
  if (kDebugMode) {'id': '2x3', 'label': '2x3', 'pairs': 3, 'difficulty': 'Test'},
  {'id': '4x5', 'label': '4x5', 'pairs': 10, 'difficulty': 'Easy'},
  {'id': '5x6', 'label': '5x6', 'pairs': 15, 'difficulty': 'Medium'},
  {'id': '6x7', 'label': '6x7', 'pairs': 21, 'difficulty': 'Hard'},
];

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
        _nameController.text = displayName;
      } else {
        final user = SupabaseService.currentUser;
        if (user?.email != null) {
          _nameController.text = user!.email!.split('@').first;
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

  void _showFindOpponent() {
    setState(() {
      _isFindOpponentMode = true;
      _isCreateMode = false;
      _isJoinMode = false;
      _errorMessage = null;
    });
    // Immediately search for an available public session
    _searchForOpponent();
  }

  Future<void> _searchForOpponent() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter your name');
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
      setState(() => _errorMessage = 'Please enter your name');
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
    );

    if (session == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to create game. Please try again.';
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
      setState(() => _errorMessage = 'Please enter your name');
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
    );

    if (session == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to create game. Please try again.';
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
        }
      },
    );
    _startConnectionListener();
  }

  Future<void> _joinGame() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter your name');
      return;
    }

    final code = _codeController.text.trim();
    if (code.isEmpty || code.length != 6) {
      setState(() => _errorMessage = 'Please enter a valid 6-digit code');
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
        _errorMessage = 'Game not found or already started. Check the code and try again.';
      });
      return;
    }

    // Store session and show waiting for host screen
    _currentSession = session;
    _sessionId = session.id;

    setState(() {
      _isWaitingForHostToStart = true;
    });

    // Subscribe to session updates to know when host starts the game
    _sessionSubscription =
        MultiplayerService.subscribeToSession(session.id).listen(
      (updatedSession) {
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
      await MultiplayerService.deleteSession(_sessionId!);
    }
    _sessionSubscription?.cancel();
    await MultiplayerService.unsubscribeFromSession();

    setState(() {
      _isWaitingForOpponent = false;
      _isPublicSession = false;
      _inviteCode = null;
      _sessionId = null;
    });
  }

  void _copyInviteCode() {
    if (_inviteCode != null) {
      Clipboard.setData(ClipboardData(text: _inviteCode!));
      showAppSnackBar(context, 'Code copied!');
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
        _errorMessage = 'Failed to start game. Please try again.';
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
          _nameController.text = name;
          _nameSetFromProfile = true;
        }
      }
    });

    return Scaffold(
      backgroundColor: context.colors.background,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
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
    );
  }

  Widget _buildMainScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBackButton(),
          const SizedBox(height: AppSpacing.xl),

          Text('Online Multiplayer', style: AppTypography.headline3(context)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Play with friends in real-time',
            style: AppTypography.body(context).copyWith(color: context.colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xxl),

          // Find Opponent option
          _buildOptionCard(
            icon: Icons.person_search,
            iconColor: AppColors.pink,
            title: 'Find Opponent',
            subtitle: 'Get matched with a random player',
            onTap: () async {
              ref.read(selectedGameModeProvider.notifier).state =
                  GameMode.onlineMultiplayer;
              final navigator = Navigator.of(context);
              await navigator.push(
                MaterialPageRoute(builder: (_) => const GrandCategoryScreen()),
              );
              final picked = ref.read(selectedCategoryProvider);
              if (picked != null && mounted) {
                setState(() => _selectedCategory = picked);
                _showFindOpponent();
              }
            },
          ),
          const SizedBox(height: AppSpacing.lg),

          // Create Game option
          _buildOptionCard(
            icon: Icons.add_circle_outline,
            iconColor: AppColors.purple,
            title: 'Create Private Game',
            subtitle: 'Start a new game and invite a friend',
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
            title: 'Join Private Game',
            subtitle: 'Enter a code to join your friend',
            onTap: _showJoinOptions,
          ),
        ],
      ),
    );
  }

  Widget _buildFindOpponentScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBackButton(),
          const SizedBox(height: AppSpacing.xl),

          Text('Find Opponent', style: AppTypography.headline3(context)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _isSearchingForOpponent
                ? 'Searching for available players...'
                : 'No players found. Create a game and wait for someone to join!',
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
                      'Looking for opponents...',
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
            _buildSectionTitle('Your Name'),
            const SizedBox(height: 8),
            _buildTextField(_nameController, 'Enter your name'),
            const SizedBox(height: AppSpacing.xl),

            // Grid selection
            _buildSectionTitle('Grid Size'),
            const SizedBox(height: 8),
            _buildGridSelector(),
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
                    : Text('Create & Wait for Opponent',
                        style: AppTypography.button),
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
                    Text('Search Again', style: AppTypography.buttonSecondary(context)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCreateScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBackButton(),
          const SizedBox(height: AppSpacing.xl),

          Text('Create Game', style: AppTypography.headline3(context)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Set up the game and invite a friend',
            style: AppTypography.body(context).copyWith(color: context.colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xl),

          if (_errorMessage != null) _buildErrorMessage(),

          // Name input
          _buildSectionTitle('Your Name'),
          const SizedBox(height: 8),
          _buildTextField(_nameController, 'Enter your name'),
          const SizedBox(height: AppSpacing.xl),

          // Grid selection
          _buildSectionTitle('Grid Size'),
          const SizedBox(height: 8),
          _buildGridSelector(),
          const SizedBox(height: AppSpacing.xxl),

          // Create button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _createGame,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.purple,
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
                  : Text('Create Game', style: AppTypography.button),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBackButton(),
          const SizedBox(height: AppSpacing.xl),

          Text('Join Game', style: AppTypography.headline3(context)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Enter the code from your friend',
            style: AppTypography.body(context).copyWith(color: context.colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xl),

          if (_errorMessage != null) _buildErrorMessage(),

          // Name input
          _buildSectionTitle('Your Name'),
          const SizedBox(height: 8),
          _buildTextField(_nameController, 'Enter your name'),
          const SizedBox(height: AppSpacing.xl),

          // Code input
          _buildSectionTitle('Invite Code'),
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
              hintText: '000000',
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
          const SizedBox(height: AppSpacing.xxl),

          // Join button
          SizedBox(
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
                  : Text('Join Game', style: AppTypography.button),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingScreen() {
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
              color: AppColors.purple.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.purple),
              ),
            ),
          ),
          const SizedBox(height: 32),

          Text(
            'Waiting for opponent...',
            style: AppTypography.headline3(context),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _isPublicSession
                ? 'Someone will join your game soon'
                : 'Share this code with a friend',
            style: AppTypography.body(context).copyWith(color: context.colors.textSecondary),
          ),
          const SizedBox(height: 24),

          _buildConnectionBanner(),

          if (!_isPublicSession) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.colors.elevated),
              ),
              child: Text(
                _inviteCode ?? '',
                style: AppTypography.headline2(context).copyWith(
                  letterSpacing: 8,
                  color: AppColors.purple,
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
                        Text('Copy', style: AppTypography.bodySmall(context)),
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
                      color: AppColors.purple,
                      borderRadius: BorderRadius.circular(AppRadius.button),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.share, size: 18, color: Colors.white),
                        const SizedBox(width: 8),
                        Text('Share', style: AppTypography.bodySmall(context).copyWith(color: Colors.white)),
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
                    'Public Game',
                    style: AppTypography.bodyLarge(context).copyWith(
                      color: AppColors.pink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Anyone can find and join this game',
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
              child: Text('Cancel', style: AppTypography.buttonSecondary(context)),
            ),
          ),
        ],
      ),
    );
  }

  /// Screen shown to HOST when opponent joins - shows "Start Game" button
  Widget _buildOpponentJoinedScreen() {
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

          Text(
            'Opponent Joined!',
            style: AppTypography.headline3(context),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Ready to play',
            style: AppTypography.body(context).copyWith(color: context.colors.textSecondary),
          ),
          const SizedBox(height: 40),

          _VsPlayersWidget(
            player1Name: _nameController.text.isNotEmpty ? _nameController.text : 'You',
            player2Name: _opponentName ?? 'Opponent',
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
                  : Text('Start Game', style: AppTypography.button),
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
              child: Text('Cancel', style: AppTypography.buttonSecondary(context)),
            ),
          ),
        ],
      ),
    );
  }

  /// Screen shown to JOINER while waiting for host to start the game
  Widget _buildWaitingForHostScreen() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () {
                _sessionSubscription?.cancel();
                _connectionSubscription?.cancel();
                MultiplayerService.unsubscribeFromSession();
                _popOrHome();
              },
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
              color: AppColors.teal.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.teal),
              ),
            ),
          ),
          const SizedBox(height: 32),

          Text(
            'Joined Successfully!',
            style: AppTypography.headline3(context),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Waiting for host to start the game...',
            style: AppTypography.body(context).copyWith(color: context.colors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          _buildConnectionBanner(),
          const SizedBox(height: 8),

          // Game info
          if (_currentSession != null)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.person, color: AppColors.purple, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Host: ${_currentSession!.player1Name ?? "Player 1"}',
                        style: AppTypography.body(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(
                            _currentSession!.category ?? 'Unknown',
                            style: AppTypography.bodySmall(context),
                          ),
                          Text('Category', style: AppTypography.labelSmall(context)),
                        ],
                      ),
                      Container(width: 1, height: 30, color: context.colors.elevated),
                      Column(
                        children: [
                          Text(
                            _currentSession!.gridSize ?? '4x5',
                            style: AppTypography.bodySmall(context),
                          ),
                          Text('Grid', style: AppTypography.labelSmall(context)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

          const Spacer(),

          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton(
              onPressed: () {
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
              child: Text('Leave', style: AppTypography.buttonSecondary(context)),
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
      style: AppTypography.body(context),
      decoration: InputDecoration(
        hintText: hint,
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
                color: isSelected ? AppColors.purple : context.colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppColors.purple : context.colors.elevated,
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
                    grid['difficulty'],
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
            isDisconnected ? 'Connection lost' : 'Reconnecting...',
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
        _nameController.text = profile.displayName!;
      } else {
        final user = SupabaseService.currentUser;
        if (user?.email != null) {
          _nameController.text = user!.email!.split('@').first;
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
      setState(() => _errorMessage = 'Please enter your name');
      return;
    }
    setState(() { _isLoading = true; _errorMessage = null; });

    final session = await MultiplayerService.createSession(
      category: widget.category,
      gridSize: _selectedGrid,
      playerName: _nameController.text.trim(),
    );

    if (session == null) {
      setState(() { _isLoading = false; _errorMessage = 'Failed to create game. Please try again.'; });
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
      setState(() { _isStartingGame = false; _errorMessage = 'Failed to start game. Please try again.'; });
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
    if (_sessionId != null) MultiplayerService.deleteSession(_sessionId!);
    MultiplayerService.unsubscribeFromSession();
    if (mounted) {
      setState(() { _isWaiting = false; _sessionId = null; });
      Navigator.pop(context);
    }
  }

  void _copyInviteCode() {
    if (_inviteCode != null) {
      Clipboard.setData(ClipboardData(text: _inviteCode!));
      showAppSnackBar(context, 'Code copied!');
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
          _nameController.text = name;
          _nameSetFromProfile = true;
        }
      }
    });

    return Scaffold(
      backgroundColor: context.colors.background,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: _isOpponentJoined
              ? _buildOpponentJoinedScreen()
              : _isWaiting
                  ? _buildWaitingScreen()
                  : _buildCreateForm(),
        ),
      ),
    );
  }

  // ── Create form ─────────────────────────────────────────────────────────────

  Widget _buildCreateForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBackButton(),
          const SizedBox(height: AppSpacing.xl),
          Text('Create Game', style: AppTypography.headline3(context)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Set up the game and invite a friend',
            style: AppTypography.body(context)
                .copyWith(color: context.colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xl),
          if (_errorMessage != null) _buildErrorMessage(),
          _buildSectionTitle('Your Name'),
          const SizedBox(height: 8),
          _buildTextField(_nameController, 'Enter your name'),
          const SizedBox(height: AppSpacing.xl),
          _buildSectionTitle('Grid Size'),
          const SizedBox(height: 8),
          _buildGridSelector(),
          const SizedBox(height: AppSpacing.xxl),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _createGame,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.purple,
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
                  : Text('Create Game', style: AppTypography.button),
            ),
          ),
        ],
      ),
    );
  }

  // ── Waiting for opponent ─────────────────────────────────────────────────────

  Widget _buildWaitingScreen() {
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
                color: AppColors.purple.withValues(alpha: 0.1),
                shape: BoxShape.circle),
            child: const Center(
              child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.purple)),
            ),
          ),
          const SizedBox(height: 32),
          Text('Waiting for opponent...', style: AppTypography.headline3(context), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('Share this code with a friend',
              style: AppTypography.body(context)
                  .copyWith(color: context.colors.textSecondary)),
          const SizedBox(height: 24),
          _buildConnectionBanner(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
            decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.colors.elevated)),
            child: Text(
              _inviteCode ?? '',
              style: AppTypography.headline2(context)
                  .copyWith(letterSpacing: 8, color: AppColors.purple),
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
                    Text('Copy', style: AppTypography.bodySmall(context)),
                  ]),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _shareInviteCode,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                      color: AppColors.purple,
                      borderRadius: BorderRadius.circular(AppRadius.button)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.share, size: 18, color: Colors.white),
                    const SizedBox(width: 8),
                    Text('Share',
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
              child: Text('Cancel', style: AppTypography.buttonSecondary(context)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Opponent joined ──────────────────────────────────────────────────────────

  Widget _buildOpponentJoinedScreen() {
    final categoryName = _formatCategoryName(widget.category);
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

          Text('Opponent Joined!', style: AppTypography.headline3(context), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'Ready to play',
            style: AppTypography.body(context).copyWith(color: context.colors.textSecondary),
          ),
          const SizedBox(height: 40),

          _VsPlayersWidget(
            player1Name: _nameController.text.isNotEmpty ? _nameController.text : 'You',
            player2Name: _opponentName ?? 'Opponent',
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
                  : Text('Start Game', style: AppTypography.button),
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
              child: Text('Cancel', style: AppTypography.buttonSecondary(context)),
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
      style: AppTypography.body(context),
      decoration: InputDecoration(
        hintText: hint,
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
                color: isSelected ? AppColors.purple : context.colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: isSelected
                        ? AppColors.purple
                        : context.colors.elevated),
              ),
              child: Column(children: [
                Text(grid['label'],
                    style: AppTypography.bodyLarge(context).copyWith(
                        color: isSelected
                            ? Colors.white
                            : context.colors.textPrimary)),
                const SizedBox(height: 2),
                Text(grid['difficulty'],
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
        Text(isDisconnected ? 'Connection lost' : 'Reconnecting...',
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
        _buildAvatar(widget.player1Name, AppColors.purple, context),
        const SizedBox(width: 20),
        ScaleTransition(
          scale: _scaleAnim,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.purple,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.purple.withValues(alpha: 0.45),
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
