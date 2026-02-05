import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../services/multiplayer_service.dart';
import '../../services/supabase_service.dart';
import '../../utils/game_utils.dart';
import 'online_game_screen.dart';

/// Categories available for selection
const List<Map<String, dynamic>> _categories = [
  {'id': 'animals', 'name': 'Animals', 'icon': Icons.pets},
  {'id': 'instruments', 'name': 'Instruments', 'icon': Icons.music_note},
  {'id': 'nature', 'name': 'Nature', 'icon': Icons.eco},
  {'id': 'vehicles', 'name': 'Vehicles', 'icon': Icons.directions_car},
  {'id': 'household', 'name': 'Household', 'icon': Icons.home},
  {'id': 'sports', 'name': 'Sports', 'icon': Icons.sports_soccer},
];

/// Grid options
const List<Map<String, dynamic>> _gridOptions = [
  {'id': '4x5', 'label': '4x5', 'pairs': 10, 'difficulty': 'Easy'},
  {'id': '5x6', 'label': '5x6', 'pairs': 15, 'difficulty': 'Medium'},
  {'id': '6x7', 'label': '6x7', 'pairs': 21, 'difficulty': 'Hard'},
];

class OnlineModeScreen extends ConsumerStatefulWidget {
  const OnlineModeScreen({super.key});

  @override
  ConsumerState<OnlineModeScreen> createState() => _OnlineModeScreenState();
}

class _OnlineModeScreenState extends ConsumerState<OnlineModeScreen> {
  // Screen states
  bool _isCreateMode = false;
  bool _isJoinMode = false;
  bool _isWaitingForOpponent = false;
  bool _isOpponentJoined = false;  // Host: opponent joined, ready to start
  bool _isWaitingForHostToStart = false;  // Joiner: waiting for host
  bool _isLoading = false;
  bool _isStartingGame = false;

  // Form controllers
  final _nameController = TextEditingController(text: 'Player');
  final _codeController = TextEditingController();

  // Selections
  String _selectedCategory = 'animals';
  String _selectedGrid = '4x5';

  // Session data
  String? _inviteCode;
  String? _sessionId;
  String? _opponentName;
  OnlineSession? _currentSession;
  String? _errorMessage;

  StreamSubscription<OnlineSession>? _sessionSubscription;

  @override
  void initState() {
    super.initState();
    final user = SupabaseService.currentUser;
    if (user?.email != null) {
      _nameController.text = user!.email!.split('@').first;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _sessionSubscription?.cancel();
    if (_sessionId != null && _isWaitingForOpponent) {
      MultiplayerService.deleteSession(_sessionId!);
    }
    MultiplayerService.unsubscribeFromSession();
    super.dispose();
  }

  void _showCreateOptions() {
    setState(() {
      _isCreateMode = true;
      _isJoinMode = false;
      _errorMessage = null;
    });
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
    } else if (_isCreateMode || _isJoinMode) {
      setState(() {
        _isCreateMode = false;
        _isJoinMode = false;
        _errorMessage = null;
      });
    } else {
      Navigator.pop(context);
    }
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
  }

