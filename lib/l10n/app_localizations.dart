import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('tr'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Music Memo'**
  String get appTitle;

  /// No description provided for @matchTheSoundsToWin.
  ///
  /// In en, this message translates to:
  /// **'Match the sounds to win!'**
  String get matchTheSoundsToWin;

  /// No description provided for @playGame.
  ///
  /// In en, this message translates to:
  /// **'Play Game'**
  String get playGame;

  /// No description provided for @subscription.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get subscription;

  /// No description provided for @statistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statistics;

  /// No description provided for @highScore.
  ///
  /// In en, this message translates to:
  /// **'High Score'**
  String get highScore;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome!'**
  String get welcome;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get welcomeBack;

  /// No description provided for @createAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create an account or sign in to start playing'**
  String get createAccountSubtitle;

  /// No description provided for @signInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue playing'**
  String get signInSubtitle;

  /// No description provided for @byContinuing.
  ///
  /// In en, this message translates to:
  /// **'By continuing, you agree to our'**
  String get byContinuing;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @andSeparator.
  ///
  /// In en, this message translates to:
  /// **' & '**
  String get andSeparator;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @pleaseEnterEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get pleaseEnterEmail;

  /// No description provided for @pleaseEnterValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email'**
  String get pleaseEnterValidEmail;

  /// No description provided for @pleaseEnterPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password'**
  String get pleaseEnterPassword;

  /// No description provided for @passwordMinLength.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get passwordMinLength;

  /// No description provided for @pleaseWait.
  ///
  /// In en, this message translates to:
  /// **'Please wait...'**
  String get pleaseWait;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// No description provided for @otherSignInOptions.
  ///
  /// In en, this message translates to:
  /// **'Other sign-in options'**
  String get otherSignInOptions;

  /// No description provided for @signInWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get signInWithGoogle;

  /// No description provided for @signInWithApple.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Apple'**
  String get signInWithApple;

  /// No description provided for @signInWithEmail.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Email'**
  String get signInWithEmail;

  /// No description provided for @displayNameOptional.
  ///
  /// In en, this message translates to:
  /// **'Display Name (optional)'**
  String get displayNameOptional;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @enterName.
  ///
  /// In en, this message translates to:
  /// **'Enter name'**
  String get enterName;

  /// No description provided for @enterEmailToReset.
  ///
  /// In en, this message translates to:
  /// **'Enter your email to reset password.'**
  String get enterEmailToReset;

  /// No description provided for @passwordResetSent.
  ///
  /// In en, this message translates to:
  /// **'Password reset email sent!'**
  String get passwordResetSent;

  /// No description provided for @selectGameMode.
  ///
  /// In en, this message translates to:
  /// **'Select Game Mode'**
  String get selectGameMode;

  /// No description provided for @chooseHowToPlay.
  ///
  /// In en, this message translates to:
  /// **'Choose how you want to play'**
  String get chooseHowToPlay;

  /// No description provided for @singlePlayer.
  ///
  /// In en, this message translates to:
  /// **'Single Player'**
  String get singlePlayer;

  /// No description provided for @singlePlayerDescription.
  ///
  /// In en, this message translates to:
  /// **'Play solo and beat your high score'**
  String get singlePlayerDescription;

  /// No description provided for @localMultiplayer.
  ///
  /// In en, this message translates to:
  /// **'Local Multiplayer'**
  String get localMultiplayer;

  /// No description provided for @localMultiplayerDescription.
  ///
  /// In en, this message translates to:
  /// **'Play with a friend on this device'**
  String get localMultiplayerDescription;

  /// No description provided for @onlineMultiplayer.
  ///
  /// In en, this message translates to:
  /// **'Online Multiplayer'**
  String get onlineMultiplayer;

  /// No description provided for @onlineMultiplayerDescription.
  ///
  /// In en, this message translates to:
  /// **'Challenge players worldwide'**
  String get onlineMultiplayerDescription;

  /// No description provided for @premiumOnly.
  ///
  /// In en, this message translates to:
  /// **'Premium only'**
  String get premiumOnly;

  /// No description provided for @premium.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get premium;

  /// No description provided for @premiumOn.
  ///
  /// In en, this message translates to:
  /// **'Premium ON'**
  String get premiumOn;

  /// No description provided for @premiumOff.
  ///
  /// In en, this message translates to:
  /// **'Premium OFF'**
  String get premiumOff;

  /// No description provided for @freeGamesLeftToday.
  ///
  /// In en, this message translates to:
  /// **'{remaining} of {limit} free games left today'**
  String freeGamesLeftToday(int remaining, int limit);

  /// No description provided for @selectCategory.
  ///
  /// In en, this message translates to:
  /// **'Select Category'**
  String get selectCategory;

  /// No description provided for @whatKindOfSounds.
  ///
  /// In en, this message translates to:
  /// **'What kind of sounds do you want to match?'**
  String get whatKindOfSounds;

  /// No description provided for @music.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get music;

  /// No description provided for @musicDescription.
  ///
  /// In en, this message translates to:
  /// **'Match songs, beats and melodies'**
  String get musicDescription;

  /// No description provided for @earTraining.
  ///
  /// In en, this message translates to:
  /// **'Ear Training'**
  String get earTraining;

  /// No description provided for @earTrainingDescription.
  ///
  /// In en, this message translates to:
  /// **'Intervals, chords, and scales'**
  String get earTrainingDescription;

  /// No description provided for @forKids.
  ///
  /// In en, this message translates to:
  /// **'For Kids'**
  String get forKids;

  /// No description provided for @forKidsDescription.
  ///
  /// In en, this message translates to:
  /// **'Animals, toys, and fun sounds'**
  String get forKidsDescription;

  /// No description provided for @funnyMemes.
  ///
  /// In en, this message translates to:
  /// **'Funny Memes'**
  String get funnyMemes;

  /// No description provided for @funnyMemesDescription.
  ///
  /// In en, this message translates to:
  /// **'Viral sounds and internet classics'**
  String get funnyMemesDescription;

  /// No description provided for @soon.
  ///
  /// In en, this message translates to:
  /// **'Soon'**
  String get soon;

  /// No description provided for @browseByFeel.
  ///
  /// In en, this message translates to:
  /// **'Browse by Feel'**
  String get browseByFeel;

  /// No description provided for @collections.
  ///
  /// In en, this message translates to:
  /// **'Collections'**
  String get collections;

  /// No description provided for @searchCollections.
  ///
  /// In en, this message translates to:
  /// **'Search collections...'**
  String get searchCollections;

  /// No description provided for @noCollectionsMatch.
  ///
  /// In en, this message translates to:
  /// **'No collections match \"{query}\"'**
  String noCollectionsMatch(String query);

  /// No description provided for @noCategoriesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No categories available'**
  String get noCategoriesAvailable;

  /// No description provided for @trackCount.
  ///
  /// In en, this message translates to:
  /// **'{count} tracks'**
  String trackCount(int count);

  /// No description provided for @pro.
  ///
  /// In en, this message translates to:
  /// **'PRO'**
  String get pro;

  /// No description provided for @searchTag.
  ///
  /// In en, this message translates to:
  /// **'Search {tagLabel}...'**
  String searchTag(String tagLabel);

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get noResults;

  /// No description provided for @premiumCategoryMessage.
  ///
  /// In en, this message translates to:
  /// **'{name} is a Premium category. Upgrade to unlock it and all other premium collections.'**
  String premiumCategoryMessage(String name);

  /// No description provided for @tagMood.
  ///
  /// In en, this message translates to:
  /// **'Mood'**
  String get tagMood;

  /// No description provided for @tagGenre.
  ///
  /// In en, this message translates to:
  /// **'Genre'**
  String get tagGenre;

  /// No description provided for @tagMovement.
  ///
  /// In en, this message translates to:
  /// **'Movement'**
  String get tagMovement;

  /// No description provided for @tagTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get tagTheme;

  /// No description provided for @selectGridSize.
  ///
  /// In en, this message translates to:
  /// **'Select Grid Size'**
  String get selectGridSize;

  /// No description provided for @largerGridsMoreChallenging.
  ///
  /// In en, this message translates to:
  /// **'Larger grids are more challenging'**
  String get largerGridsMoreChallenging;

  /// No description provided for @debug.
  ///
  /// In en, this message translates to:
  /// **'Debug'**
  String get debug;

  /// No description provided for @easy.
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get easy;

  /// No description provided for @medium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get medium;

  /// No description provided for @hard.
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get hard;

  /// No description provided for @test.
  ///
  /// In en, this message translates to:
  /// **'Test'**
  String get test;

  /// No description provided for @cardsPairs.
  ///
  /// In en, this message translates to:
  /// **'{cards} cards, {pairs} pairs'**
  String cardsPairs(int cards, int pairs);

  /// No description provided for @pleaseSelectGameModeAndCategory.
  ///
  /// In en, this message translates to:
  /// **'Please select a game mode and category'**
  String get pleaseSelectGameModeAndCategory;

  /// No description provided for @preparingGame.
  ///
  /// In en, this message translates to:
  /// **'Preparing Game'**
  String get preparingGame;

  /// No description provided for @fetchingSoundList.
  ///
  /// In en, this message translates to:
  /// **'Fetching sound list...'**
  String get fetchingSoundList;

  /// No description provided for @downloadingSounds.
  ///
  /// In en, this message translates to:
  /// **'Downloading sounds...'**
  String get downloadingSounds;

  /// No description provided for @downloadingSoundsProgress.
  ///
  /// In en, this message translates to:
  /// **'Downloading sounds ({completed}/{total})'**
  String downloadingSoundsProgress(int completed, int total);

  /// No description provided for @failedToLoadSounds.
  ///
  /// In en, this message translates to:
  /// **'Failed to load sounds'**
  String get failedToLoadSounds;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @goBack.
  ///
  /// In en, this message translates to:
  /// **'Go Back'**
  String get goBack;

  /// No description provided for @playerSetup.
  ///
  /// In en, this message translates to:
  /// **'Player Setup'**
  String get playerSetup;

  /// No description provided for @enterNamesAndPickColors.
  ///
  /// In en, this message translates to:
  /// **'Enter names and pick colors'**
  String get enterNamesAndPickColors;

  /// No description provided for @vs.
  ///
  /// In en, this message translates to:
  /// **'VS'**
  String get vs;

  /// No description provided for @startGame.
  ///
  /// In en, this message translates to:
  /// **'Start Game'**
  String get startGame;

  /// No description provided for @playerNumber.
  ///
  /// In en, this message translates to:
  /// **'Player {number}'**
  String playerNumber(int number);

  /// No description provided for @chooseColor.
  ///
  /// In en, this message translates to:
  /// **'Choose color'**
  String get chooseColor;

  /// No description provided for @score.
  ///
  /// In en, this message translates to:
  /// **'Score'**
  String get score;

  /// No description provided for @moves.
  ///
  /// In en, this message translates to:
  /// **'Moves'**
  String get moves;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @pairs.
  ///
  /// In en, this message translates to:
  /// **'Pairs'**
  String get pairs;

  /// No description provided for @gamePaused.
  ///
  /// In en, this message translates to:
  /// **'Game Paused'**
  String get gamePaused;

  /// No description provided for @tapToResume.
  ///
  /// In en, this message translates to:
  /// **'Tap anywhere to resume'**
  String get tapToResume;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @quitGame.
  ///
  /// In en, this message translates to:
  /// **'Quit Game'**
  String get quitGame;

  /// No description provided for @goHomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Go Home?'**
  String get goHomeTitle;

  /// No description provided for @progressWillBeLost.
  ///
  /// In en, this message translates to:
  /// **'Your progress will be lost.'**
  String get progressWillBeLost;

  /// No description provided for @goHome.
  ///
  /// In en, this message translates to:
  /// **'Go Home'**
  String get goHome;

  /// No description provided for @yourTurn.
  ///
  /// In en, this message translates to:
  /// **'Your Turn'**
  String get yourTurn;

  /// No description provided for @opponentsTurn.
  ///
  /// In en, this message translates to:
  /// **'Opponent\'s Turn'**
  String get opponentsTurn;

  /// No description provided for @itsATie.
  ///
  /// In en, this message translates to:
  /// **'It\'s a Tie!'**
  String get itsATie;

  /// No description provided for @playerWins.
  ///
  /// In en, this message translates to:
  /// **'{name} Wins!'**
  String playerWins(String name);

  /// No description provided for @greatMatchBothPlayers.
  ///
  /// In en, this message translates to:
  /// **'Great match, both players!'**
  String get greatMatchBothPlayers;

  /// No description provided for @congratulations.
  ///
  /// In en, this message translates to:
  /// **'Congratulations!'**
  String get congratulations;

  /// No description provided for @playAgain.
  ///
  /// In en, this message translates to:
  /// **'Play Again'**
  String get playAgain;

  /// No description provided for @changeCategory.
  ///
  /// In en, this message translates to:
  /// **'Change Category'**
  String get changeCategory;

  /// No description provided for @upgradeToPremium.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Premium'**
  String get upgradeToPremium;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @freeGamesLeftCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 free game left today} other{{count} free games left today}}'**
  String freeGamesLeftCount(int count);

  /// No description provided for @noFreeGamesLeft.
  ///
  /// In en, this message translates to:
  /// **'No free games left. Resets at 3:00 AM'**
  String get noFreeGamesLeft;

  /// No description provided for @onlineMultiplayerTitle.
  ///
  /// In en, this message translates to:
  /// **'Online Multiplayer'**
  String get onlineMultiplayerTitle;

  /// No description provided for @createOrJoinGame.
  ///
  /// In en, this message translates to:
  /// **'Create a game or join with a code'**
  String get createOrJoinGame;

  /// No description provided for @yourName.
  ///
  /// In en, this message translates to:
  /// **'Your Name'**
  String get yourName;

  /// No description provided for @enterYourName.
  ///
  /// In en, this message translates to:
  /// **'Enter your name'**
  String get enterYourName;

  /// No description provided for @createGame.
  ///
  /// In en, this message translates to:
  /// **'Create Game'**
  String get createGame;

  /// No description provided for @getCodeToShare.
  ///
  /// In en, this message translates to:
  /// **'Get a code to share with a friend'**
  String get getCodeToShare;

  /// No description provided for @or.
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get or;

  /// No description provided for @joinGame.
  ///
  /// In en, this message translates to:
  /// **'Join Game'**
  String get joinGame;

  /// No description provided for @enterCodeFromFriend.
  ///
  /// In en, this message translates to:
  /// **'Enter a code from your friend'**
  String get enterCodeFromFriend;

  /// No description provided for @codePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'000000'**
  String get codePlaceholder;

  /// No description provided for @waitingForOpponent.
  ///
  /// In en, this message translates to:
  /// **'Waiting for opponent...'**
  String get waitingForOpponent;

  /// No description provided for @shareCodeWithFriend.
  ///
  /// In en, this message translates to:
  /// **'Share this code with a friend'**
  String get shareCodeWithFriend;

  /// No description provided for @tapToCopy.
  ///
  /// In en, this message translates to:
  /// **'Tap to copy'**
  String get tapToCopy;

  /// No description provided for @pleaseEnterYourName.
  ///
  /// In en, this message translates to:
  /// **'Please enter your name'**
  String get pleaseEnterYourName;

  /// No description provided for @pleaseEnterInviteCode.
  ///
  /// In en, this message translates to:
  /// **'Please enter the invite code'**
  String get pleaseEnterInviteCode;

  /// No description provided for @gameNotFound.
  ///
  /// In en, this message translates to:
  /// **'Game not found or already started'**
  String get gameNotFound;

  /// No description provided for @inviteCodeCopied.
  ///
  /// In en, this message translates to:
  /// **'Invite code copied!'**
  String get inviteCodeCopied;

  /// No description provided for @failedToCreateGame.
  ///
  /// In en, this message translates to:
  /// **'Failed to create game. Please try again.'**
  String get failedToCreateGame;

  /// No description provided for @pleaseEnterValidCode.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid 6-digit code'**
  String get pleaseEnterValidCode;

  /// No description provided for @opponentLeftTheGame.
  ///
  /// In en, this message translates to:
  /// **'Opponent left the game'**
  String get opponentLeftTheGame;

  /// No description provided for @settingUpGame.
  ///
  /// In en, this message translates to:
  /// **'Setting up game...'**
  String get settingUpGame;

  /// No description provided for @waitingForHost.
  ///
  /// In en, this message translates to:
  /// **'Waiting for host...'**
  String get waitingForHost;

  /// No description provided for @live.
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get live;

  /// No description provided for @reconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting...'**
  String get reconnecting;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// No description provided for @opponent.
  ///
  /// In en, this message translates to:
  /// **'Opponent'**
  String get opponent;

  /// No description provided for @forfeitMessage.
  ///
  /// In en, this message translates to:
  /// **'You will forfeit this game if you leave.'**
  String get forfeitMessage;

  /// No description provided for @opponentLeftTitle.
  ///
  /// In en, this message translates to:
  /// **'Opponent Left'**
  String get opponentLeftTitle;

  /// No description provided for @opponentLeftMessage.
  ///
  /// In en, this message translates to:
  /// **'Your opponent has left the game. You win!'**
  String get opponentLeftMessage;

  /// No description provided for @opponentTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Opponent Timed Out'**
  String get opponentTimedOut;

  /// No description provided for @opponentLeftTheRoom.
  ///
  /// In en, this message translates to:
  /// **'Opponent left the room'**
  String get opponentLeftTheRoom;

  /// No description provided for @opponentDeclinedRematch.
  ///
  /// In en, this message translates to:
  /// **'Opponent declined the rematch'**
  String get opponentDeclinedRematch;

  /// No description provided for @youWin.
  ///
  /// In en, this message translates to:
  /// **'You Win!'**
  String get youWin;

  /// No description provided for @youLost.
  ///
  /// In en, this message translates to:
  /// **'You Lost'**
  String get youLost;

  /// No description provided for @greatMatch.
  ///
  /// In en, this message translates to:
  /// **'Great match!'**
  String get greatMatch;

  /// No description provided for @betterLuckNextTime.
  ///
  /// In en, this message translates to:
  /// **'Better luck next time!'**
  String get betterLuckNextTime;

  /// No description provided for @rematch.
  ///
  /// In en, this message translates to:
  /// **'Rematch'**
  String get rematch;

  /// No description provided for @findNewOpponent.
  ///
  /// In en, this message translates to:
  /// **'Find New Opponent'**
  String get findNewOpponent;

  /// No description provided for @waitingForOpponentEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Waiting for opponent...'**
  String get waitingForOpponentEllipsis;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @acceptRematch.
  ///
  /// In en, this message translates to:
  /// **'Accept Rematch!'**
  String get acceptRematch;

  /// No description provided for @decline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get decline;

  /// No description provided for @startingRematch.
  ///
  /// In en, this message translates to:
  /// **'Starting rematch...'**
  String get startingRematch;

  /// No description provided for @statisticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statisticsTitle;

  /// No description provided for @byGameMode.
  ///
  /// In en, this message translates to:
  /// **'By Game Mode'**
  String get byGameMode;

  /// No description provided for @overallStats.
  ///
  /// In en, this message translates to:
  /// **'Overall Stats'**
  String get overallStats;

  /// No description provided for @games.
  ///
  /// In en, this message translates to:
  /// **'Games'**
  String get games;

  /// No description provided for @wins.
  ///
  /// In en, this message translates to:
  /// **'Wins'**
  String get wins;

  /// No description provided for @winRate.
  ///
  /// In en, this message translates to:
  /// **'Win Rate'**
  String get winRate;

  /// No description provided for @twoPlayerLocal.
  ///
  /// In en, this message translates to:
  /// **'Two Player Local'**
  String get twoPlayerLocal;

  /// No description provided for @twoPlayerOnline.
  ///
  /// In en, this message translates to:
  /// **'Two Player Online'**
  String get twoPlayerOnline;

  /// No description provided for @gamesWinRate.
  ///
  /// In en, this message translates to:
  /// **'{games} games • {winRate}% win rate'**
  String gamesWinRate(int games, String winRate);

  /// No description provided for @subscriptionTitle.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get subscriptionTitle;

  /// No description provided for @currentPlan.
  ///
  /// In en, this message translates to:
  /// **'Current Plan'**
  String get currentPlan;

  /// No description provided for @free.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get free;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @unlimitedGames.
  ///
  /// In en, this message translates to:
  /// **'Unlimited games'**
  String get unlimitedGames;

  /// No description provided for @singlePlayerToday.
  ///
  /// In en, this message translates to:
  /// **'Single player today'**
  String get singlePlayerToday;

  /// No description provided for @localMpToday.
  ///
  /// In en, this message translates to:
  /// **'Local MP today'**
  String get localMpToday;

  /// No description provided for @monthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get monthly;

  /// No description provided for @monthlyPrice.
  ///
  /// In en, this message translates to:
  /// **'\$4.99'**
  String get monthlyPrice;

  /// No description provided for @perMonth.
  ///
  /// In en, this message translates to:
  /// **'/month'**
  String get perMonth;

  /// No description provided for @yearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get yearly;

  /// No description provided for @yearlyPrice.
  ///
  /// In en, this message translates to:
  /// **'\$35.99'**
  String get yearlyPrice;

  /// No description provided for @perYear.
  ///
  /// In en, this message translates to:
  /// **'/year'**
  String get perYear;

  /// No description provided for @save40.
  ///
  /// In en, this message translates to:
  /// **'SAVE 40%'**
  String get save40;

  /// No description provided for @unlimitedSinglePlayerGames.
  ///
  /// In en, this message translates to:
  /// **'Unlimited single player games'**
  String get unlimitedSinglePlayerGames;

  /// No description provided for @unlimitedLocalMultiplayerGames.
  ///
  /// In en, this message translates to:
  /// **'Unlimited local multiplayer games'**
  String get unlimitedLocalMultiplayerGames;

  /// No description provided for @accessOnlineMultiplayer.
  ///
  /// In en, this message translates to:
  /// **'Access to online multiplayer'**
  String get accessOnlineMultiplayer;

  /// No description provided for @trialEnded.
  ///
  /// In en, this message translates to:
  /// **'Your Free Trial Has Ended'**
  String get trialEnded;

  /// No description provided for @premiumFeature.
  ///
  /// In en, this message translates to:
  /// **'Premium Feature'**
  String get premiumFeature;

  /// No description provided for @reachedYourLimit.
  ///
  /// In en, this message translates to:
  /// **'You\'ve Reached Your Limit!'**
  String get reachedYourLimit;

  /// No description provided for @subscribeMessage.
  ///
  /// In en, this message translates to:
  /// **'Subscribe to keep enjoying unlimited games and all premium features'**
  String get subscribeMessage;

  /// No description provided for @onlineRequiresPremium.
  ///
  /// In en, this message translates to:
  /// **'Online multiplayer requires a Premium subscription'**
  String get onlineRequiresPremium;

  /// No description provided for @upgradeToPremiumToKeepPlaying.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Premium to keep playing'**
  String get upgradeToPremiumToKeepPlaying;

  /// No description provided for @unlimitedSinglePlayer.
  ///
  /// In en, this message translates to:
  /// **'Unlimited single player games'**
  String get unlimitedSinglePlayer;

  /// No description provided for @unlimitedLocalMultiplayer.
  ///
  /// In en, this message translates to:
  /// **'Unlimited local multiplayer'**
  String get unlimitedLocalMultiplayer;

  /// No description provided for @onlineMultiplayerAccess.
  ///
  /// In en, this message translates to:
  /// **'Online multiplayer access'**
  String get onlineMultiplayerAccess;

  /// No description provided for @adFreeExperience.
  ///
  /// In en, this message translates to:
  /// **'Ad-free experience'**
  String get adFreeExperience;

  /// No description provided for @getYearly.
  ///
  /// In en, this message translates to:
  /// **'Get Yearly – \$35.99/year'**
  String get getYearly;

  /// No description provided for @getMonthly.
  ///
  /// In en, this message translates to:
  /// **'Get Monthly – \$4.99/month'**
  String get getMonthly;

  /// No description provided for @restorePurchase.
  ///
  /// In en, this message translates to:
  /// **'Restore Purchase'**
  String get restorePurchase;

  /// No description provided for @cancelAnytime.
  ///
  /// In en, this message translates to:
  /// **'Cancel anytime. Terms & Privacy apply.'**
  String get cancelAnytime;

  /// No description provided for @perfect.
  ///
  /// In en, this message translates to:
  /// **'Perfect!'**
  String get perfect;

  /// No description provided for @wellDone.
  ///
  /// In en, this message translates to:
  /// **'Well Done!'**
  String get wellDone;

  /// No description provided for @niceTry.
  ///
  /// In en, this message translates to:
  /// **'Nice Try!'**
  String get niceTry;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @gameplay.
  ///
  /// In en, this message translates to:
  /// **'Gameplay'**
  String get gameplay;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @displayName.
  ///
  /// In en, this message translates to:
  /// **'Display Name'**
  String get displayName;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @signOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOutTitle;

  /// No description provided for @signOutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out?'**
  String get signOutConfirm;

  /// No description provided for @manageSubscription.
  ///
  /// In en, this message translates to:
  /// **'Manage Subscription'**
  String get manageSubscription;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming Soon'**
  String get comingSoon;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @nameUpdated.
  ///
  /// In en, this message translates to:
  /// **'Name updated'**
  String get nameUpdated;

  /// No description provided for @failedToUpdateName.
  ///
  /// In en, this message translates to:
  /// **'Failed to update name'**
  String get failedToUpdateName;

  /// No description provided for @noActivePurchasesFound.
  ///
  /// In en, this message translates to:
  /// **'No active purchases found.'**
  String get noActivePurchasesFound;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @yourNameHint.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get yourNameHint;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @cardTiming.
  ///
  /// In en, this message translates to:
  /// **'Card Timing'**
  String get cardTiming;

  /// No description provided for @delayAfterFirstCard.
  ///
  /// In en, this message translates to:
  /// **'Delay after 1st card'**
  String get delayAfterFirstCard;

  /// No description provided for @delayAfterMismatch.
  ///
  /// In en, this message translates to:
  /// **'Delay after mismatch'**
  String get delayAfterMismatch;

  /// No description provided for @delayAfterFirstCardDescription.
  ///
  /// In en, this message translates to:
  /// **'How long you must wait after tapping the first card before you can tap a second. The sound keeps playing regardless — this only controls when your next tap is accepted.'**
  String get delayAfterFirstCardDescription;

  /// No description provided for @delayAfterMismatchDescription.
  ///
  /// In en, this message translates to:
  /// **'Minimum time you must wait after a mismatch before tapping again. The unmatched cards stay visible and flip back on their own at 2.1 seconds if you haven\'t tapped yet.'**
  String get delayAfterMismatchDescription;

  /// No description provided for @gotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotIt;

  /// No description provided for @authSignUpFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign up failed. Please try again.'**
  String get authSignUpFailed;

  /// No description provided for @authUnexpectedError.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred.'**
  String get authUnexpectedError;

  /// No description provided for @authSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign in failed. Please try again.'**
  String get authSignInFailed;

  /// No description provided for @authSignInCancelled.
  ///
  /// In en, this message translates to:
  /// **'Sign-in cancelled.'**
  String get authSignInCancelled;

  /// No description provided for @authGoogleNoIdToken.
  ///
  /// In en, this message translates to:
  /// **'Google Sign-In failed: no ID token.'**
  String get authGoogleNoIdToken;

  /// No description provided for @authGoogleFailed.
  ///
  /// In en, this message translates to:
  /// **'Google Sign-In failed. Please try again.'**
  String get authGoogleFailed;

  /// No description provided for @authGoogleError.
  ///
  /// In en, this message translates to:
  /// **'Google Sign-In error: {error}'**
  String authGoogleError(String error);

  /// No description provided for @authAppleNoIdentityToken.
  ///
  /// In en, this message translates to:
  /// **'Apple Sign-In failed: no identity token.'**
  String get authAppleNoIdentityToken;

  /// No description provided for @authAppleFailed.
  ///
  /// In en, this message translates to:
  /// **'Apple Sign-In failed. Please try again.'**
  String get authAppleFailed;

  /// No description provided for @authAppleError.
  ///
  /// In en, this message translates to:
  /// **'Apple Sign-In error: {error}'**
  String authAppleError(String error);

  /// No description provided for @authInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid email or password.'**
  String get authInvalidCredentials;

  /// No description provided for @authEmailNotConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Please verify your email before signing in.'**
  String get authEmailNotConfirmed;

  /// No description provided for @authUserAlreadyRegistered.
  ///
  /// In en, this message translates to:
  /// **'An account with this email already exists.'**
  String get authUserAlreadyRegistered;

  /// No description provided for @authPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters.'**
  String get authPasswordTooShort;

  /// No description provided for @authInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address.'**
  String get authInvalidEmail;

  /// No description provided for @findOpponent.
  ///
  /// In en, this message translates to:
  /// **'Find Opponent'**
  String get findOpponent;

  /// No description provided for @findOpponentDescription.
  ///
  /// In en, this message translates to:
  /// **'Match with a random player'**
  String get findOpponentDescription;

  /// No description provided for @searching.
  ///
  /// In en, this message translates to:
  /// **'Searching...'**
  String get searching;

  /// No description provided for @opponentFound.
  ///
  /// In en, this message translates to:
  /// **'Opponent found!'**
  String get opponentFound;

  /// No description provided for @cancelSearch.
  ///
  /// In en, this message translates to:
  /// **'Cancel Search'**
  String get cancelSearch;

  /// No description provided for @inviteFriend.
  ///
  /// In en, this message translates to:
  /// **'Invite a Friend'**
  String get inviteFriend;

  /// No description provided for @inviteFriendDescription.
  ///
  /// In en, this message translates to:
  /// **'Share a code with someone'**
  String get inviteFriendDescription;

  /// No description provided for @joinWithCode.
  ///
  /// In en, this message translates to:
  /// **'Join with Code'**
  String get joinWithCode;

  /// No description provided for @joinWithCodeDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter a friend\'s invite code'**
  String get joinWithCodeDescription;

  /// No description provided for @lobbyWaitingForOpponent.
  ///
  /// In en, this message translates to:
  /// **'Waiting for opponent...'**
  String get lobbyWaitingForOpponent;

  /// No description provided for @lobbyShareCode.
  ///
  /// In en, this message translates to:
  /// **'Share this code with a friend'**
  String get lobbyShareCode;

  /// No description provided for @lobbyTapToCopy.
  ///
  /// In en, this message translates to:
  /// **'Tap to copy'**
  String get lobbyTapToCopy;

  /// No description provided for @playWithFriendsRealtime.
  ///
  /// In en, this message translates to:
  /// **'Play with friends in real-time'**
  String get playWithFriendsRealtime;

  /// No description provided for @createPrivateGame.
  ///
  /// In en, this message translates to:
  /// **'Create Private Game'**
  String get createPrivateGame;

  /// No description provided for @startNewGameInviteFriend.
  ///
  /// In en, this message translates to:
  /// **'Start a new game and invite a friend'**
  String get startNewGameInviteFriend;

  /// No description provided for @joinPrivateGame.
  ///
  /// In en, this message translates to:
  /// **'Join Private Game'**
  String get joinPrivateGame;

  /// No description provided for @enterCodeToJoinFriend.
  ///
  /// In en, this message translates to:
  /// **'Enter a code to join your friend'**
  String get enterCodeToJoinFriend;

  /// No description provided for @searchingForPlayers.
  ///
  /// In en, this message translates to:
  /// **'Searching for available players...'**
  String get searchingForPlayers;

  /// No description provided for @noPlayersFoundCreateGame.
  ///
  /// In en, this message translates to:
  /// **'No players found. Create a game and wait for someone to join!'**
  String get noPlayersFoundCreateGame;

  /// No description provided for @lookingForOpponents.
  ///
  /// In en, this message translates to:
  /// **'Looking for opponents...'**
  String get lookingForOpponents;

  /// No description provided for @gridSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Grid Size'**
  String get gridSizeLabel;

  /// No description provided for @createAndWaitForOpponent.
  ///
  /// In en, this message translates to:
  /// **'Create & Wait for Opponent'**
  String get createAndWaitForOpponent;

  /// No description provided for @searchAgain.
  ///
  /// In en, this message translates to:
  /// **'Search Again'**
  String get searchAgain;

  /// No description provided for @setupGameInviteFriend.
  ///
  /// In en, this message translates to:
  /// **'Set up the game and invite a friend'**
  String get setupGameInviteFriend;

  /// No description provided for @inviteCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Invite Code'**
  String get inviteCodeLabel;

  /// No description provided for @someoneWillJoinSoon.
  ///
  /// In en, this message translates to:
  /// **'Someone will join your game soon'**
  String get someoneWillJoinSoon;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @publicGame.
  ///
  /// In en, this message translates to:
  /// **'Public Game'**
  String get publicGame;

  /// No description provided for @anyoneCanJoinThisGame.
  ///
  /// In en, this message translates to:
  /// **'Anyone can find and join this game'**
  String get anyoneCanJoinThisGame;

  /// No description provided for @opponentJoinedTitle.
  ///
  /// In en, this message translates to:
  /// **'Opponent Joined!'**
  String get opponentJoinedTitle;

  /// No description provided for @readyToPlay.
  ///
  /// In en, this message translates to:
  /// **'Ready to play'**
  String get readyToPlay;

  /// No description provided for @youFallbackName.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get youFallbackName;

  /// No description provided for @waitingForHostToStart.
  ///
  /// In en, this message translates to:
  /// **'Waiting for Host to Start the Game!'**
  String get waitingForHostToStart;

  /// No description provided for @joinedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'You\'ve joined successfully'**
  String get joinedSuccessfully;

  /// No description provided for @leave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leave;

  /// No description provided for @hostCancelledGame.
  ///
  /// In en, this message translates to:
  /// **'Host cancelled the game'**
  String get hostCancelledGame;

  /// No description provided for @failedToStartGame.
  ///
  /// In en, this message translates to:
  /// **'Failed to start game. Please try again.'**
  String get failedToStartGame;

  /// No description provided for @codeCopied.
  ///
  /// In en, this message translates to:
  /// **'Code copied!'**
  String get codeCopied;

  /// No description provided for @gameNotFoundCheckCode.
  ///
  /// In en, this message translates to:
  /// **'Game not found or already started. Check the code and try again.'**
  String get gameNotFoundCheckCode;

  /// No description provided for @connectionLost.
  ///
  /// In en, this message translates to:
  /// **'Connection lost'**
  String get connectionLost;

  /// No description provided for @opponentTimedOutMessage.
  ///
  /// In en, this message translates to:
  /// **'Your opponent hasn\'t made a move in 60 seconds. The game has been ended.'**
  String get opponentTimedOutMessage;

  /// No description provided for @enterTheCodeFromFriend.
  ///
  /// In en, this message translates to:
  /// **'Enter the code from your friend'**
  String get enterTheCodeFromFriend;

  /// No description provided for @turkce.
  ///
  /// In en, this message translates to:
  /// **'Türkçe'**
  String get turkce;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get languageSystem;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
