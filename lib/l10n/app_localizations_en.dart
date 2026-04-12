// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Music Memo';

  @override
  String get matchTheSoundsToWin => 'Match the sounds to win!';

  @override
  String get playGame => 'Play Game';

  @override
  String get subscription => 'Subscription';

  @override
  String get statistics => 'Statistics';

  @override
  String get highScore => 'High Score';

  @override
  String get welcome => 'Welcome!';

  @override
  String get welcomeBack => 'Welcome Back';

  @override
  String get createAccountSubtitle =>
      'Create an account or sign in to start playing';

  @override
  String get signInSubtitle => 'Sign in to continue playing';

  @override
  String get byContinuing => 'By continuing, you agree to our';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get andSeparator => ' & ';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get pleaseEnterEmail => 'Please enter your email';

  @override
  String get pleaseEnterValidEmail => 'Please enter a valid email';

  @override
  String get pleaseEnterPassword => 'Please enter your password';

  @override
  String get passwordMinLength => 'Password must be at least 6 characters';

  @override
  String get pleaseWait => 'Please wait...';

  @override
  String get createAccount => 'Create Account';

  @override
  String get signIn => 'Sign In';

  @override
  String get signUp => 'Sign Up';

  @override
  String get forgotPassword => 'Forgot Password?';

  @override
  String get otherSignInOptions => 'Other sign-in options';

  @override
  String get signInWithGoogle => 'Sign in with Google';

  @override
  String get signInWithApple => 'Sign in with Apple';

  @override
  String get signInWithEmail => 'Sign in with Email';

  @override
  String get displayNameOptional => 'Display Name (optional)';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get enterName => 'Enter name';

  @override
  String get enterEmailToReset => 'Enter your email to reset password.';

  @override
  String get passwordResetSent => 'Password reset email sent!';

  @override
  String get selectGameMode => 'Select Game Mode';

  @override
  String get chooseHowToPlay => 'Choose how you want to play';

  @override
  String get singlePlayer => 'Single Player';

  @override
  String get singlePlayerDescription => 'Play solo and beat your high score';

  @override
  String get localMultiplayer => 'Local Multiplayer';

  @override
  String get localMultiplayerDescription => 'Play with a friend on this device';

  @override
  String get onlineMultiplayer => 'Online Multiplayer';

  @override
  String get onlineMultiplayerDescription => 'Challenge players worldwide';

  @override
  String get premiumOnly => 'Premium only';

  @override
  String get premium => 'Premium';

  @override
  String get premiumOn => 'Premium ON';

  @override
  String get premiumOff => 'Premium OFF';

  @override
  String freeGamesLeftToday(int remaining, int limit) {
    return '$remaining of $limit free games left today';
  }

  @override
  String get selectCategory => 'Select Category';

  @override
  String get whatKindOfSounds => 'What kind of sounds do you want to match?';

  @override
  String get music => 'Music';

  @override
  String get musicDescription => 'Match songs, beats and melodies';

  @override
  String get earTraining => 'Ear Training';

  @override
  String get earTrainingDescription => 'Intervals, chords, and scales';

  @override
  String get forKids => 'For Kids';

  @override
  String get forKidsDescription => 'Animals, toys, and fun sounds';

  @override
  String get funnyMemes => 'Funny Memes';

  @override
  String get funnyMemesDescription => 'Viral sounds and internet classics';

  @override
  String get soon => 'Soon';

  @override
  String get browseByFeel => 'Browse by Feel';

  @override
  String get collections => 'Collections';

  @override
  String get searchCollections => 'Search collections...';

  @override
  String noCollectionsMatch(String query) {
    return 'No collections match \"$query\"';
  }

  @override
  String get noCategoriesAvailable => 'No categories available';

  @override
  String trackCount(int count) {
    return '$count tracks';
  }

  @override
  String get pro => 'PRO';

  @override
  String searchTag(String tagLabel) {
    return 'Search $tagLabel...';
  }

  @override
  String get noResults => 'No results';

  @override
  String premiumCategoryMessage(String name) {
    return '$name is a Premium category. Upgrade to unlock it and all other premium collections.';
  }

  @override
  String get tagMood => 'Mood';

  @override
  String get tagGenre => 'Genre';

  @override
  String get tagMovement => 'Movement';

  @override
  String get tagTheme => 'Theme';

  @override
  String get selectGridSize => 'Select Grid Size';

  @override
  String get largerGridsMoreChallenging => 'Larger grids are more challenging';

  @override
  String get debug => 'Debug';

  @override
  String get easy => 'Easy';

  @override
  String get medium => 'Medium';

  @override
  String get hard => 'Hard';

  @override
  String get test => 'Test';

  @override
  String cardsPairs(int cards, int pairs) {
    return '$cards cards, $pairs pairs';
  }

  @override
  String get pleaseSelectGameModeAndCategory =>
      'Please select a game mode and category';

  @override
  String get preparingGame => 'Preparing Game';

  @override
  String get fetchingSoundList => 'Fetching sound list...';

  @override
  String get downloadingSounds => 'Getting ready...';

  @override
  String get failedToLoadSounds => 'Failed to load sounds';

  @override
  String get retry => 'Retry';

  @override
  String get goBack => 'Go Back';

  @override
  String get playerSetup => 'Player Setup';

  @override
  String get enterNamesAndPickColors => 'Enter names and pick colors';

  @override
  String get vs => 'VS';

  @override
  String get startGame => 'Start Game';

  @override
  String playerNumber(int number) {
    return 'Player $number';
  }

  @override
  String get chooseColor => 'Choose color';

  @override
  String get score => 'Score';

  @override
  String get moves => 'Moves';

  @override
  String get time => 'Time';

  @override
  String get pairs => 'Pairs';

  @override
  String get gamePaused => 'Game Paused';

  @override
  String get tapToResume => 'Tap anywhere to resume';

  @override
  String get resume => 'Resume';

  @override
  String get quitGame => 'Quit Game';

  @override
  String get goHomeTitle => 'Go Home?';

  @override
  String get progressWillBeLost => 'Your progress will be lost.';

  @override
  String get goHome => 'Go Home';

  @override
  String get yourTurn => 'Your Turn';

  @override
  String get opponentsTurn => 'Opponent\'s Turn';

  @override
  String get itsATie => 'It\'s a Tie!';

  @override
  String playerWins(String name) {
    return '$name Wins!';
  }

  @override
  String get greatMatchBothPlayers => 'Great match, both players!';

  @override
  String get congratulations => 'Congratulations!';

  @override
  String get playAgain => 'Play Again';

  @override
  String get changeCategory => 'Change Category';

  @override
  String get upgradeToPremium => 'Upgrade to Premium';

  @override
  String get home => 'Home';

  @override
  String freeGamesLeftCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count free games left today',
      one: '1 free game left today',
    );
    return '$_temp0';
  }

  @override
  String get noFreeGamesLeft => 'No free games left. Resets at 3:00 AM';

  @override
  String get onlineMultiplayerTitle => 'Online Multiplayer';

  @override
  String get createOrJoinGame => 'Create a game or join with a code';

  @override
  String get yourName => 'Your Name';

  @override
  String get enterYourName => 'Enter your name';

  @override
  String get createGame => 'Create Game';

  @override
  String get getCodeToShare => 'Get a code to share with a friend';

  @override
  String get or => 'OR';

  @override
  String get joinGame => 'Join Game';

  @override
  String get enterCodeFromFriend => 'Enter a code from your friend';

  @override
  String get codePlaceholder => '000000';

  @override
  String get waitingForOpponent => 'Waiting for opponent...';

  @override
  String get shareCodeWithFriend => 'Share this code with a friend';

  @override
  String get tapToCopy => 'Tap to copy';

  @override
  String get pleaseEnterYourName => 'Please enter your name';

  @override
  String get pleaseEnterInviteCode => 'Please enter the invite code';

  @override
  String get gameNotFound => 'Game not found or already started';

  @override
  String get inviteCodeCopied => 'Invite code copied!';

  @override
  String get failedToCreateGame => 'Failed to create game. Please try again.';

  @override
  String get pleaseEnterValidCode => 'Please enter a valid 6-digit code';

  @override
  String get opponentLeftTheGame => 'Opponent left the game';

  @override
  String get settingUpGame => 'Setting up game...';

  @override
  String get waitingForHost => 'Waiting for host...';

  @override
  String get live => 'LIVE';

  @override
  String get reconnecting => 'Reconnecting...';

  @override
  String get offline => 'Offline';

  @override
  String get opponent => 'Opponent';

  @override
  String get forfeitMessage => 'You will forfeit this game if you leave.';

  @override
  String get opponentLeftTitle => 'Opponent Left';

  @override
  String get opponentLeftMessage => 'Your opponent has left the game. You win!';

  @override
  String get opponentTimedOut => 'Opponent Timed Out';

  @override
  String get opponentLeftTheRoom => 'Opponent left the room';

  @override
  String get opponentDeclinedRematch => 'Opponent declined the rematch';

  @override
  String get youWin => 'You Win!';

  @override
  String get youLost => 'You Lost';

  @override
  String get greatMatch => 'Great match!';

  @override
  String get betterLuckNextTime => 'Better luck next time!';

  @override
  String get rematch => 'Rematch';

  @override
  String get findNewOpponent => 'Find New Opponent';

  @override
  String get waitingForOpponentEllipsis => 'Waiting for opponent...';

  @override
  String get cancel => 'Cancel';

  @override
  String get acceptRematch => 'Accept Rematch!';

  @override
  String get decline => 'Decline';

  @override
  String get startingRematch => 'Starting rematch...';

  @override
  String get statisticsTitle => 'Statistics';

  @override
  String get byGameMode => 'By Game Mode';

  @override
  String get overallStats => 'Overall Stats';

  @override
  String get games => 'Games';

  @override
  String get wins => 'Wins';

  @override
  String get winRate => 'Win Rate';

  @override
  String get twoPlayerLocal => 'Two Player Local';

  @override
  String get twoPlayerOnline => 'Two Player Online';

  @override
  String gamesWinRate(int games, String winRate) {
    return '$games games • $winRate% win rate';
  }

  @override
  String get subscriptionTitle => 'Subscription';

  @override
  String get currentPlan => 'Current Plan';

  @override
  String get free => 'Free';

  @override
  String get active => 'Active';

  @override
  String get unlimitedGames => 'Unlimited games';

  @override
  String get singlePlayerToday => 'Single player today';

  @override
  String get localMpToday => 'Local MP today';

  @override
  String get monthly => 'Monthly';

  @override
  String get monthlyPrice => '\$4.99';

  @override
  String get perMonth => '/month';

  @override
  String get yearly => 'Yearly';

  @override
  String get yearlyPrice => '\$35.99';

  @override
  String get perYear => '/year';

  @override
  String get save40 => 'SAVE 40%';

  @override
  String get unlimitedSinglePlayerGames => 'Unlimited single player games';

  @override
  String get unlimitedLocalMultiplayerGames =>
      'Unlimited local multiplayer games';

  @override
  String get accessOnlineMultiplayer => 'Access to online multiplayer';

  @override
  String get trialEnded => 'Your Free Trial Has Ended';

  @override
  String get premiumFeature => 'Premium Feature';

  @override
  String get reachedYourLimit => 'You\'ve Reached Your Limit!';

  @override
  String get subscribeMessage =>
      'Subscribe to keep enjoying unlimited games and all premium features';

  @override
  String get onlineRequiresPremium =>
      'Online multiplayer requires a Premium subscription';

  @override
  String get upgradeToPremiumToKeepPlaying =>
      'Upgrade to Premium to keep playing';

  @override
  String get unlimitedSinglePlayer => 'Unlimited single player games';

  @override
  String get unlimitedLocalMultiplayer => 'Unlimited local multiplayer';

  @override
  String get onlineMultiplayerAccess => 'Online multiplayer access';

  @override
  String get adFreeExperience => 'Ad-free experience';

  @override
  String get getYearly => 'Get Yearly – \$35.99/year';

  @override
  String get getMonthly => 'Get Monthly – \$4.99/month';

  @override
  String get restorePurchase => 'Restore Purchase';

  @override
  String get cancelAnytime => 'Cancel anytime. Terms & Privacy apply.';

  @override
  String get perfect => 'Perfect!';

  @override
  String get wellDone => 'Well Done!';

  @override
  String get niceTry => 'Nice Try!';

  @override
  String get settings => 'Settings';

  @override
  String get accentColor => 'Card Color';

  @override
  String get blue => 'Blue';

  @override
  String get purple => 'Purple';

  @override
  String get red => 'Red';

  @override
  String get appearance => 'Appearance';

  @override
  String get gameplay => 'Gameplay';

  @override
  String get hapticFeedback => 'Haptic Feedback';

  @override
  String get account => 'Account';

  @override
  String get displayName => 'Display Name';

  @override
  String get signOut => 'Sign Out';

  @override
  String get signOutTitle => 'Sign Out';

  @override
  String get signOutConfirm => 'Are you sure you want to sign out?';

  @override
  String get manageSubscription => 'Manage Subscription';

  @override
  String get language => 'Language';

  @override
  String get comingSoon => 'Coming Soon';

  @override
  String get about => 'About';

  @override
  String get version => 'Version';

  @override
  String get nameUpdated => 'Name updated';

  @override
  String get failedToUpdateName => 'Failed to update name';

  @override
  String get noActivePurchasesFound => 'No active purchases found.';

  @override
  String get purchaseSuccessful =>
      'You\'re now Premium! Enjoy unlimited games.';

  @override
  String get purchaseFailed => 'Something went wrong. Please try again.';

  @override
  String get purchaseRestored => 'Your subscription has been restored!';

  @override
  String get loadingPurchases => 'Loading...';

  @override
  String get system => 'System';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get yourNameHint => 'Your name';

  @override
  String get save => 'Save';

  @override
  String get confirm => 'Confirm';

  @override
  String get cardTiming => 'Card Timing';

  @override
  String get delayAfterFirstCard => 'Delay after 1st card';

  @override
  String get delayAfterMismatch => 'Delay after mismatch';

  @override
  String get delayAfterFirstCardDescription =>
      'How long you must wait after tapping the first card before you can tap a second. The sound keeps playing regardless — this only controls when your next tap is accepted.';

  @override
  String get delayAfterMismatchDescription =>
      'Minimum time you must wait after a mismatch before tapping again. The unmatched cards stay visible and flip back on their own at 2.1 seconds if you haven\'t tapped yet.';

  @override
  String get hapticFeedbackInfoDescription =>
      'Short vibrations on card flips, matches, mismatches, and turn changes. Lets you feel the rhythm of the game without looking. Toggle it off below if you prefer silence or want to save a bit of battery.';

  @override
  String get gotIt => 'Got it';

  @override
  String get authSignUpFailed => 'Sign up failed. Please try again.';

  @override
  String get authUnexpectedError => 'An unexpected error occurred.';

  @override
  String get authSignInFailed => 'Sign in failed. Please try again.';

  @override
  String get authSignInCancelled => 'Sign-in cancelled.';

  @override
  String get authGoogleNoIdToken => 'Google Sign-In failed: no ID token.';

  @override
  String get authGoogleFailed => 'Google Sign-In failed. Please try again.';

  @override
  String authGoogleError(String error) {
    return 'Google Sign-In error: $error';
  }

  @override
  String get authAppleNoIdentityToken =>
      'Apple Sign-In failed: no identity token.';

  @override
  String get authAppleFailed => 'Apple Sign-In failed. Please try again.';

  @override
  String authAppleError(String error) {
    return 'Apple Sign-In error: $error';
  }

  @override
  String get authInvalidCredentials => 'Invalid email or password.';

  @override
  String get authEmailNotConfirmed =>
      'Please verify your email before signing in.';

  @override
  String get authUserAlreadyRegistered =>
      'An account with this email already exists.';

  @override
  String get authPasswordTooShort => 'Password must be at least 6 characters.';

  @override
  String get authInvalidEmail => 'Please enter a valid email address.';

  @override
  String get findOpponent => 'Find Opponent';

  @override
  String get findOpponentDescription => 'Match with a random player';

  @override
  String get searching => 'Searching...';

  @override
  String get opponentFound => 'Opponent found!';

  @override
  String get cancelSearch => 'Cancel Search';

  @override
  String get inviteFriend => 'Invite a Friend';

  @override
  String get inviteFriendDescription => 'Share a code with someone';

  @override
  String get joinWithCode => 'Join with Code';

  @override
  String get joinWithCodeDescription => 'Enter a friend\'s invite code';

  @override
  String get lobbyWaitingForOpponent => 'Waiting for opponent...';

  @override
  String get lobbyShareCode => 'Share this code with a friend';

  @override
  String get lobbyTapToCopy => 'Tap to copy';

  @override
  String get playWithFriendsRealtime => 'Play with friends in real-time';

  @override
  String get createPrivateGame => 'Create Private Game';

  @override
  String get startNewGameInviteFriend => 'Start a new game and invite a friend';

  @override
  String get joinPrivateGame => 'Join Private Game';

  @override
  String get enterCodeToJoinFriend => 'Enter a code to join your friend';

  @override
  String get searchingForPlayers => 'Searching for available players...';

  @override
  String get noPlayersFoundCreateGame =>
      'No players found. Create a game and wait for someone to join!';

  @override
  String get lookingForOpponents => 'Looking for opponents...';

  @override
  String get gridSizeLabel => 'Grid Size';

  @override
  String get createAndWaitForOpponent => 'Create & Wait for Opponent';

  @override
  String get searchAgain => 'Search Again';

  @override
  String get setupGameInviteFriend => 'Set up the game and invite a friend';

  @override
  String get inviteCodeLabel => 'Invite Code';

  @override
  String get someoneWillJoinSoon => 'Someone will join your game soon';

  @override
  String get copy => 'Copy';

  @override
  String get share => 'Share';

  @override
  String get publicGame => 'Public Game';

  @override
  String get anyoneCanJoinThisGame => 'Anyone can find and join this game';

  @override
  String get opponentJoinedTitle => 'Opponent Joined!';

  @override
  String get readyToPlay => 'Ready to play';

  @override
  String get youFallbackName => 'You';

  @override
  String get waitingForHostToStart => 'Waiting for Host to Start the Game!';

  @override
  String get joinedSuccessfully => 'You\'ve joined successfully';

  @override
  String get leave => 'Leave';

  @override
  String get hostCancelledGame => 'Host cancelled the game';

  @override
  String get failedToStartGame => 'Failed to start game. Please try again.';

  @override
  String get codeCopied => 'Code copied!';

  @override
  String get gameNotFoundCheckCode =>
      'Game not found or already started. Check the code and try again.';

  @override
  String get connectionLost => 'Connection lost';

  @override
  String get opponentTimedOutMessage =>
      'Your opponent hasn\'t made a move in 60 seconds. The game has been ended.';

  @override
  String get enterTheCodeFromFriend => 'Enter the code from your friend';

  @override
  String get dailyChallenge => 'Daily Challenge';

  @override
  String get dailyChallengeSubtitle => 'Same puzzle for everyone, every day';

  @override
  String get playNow => 'Play Now';

  @override
  String get alreadyPlayed => 'Already Played';

  @override
  String get viewLeaderboard => 'View Leaderboard';

  @override
  String get leaderboard => 'Leaderboard';

  @override
  String get rank => 'Rank';

  @override
  String get yourRank => 'Your Rank';

  @override
  String rankOutOfTotal(int rank, int total) {
    return '#$rank of $total';
  }

  @override
  String get noScoresYet => 'No scores yet. Be the first!';

  @override
  String get giveUpTitle => 'Give Up?';

  @override
  String get giveUpMessage =>
      'Your attempt will be used and your current score will be saved.';

  @override
  String get giveUp => 'Give Up';

  @override
  String get challengeComplete => 'Challenge Complete!';

  @override
  String get upgradeToPlay => 'Upgrade to Play';

  @override
  String get turkce => 'Türkçe';

  @override
  String get english => 'English';

  @override
  String get languageSystem => 'System';
}