  Future<void> _joinGame() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter your name');
      return;
    }

    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty || code.length != 6) {
      setState(() => _errorMessage = 'Please enter a valid 6-character code');
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
  }

  void _navigateToGame(OnlineSession session) {
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
      _inviteCode = null;
      _sessionId = null;
    });
  }

  void _copyInviteCode() {
    if (_inviteCode != null) {
      Clipboard.setData(ClipboardData(text: _inviteCode!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Code copied!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _hostStartGame() async {
    if (_currentSession == null || _sessionId == null) return;

    setState(() => _isStartingGame = true);

    // Generate cards
    final cards = GameUtils.generateCards(
      gridSize: _selectedGrid,
      category: _selectedCategory,
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isWaitingForHostToStart
            ? _buildWaitingForHostScreen()
            : _isOpponentJoined
                ? _buildOpponentJoinedScreen()
                : _isWaitingForOpponent
                    ? _buildWaitingScreen()
                    : _isCreateMode
                        ? _buildCreateScreen()
                        : _isJoinMode
                            ? _buildJoinScreen()
                            : _buildMainScreen(),
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

          Text('Online Multiplayer', style: AppTypography.headline3),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Play with friends in real-time',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xxl),

          // Create Game option
          _buildOptionCard(
            icon: Icons.add_circle_outline,
            iconColor: AppColors.purple,
            title: 'Create Game',
            subtitle: 'Start a new game and invite a friend',
            onTap: _showCreateOptions,
          ),
          const SizedBox(height: AppSpacing.lg),

          // Join Game option
          _buildOptionCard(
            icon: Icons.login,
            iconColor: AppColors.teal,
            title: 'Join Game',
            subtitle: 'Enter a code to join your friend',
            onTap: _showJoinOptions,
          ),
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

          Text('Create Game', style: AppTypography.headline3),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Set up the game and invite a friend',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xl),

          if (_errorMessage != null) _buildErrorMessage(),

          // Name input
          _buildSectionTitle('Your Name'),
          const SizedBox(height: 8),
          _buildTextField(_nameController, 'Enter your name'),
          const SizedBox(height: AppSpacing.xl),

          // Category selection
          _buildSectionTitle('Category'),
          const SizedBox(height: 8),
          _buildCategorySelector(),
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

          Text('Join Game', style: AppTypography.headline3),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Enter the code from your friend',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
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
            style: AppTypography.body.copyWith(
              letterSpacing: 8,
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            decoration: InputDecoration(
              hintText: '------',
              hintStyle: AppTypography.body.copyWith(
                letterSpacing: 8,
                color: AppColors.textTertiary,
              ),
              counterText: '',
              filled: true,
              fillColor: AppColors.surface,
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
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(Icons.close, size: 24, color: AppColors.textPrimary),
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
            style: AppTypography.headline3,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Share this code with a friend',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),

          GestureDetector(
            onTap: _copyInviteCode,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.elevated),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _inviteCode ?? '',
                    style: AppTypography.headline2.copyWith(
                      letterSpacing: 8,
                      color: AppColors.purple,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.copy, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text('Tap to copy', style: AppTypography.labelSmall),

          const Spacer(),

          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton(
              onPressed: _cancelWaiting,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.elevated),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
              ),
              child: Text('Cancel', style: AppTypography.buttonSecondary),
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
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(Icons.close, size: 24, color: AppColors.textPrimary),
              ),
            ),
          ),
          const Spacer(),

          // Success icon
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.teal.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.person_add,
                size: 50,
                color: AppColors.teal,
              ),
            ),
          ),
          const SizedBox(height: 32),

          Text(
            'Opponent Joined!',
            style: AppTypography.headline3,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Opponent info card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.teal.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.teal.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person, color: AppColors.teal),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _opponentName ?? 'Player 2',
                      style: AppTypography.bodyLarge,
                    ),
                    Text(
                      'Ready to play',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.teal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Game settings summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(_selectedCategory, style: AppTypography.bodySmall),
                    Text('Category', style: AppTypography.labelSmall),
                  ],
                ),
                Container(width: 1, height: 30, color: AppColors.elevated),
                Column(
                  children: [
                    Text(_selectedGrid, style: AppTypography.bodySmall),
                    Text('Grid', style: AppTypography.labelSmall),
                  ],
                ),
              ],
            ),
          ),

          const Spacer(),

          // Start Game button
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
                side: const BorderSide(color: AppColors.elevated),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
              ),
              child: Text('Cancel', style: AppTypography.buttonSecondary),
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
                MultiplayerService.unsubscribeFromSession();
                Navigator.pop(context);
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(Icons.close, size: 24, color: AppColors.textPrimary),
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
            style: AppTypography.headline3,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Waiting for host to start the game...',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Game info
          if (_currentSession != null)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
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
                        style: AppTypography.body,
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
                            style: AppTypography.bodySmall,
                          ),
                          Text('Category', style: AppTypography.labelSmall),
                        ],
                      ),
                      Container(width: 1, height: 30, color: AppColors.elevated),
                      Column(
                        children: [
                          Text(
                            _currentSession!.gridSize ?? '4x5',
                            style: AppTypography.bodySmall,
                          ),
                          Text('Grid', style: AppTypography.labelSmall),
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
                MultiplayerService.unsubscribeFromSession();
                Navigator.pop(context);
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.elevated),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
              ),
              child: Text('Leave', style: AppTypography.buttonSecondary),
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
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Icon(Icons.arrow_back, size: 24, color: AppColors.textPrimary),
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
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.elevated),
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
                  Text(title, style: AppTypography.bodyLarge),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: AppTypography.label);
  }

  Widget _buildTextField(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      style: AppTypography.body,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _categories.map((cat) {
        final isSelected = _selectedCategory == cat['id'];
        return GestureDetector(
          onTap: () => setState(() => _selectedCategory = cat['id']),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.purple : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.purple : AppColors.elevated,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  cat['icon'],
                  size: 18,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  cat['name'],
                  style: AppTypography.bodySmall.copyWith(
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
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
                color: isSelected ? AppColors.purple : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppColors.purple : AppColors.elevated,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    grid['label'],
                    style: AppTypography.bodyLarge.copyWith(
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    grid['difficulty'],
                    style: AppTypography.labelSmall.copyWith(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.8)
                          : AppColors.textTertiary,
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
              style: AppTypography.bodySmall.copyWith(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
