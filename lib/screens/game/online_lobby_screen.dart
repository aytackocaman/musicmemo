import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../providers/user_provider.dart';
import '../../services/multiplayer_service.dart';
import '../../services/supabase_service.dart';
import 'online_game_screen.dart';

class OnlineLobbyScreen extends ConsumerStatefulWidget {
  final String category;
  final String gridSize;

  const OnlineLobbyScreen({
    super.key,
    required this.category,
    required this.gridSize,
  });

  @override
  ConsumerState<OnlineLobbyScreen> createState() => _OnlineLobbyScreenState();
}

class _OnlineLobbyScreenState extends ConsumerState<OnlineLobbyScreen> {
  final _nameController = TextEditingController(text: 'Player');
  final _codeController = TextEditingController();

  bool _isCreating = false;
  bool _isJoining = false;
  bool _isWaiting = false;
  String? _inviteCode;
  String? _sessionId;
  String? _errorMessage;

  StreamSubscription<OnlineSession>? _sessionSubscription;

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
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _sessionSubscription?.cancel();
    if (_sessionId != null && _isWaiting) {
      // Clean up session if leaving while waiting
      MultiplayerService.deleteSession(_sessionId!);
    }
    MultiplayerService.unsubscribeFromSession();
    super.dispose();
  }

  Future<void> _createGame() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter your name');
      return;
    }

    setState(() {
      _isCreating = true;
      _errorMessage = null;
    });

    final session = await MultiplayerService.createSession(
      category: widget.category,
      gridSize: widget.gridSize,
      playerName: _nameController.text.trim(),
    );

    if (session == null) {
      setState(() {
        _isCreating = false;
        _errorMessage = 'Failed to create game. Please try again.';
      });
      return;
    }

    setState(() {
      _isCreating = false;
      _isWaiting = true;
      _inviteCode = session.inviteCode;
      _sessionId = session.id;
    });

    // Subscribe to session updates to know when opponent joins
    _sessionSubscription = MultiplayerService.subscribeToSession(session.id).listen(
      (updatedSession) {
        if (updatedSession.hasOpponent && updatedSession.isPlaying) {
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

    if (_codeController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter the invite code');
      return;
    }

    setState(() {
      _isJoining = true;
      _errorMessage = null;
    });

    final session = await MultiplayerService.joinSession(
      inviteCode: _codeController.text.trim(),
      playerName: _nameController.text.trim(),
    );

    if (session == null) {
      setState(() {
        _isJoining = false;
        _errorMessage = 'Game not found or already started';
      });
      return;
    }

    _navigateToGame(session);
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
      _isWaiting = false;
      _inviteCode = null;
      _sessionId = null;
    });
  }

  void _copyInviteCode() {
    if (_inviteCode != null) {
      Clipboard.setData(ClipboardData(text: _inviteCode!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invite code copied!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: _isWaiting ? _buildWaitingScreen() : _buildLobbyScreen(),
        ),
      ),
    );
  }

  Widget _buildLobbyScreen() {
    return Column(children: [Expanded(child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button
          _buildBackButton(),
          const SizedBox(height: AppSpacing.xl),

          // Title
          Text(
            'Online Multiplayer',
            style: AppTypography.headline3(context),
          ),
          const SizedBox(height: AppSpacing.sm),

          Text(
            'Create a game or join with a code',
            style: AppTypography.body(context).copyWith(
              color: context.colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),

          // Name input
          Text(
            'Your Name',
            style: AppTypography.label(context),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            onTap: () {
              _nameController.selection = TextSelection(
                baseOffset: 0,
                extentOffset: _nameController.text.length,
              );
            },
            style: AppTypography.body(context),
            decoration: InputDecoration(
              hintText: 'Enter your name',
              filled: true,
              fillColor: context.colors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),

          // Error message
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
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
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          // Create game section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.purple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.purple.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.purple.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.add_circle_outline,
                        color: AppColors.purple,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create Game',
                            style: AppTypography.bodyLarge(context),
                          ),
                          Text(
                            'Get a code to share with a friend',
                            style: AppTypography.labelSmall(context),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isCreating ? null : _createGame,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.purple,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isCreating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text('Create Game', style: AppTypography.button),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // OR divider
          Row(
            children: [
              Expanded(child: Divider(color: context.colors.elevated)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'OR',
                  style: AppTypography.labelSmall(context),
                ),
              ),
              Expanded(child: Divider(color: context.colors.elevated)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Join game section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.teal.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.login,
                        color: AppColors.teal,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Join Game',
                            style: AppTypography.bodyLarge(context),
                          ),
                          Text(
                            'Enter a code from your friend',
                            style: AppTypography.labelSmall(context),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _codeController,
                  style: AppTypography.body(context).copyWith(
                    letterSpacing: 4,
                    fontWeight: FontWeight.bold,
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(
                    hintText: '000000',
                    counterText: '',
                    filled: true,
                    fillColor: context.colors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    )),
    // Join button — stays above keyboard
    Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: _isJoining ? null : _joinGame,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.teal,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isJoining
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text('Join Game', style: AppTypography.button),
        ),
      ),
    ),
    ]);
  }

  Widget _buildWaitingScreen() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Stack(
        children: [
          // Close button — top left
          Align(
            alignment: Alignment.topLeft,
            child: GestureDetector(
              onTap: _cancelWaiting,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(
                  Icons.close,
                  size: 24,
                  color: context.colors.textPrimary,
                ),
              ),
            ),
          ),

          // Cancel button — bottom
          Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
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
                child: Text(
                  'Cancel',
                  style: AppTypography.buttonSecondary(context),
                ),
              ),
            ),
          ),

          // Main content — truly centered
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                  'Share this code with a friend',
                  style: AppTypography.body(context).copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),

                // Invite code display
                GestureDetector(
                  onTap: _copyInviteCode,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.colors.elevated),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _inviteCode ?? '',
                          style: AppTypography.headline2(context).copyWith(
                            letterSpacing: 8,
                            color: AppColors.purple,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          Icons.copy,
                          color: context.colors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                Text(
                  'Tap to copy',
                  style: AppTypography.labelSmall(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
        child: Icon(
          Icons.arrow_back,
          size: 24,
          color: context.colors.textPrimary,
        ),
      ),
    );
  }
}
