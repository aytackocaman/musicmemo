// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appTitle => 'Music Memo';

  @override
  String get matchTheSoundsToWin => 'Sesleri eşleştirerek kazan!';

  @override
  String get playGame => 'Oyuna Başla';

  @override
  String get subscription => 'Abonelik';

  @override
  String get statistics => 'İstatistikler';

  @override
  String get highScore => 'En Yüksek Skor';

  @override
  String get welcome => 'Hoş Geldiniz!';

  @override
  String get welcomeBack => 'Tekrar Hoş Geldiniz';

  @override
  String get createAccountSubtitle =>
      'Oynamaya başlamak için hesap oluşturun veya giriş yapın';

  @override
  String get signInSubtitle => 'Oynamaya devam etmek için giriş yapın';

  @override
  String get byContinuing => 'Devam ederek şunları kabul etmiş olursunuz:';

  @override
  String get termsOfService => 'Kullanım Koşulları';

  @override
  String get andSeparator => ' ve ';

  @override
  String get privacyPolicy => 'Gizlilik Politikası';

  @override
  String get pleaseEnterEmail => 'Lütfen e-posta adresinizi girin';

  @override
  String get pleaseEnterValidEmail => 'Lütfen geçerli bir e-posta adresi girin';

  @override
  String get pleaseEnterPassword => 'Lütfen şifrenizi girin';

  @override
  String get passwordMinLength => 'Şifre en az 6 karakter olmalıdır';

  @override
  String get pleaseWait => 'Lütfen bekleyin...';

  @override
  String get createAccount => 'Hesap Oluştur';

  @override
  String get signIn => 'Giriş Yap';

  @override
  String get signUp => 'Kayıt Ol';

  @override
  String get forgotPassword => 'Şifremi Unuttum?';

  @override
  String get otherSignInOptions => 'Diğer giriş seçenekleri';

  @override
  String get signInWithGoogle => 'Google ile giriş yap';

  @override
  String get signInWithApple => 'Apple ile giriş yap';

  @override
  String get signInWithEmail => 'E-posta ile giriş yap';

  @override
  String get displayNameOptional => 'Görünen Ad (isteğe bağlı)';

  @override
  String get email => 'E-posta';

  @override
  String get password => 'Şifre';

  @override
  String get enterName => 'Ad girin';

  @override
  String get enterEmailToReset =>
      'Şifrenizi sıfırlamak için e-posta adresinizi girin.';

  @override
  String get passwordResetSent => 'Şifre sıfırlama e-postası gönderildi!';

  @override
  String get selectGameMode => 'Oyun Modu Seçin';

  @override
  String get chooseHowToPlay => 'Nasıl oynamak istediğinizi seçin';

  @override
  String get singlePlayer => 'Tek Oyunculu';

  @override
  String get singlePlayerDescription => 'Tek başına oyna ve rekorunu kır';

  @override
  String get localMultiplayer => 'Yerel Çok Oyunculu';

  @override
  String get localMultiplayerDescription => 'Bu cihazda bir arkadaşınla oyna';

  @override
  String get onlineMultiplayer => 'Çevrimiçi Çok Oyunculu';

  @override
  String get onlineMultiplayerDescription =>
      'Dünya genelinde oyunculara meydan oku';

  @override
  String get premiumOnly => 'Yalnızca Premium';

  @override
  String get premium => 'Premium';

  @override
  String get premiumOn => 'Premium AÇIK';

  @override
  String get premiumOff => 'Premium KAPALI';

  @override
  String freeGamesLeftToday(int remaining, int limit) {
    return 'Bugün $remaining/$limit ücretsiz oyun hakkı';
  }

  @override
  String get selectCategory => 'Kategori Seçin';

  @override
  String get whatKindOfSounds => 'Ne tür sesler eşleştirmek istiyorsunuz?';

  @override
  String get music => 'Müzik';

  @override
  String get musicDescription => 'Şarkıları, ritmleri ve melodileri eşleştir';

  @override
  String get earTraining => 'Kulak Eğitimi';

  @override
  String get earTrainingDescription => 'Aralıklar, akorlar ve diziler';

  @override
  String get forKids => 'Çocuklar İçin';

  @override
  String get forKidsDescription => 'Hayvanlar, oyuncaklar ve eğlenceli sesler';

  @override
  String get funnyMemes => 'Komik Memeler';

  @override
  String get funnyMemesDescription => 'Viral sesler ve internet klasikleri';

  @override
  String get soon => 'Yakında';

  @override
  String get browseByFeel => 'Hissiyata Göre';

  @override
  String get collections => 'Koleksiyonlar';

  @override
  String get searchCollections => 'Koleksiyon ara...';

  @override
  String noCollectionsMatch(String query) {
    return '\"$query\" ile eşleşen koleksiyon yok';
  }

  @override
  String get noCategoriesAvailable => 'Kategori bulunamadı';

  @override
  String trackCount(int count) {
    return '$count parça';
  }

  @override
  String get pro => 'PRO';

  @override
  String searchTag(String tagLabel) {
    return '$tagLabel ara...';
  }

  @override
  String get noResults => 'Sonuç yok';

  @override
  String premiumCategoryMessage(String name) {
    return '$name Premium bir kategoridir. Kilidi açmak için Premium\'a yükseltin.';
  }

  @override
  String get tagMood => 'Ruh Hali';

  @override
  String get tagGenre => 'Tür';

  @override
  String get tagMovement => 'Hareket';

  @override
  String get tagTheme => 'Tema';

  @override
  String get selectGridSize => 'Izgara Boyutu Seçin';

  @override
  String get largerGridsMoreChallenging => 'Büyük ızgaralar daha zorlayıcıdır';

  @override
  String get debug => 'Hata Ayıklama';

  @override
  String get easy => 'Kolay';

  @override
  String get medium => 'Orta';

  @override
  String get hard => 'Zor';

  @override
  String get test => 'Test';

  @override
  String cardsPairs(int cards, int pairs) {
    return '$cards kart, $pairs çift';
  }

  @override
  String get pleaseSelectGameModeAndCategory =>
      'Lütfen bir oyun modu ve kategori seçin';

  @override
  String get preparingGame => 'Oyun Hazırlanıyor';

  @override
  String get fetchingSoundList => 'Ses listesi alınıyor...';

  @override
  String get downloadingSounds => 'Sesler indiriliyor...';

  @override
  String downloadingSoundsProgress(int completed, int total) {
    return 'Sesler indiriliyor ($completed/$total)';
  }

  @override
  String get failedToLoadSounds => 'Sesler yüklenemedi';

  @override
  String get retry => 'Tekrar Dene';

  @override
  String get goBack => 'Geri Dön';

  @override
  String get playerSetup => 'Oyuncu Ayarları';

  @override
  String get enterNamesAndPickColors => 'Adları girin ve renk seçin';

  @override
  String get vs => 'VS';

  @override
  String get startGame => 'Oyunu Başlat';

  @override
  String playerNumber(int number) {
    return 'Oyuncu $number';
  }

  @override
  String get chooseColor => 'Renk seçin';

  @override
  String get score => 'Skor';

  @override
  String get moves => 'Hamle';

  @override
  String get time => 'Süre';

  @override
  String get pairs => 'Çift';

  @override
  String get gamePaused => 'Oyun Duraklatıldı';

  @override
  String get tapToResume => 'Devam etmek için dokunun';

  @override
  String get resume => 'Devam Et';

  @override
  String get quitGame => 'Oyundan Çık';

  @override
  String get goHomeTitle => 'Ana Sayfaya Dön?';

  @override
  String get progressWillBeLost => 'İlerlemeniz kaybolacak.';

  @override
  String get goHome => 'Ana Sayfa';

  @override
  String get yourTurn => 'Senin Sıran';

  @override
  String get opponentsTurn => 'Rakibin Sırası';

  @override
  String get itsATie => 'Berabere!';

  @override
  String playerWins(String name) {
    return '$name Kazandı!';
  }

  @override
  String get greatMatchBothPlayers => 'Harika maç, iki oyuncu da!';

  @override
  String get congratulations => 'Tebrikler!';

  @override
  String get playAgain => 'Tekrar Oyna';

  @override
  String get changeCategory => 'Kategori Değiştir';

  @override
  String get upgradeToPremium => 'Premium\'a Yükselt';

  @override
  String get home => 'Ana Sayfa';

  @override
  String freeGamesLeftCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Bugün $count ücretsiz oyun hakkı kaldı',
      one: 'Bugün 1 ücretsiz oyun hakkı kaldı',
    );
    return '$_temp0';
  }

  @override
  String get noFreeGamesLeft =>
      'Ücretsiz oyun hakkı kalmadı. Sabah 3:00\'te yenilenir';

  @override
  String get onlineMultiplayerTitle => 'Çevrimiçi Çok Oyunculu';

  @override
  String get createOrJoinGame => 'Oyun oluştur veya kodla katıl';

  @override
  String get yourName => 'Adınız';

  @override
  String get enterYourName => 'Adınızı girin';

  @override
  String get createGame => 'Oyun Oluştur';

  @override
  String get getCodeToShare => 'Arkadaşınızla paylaşmak için kod alın';

  @override
  String get or => 'VEYA';

  @override
  String get joinGame => 'Oyuna Katıl';

  @override
  String get enterCodeFromFriend => 'Arkadaşınızdan aldığınız kodu girin';

  @override
  String get codePlaceholder => '000000';

  @override
  String get waitingForOpponent => 'Rakip bekleniyor...';

  @override
  String get shareCodeWithFriend => 'Bu kodu bir arkadaşınızla paylaşın';

  @override
  String get tapToCopy => 'Kopyalamak için dokunun';

  @override
  String get pleaseEnterYourName => 'Lütfen adınızı girin';

  @override
  String get pleaseEnterInviteCode => 'Lütfen davet kodunu girin';

  @override
  String get gameNotFound => 'Oyun bulunamadı veya zaten başlamış';

  @override
  String get inviteCodeCopied => 'Davet kodu kopyalandı!';

  @override
  String get failedToCreateGame =>
      'Oyun oluşturulamadı. Lütfen tekrar deneyin.';

  @override
  String get pleaseEnterValidCode => 'Lütfen geçerli bir 6 haneli kod girin';

  @override
  String get opponentLeftTheGame => 'Rakip oyundan ayrıldı';

  @override
  String get settingUpGame => 'Oyun kuruluyor...';

  @override
  String get waitingForHost => 'Ev sahibi bekleniyor...';

  @override
  String get live => 'CANLI';

  @override
  String get reconnecting => 'Yeniden bağlanılıyor...';

  @override
  String get offline => 'Çevrimdışı';

  @override
  String get opponent => 'Rakip';

  @override
  String get forfeitMessage => 'Ayrılırsanız bu oyunu kaybedersiniz.';

  @override
  String get opponentLeftTitle => 'Rakip Ayrıldı';

  @override
  String get opponentLeftMessage =>
      'Rakibiniz oyundan ayrıldı. Siz kazandınız!';

  @override
  String get opponentTimedOut => 'Rakip Zaman Aşımı';

  @override
  String get opponentLeftTheRoom => 'Rakip odadan ayrıldı';

  @override
  String get opponentDeclinedRematch => 'Rakip rövanşı reddetti';

  @override
  String get youWin => 'Kazandın!';

  @override
  String get youLost => 'Kaybettin';

  @override
  String get greatMatch => 'Harika maç!';

  @override
  String get betterLuckNextTime => 'Bir dahaki sefere!';

  @override
  String get rematch => 'Rövanş';

  @override
  String get findNewOpponent => 'Yeni Rakip Bul';

  @override
  String get waitingForOpponentEllipsis => 'Rakip bekleniyor...';

  @override
  String get cancel => 'İptal';

  @override
  String get acceptRematch => 'Rövanşı Kabul Et!';

  @override
  String get decline => 'Reddet';

  @override
  String get startingRematch => 'Rövanş başlıyor...';

  @override
  String get statisticsTitle => 'İstatistikler';

  @override
  String get byGameMode => 'Oyun Moduna Göre';

  @override
  String get overallStats => 'Genel İstatistikler';

  @override
  String get games => 'Oyun';

  @override
  String get wins => 'Galibiyet';

  @override
  String get winRate => 'Kazanma Oranı';

  @override
  String get twoPlayerLocal => 'İki Oyunculu Yerel';

  @override
  String get twoPlayerOnline => 'İki Oyunculu Çevrimiçi';

  @override
  String gamesWinRate(int games, String winRate) {
    return '$games oyun • %$winRate kazanma oranı';
  }

  @override
  String get subscriptionTitle => 'Abonelik';

  @override
  String get currentPlan => 'Mevcut Plan';

  @override
  String get free => 'Ücretsiz';

  @override
  String get active => 'Aktif';

  @override
  String get unlimitedGames => 'Sınırsız oyun';

  @override
  String get singlePlayerToday => 'Bugün tek oyunculu';

  @override
  String get localMpToday => 'Bugün yerel çok oyunculu';

  @override
  String get monthly => 'Aylık';

  @override
  String get monthlyPrice => '₺49,99';

  @override
  String get perMonth => '/ay';

  @override
  String get yearly => 'Yıllık';

  @override
  String get yearlyPrice => '₺349,99';

  @override
  String get perYear => '/yıl';

  @override
  String get save40 => '%40 TASARRUF';

  @override
  String get unlimitedSinglePlayerGames => 'Sınırsız tek oyunculu oyun';

  @override
  String get unlimitedLocalMultiplayerGames =>
      'Sınırsız yerel çok oyunculu oyun';

  @override
  String get accessOnlineMultiplayer => 'Çevrimiçi çok oyunculu erişim';

  @override
  String get trialEnded => 'Ücretsiz Denemeniz Sona Erdi';

  @override
  String get premiumFeature => 'Premium Özellik';

  @override
  String get reachedYourLimit => 'Limitinize Ulaştınız!';

  @override
  String get subscribeMessage =>
      'Sınırsız oyun ve tüm premium özelliklerden yararlanmaya devam etmek için abone olun';

  @override
  String get onlineRequiresPremium =>
      'Çevrimiçi çok oyunculu için Premium abonelik gereklidir';

  @override
  String get upgradeToPremiumToKeepPlaying =>
      'Oynamaya devam etmek için Premium\'a yükseltin';

  @override
  String get unlimitedSinglePlayer => 'Sınırsız tek oyunculu oyun';

  @override
  String get unlimitedLocalMultiplayer => 'Sınırsız yerel çok oyunculu';

  @override
  String get onlineMultiplayerAccess => 'Çevrimiçi çok oyunculu erişim';

  @override
  String get adFreeExperience => 'Reklamsız deneyim';

  @override
  String get getYearly => 'Yıllık Al – ₺349,99/yıl';

  @override
  String get getMonthly => 'Aylık Al – ₺49,99/ay';

  @override
  String get restorePurchase => 'Satın Alımı Geri Yükle';

  @override
  String get cancelAnytime =>
      'İstediğiniz zaman iptal edin. Koşullar ve Gizlilik geçerlidir.';

  @override
  String get perfect => 'Mükemmel!';

  @override
  String get wellDone => 'Harika!';

  @override
  String get niceTry => 'İyi Deneme!';

  @override
  String get settings => 'Ayarlar';

  @override
  String get accentColor => 'Vurgu Rengi';

  @override
  String get blue => 'Mavi';

  @override
  String get purple => 'Mor';

  @override
  String get red => 'Kırmızı';

  @override
  String get appearance => 'Görünüm';

  @override
  String get gameplay => 'Oynanış';

  @override
  String get hapticFeedback => 'Dokunsal Geri Bildirim';

  @override
  String get account => 'Hesap';

  @override
  String get displayName => 'Görünen Ad';

  @override
  String get signOut => 'Çıkış Yap';

  @override
  String get signOutTitle => 'Çıkış Yap';

  @override
  String get signOutConfirm => 'Çıkış yapmak istediğinize emin misiniz?';

  @override
  String get manageSubscription => 'Aboneliği Yönet';

  @override
  String get language => 'Dil';

  @override
  String get comingSoon => 'Çok Yakında';

  @override
  String get about => 'Hakkında';

  @override
  String get version => 'Sürüm';

  @override
  String get nameUpdated => 'Ad güncellendi';

  @override
  String get failedToUpdateName => 'Ad güncellenemedi';

  @override
  String get noActivePurchasesFound => 'Aktif satın alım bulunamadı.';

  @override
  String get purchaseSuccessful => 'Premium\'a hoş geldiniz!';

  @override
  String get purchaseFailed => 'Satın alma tamamlanamadı.';

  @override
  String get purchaseRestored => 'Satın alma başarıyla geri yüklendi!';

  @override
  String get loadingPurchases => 'Yükleniyor...';

  @override
  String get system => 'Sistem';

  @override
  String get light => 'Açık';

  @override
  String get dark => 'Koyu';

  @override
  String get yourNameHint => 'Adınız';

  @override
  String get save => 'Kaydet';

  @override
  String get confirm => 'Onayla';

  @override
  String get cardTiming => 'Kart Zamanlamaları';

  @override
  String get delayAfterFirstCard => '1. karttan sonra bekleme';

  @override
  String get delayAfterMismatch => 'Eşleşmeme sonrası bekleme';

  @override
  String get delayAfterFirstCardDescription =>
      'İlk karta dokunduktan sonra ikinci karta dokunmadan önce ne kadar beklemeniz gerektiği. Ses ne olursa olsun çalmaya devam eder — bu yalnızca bir sonraki dokunmanızın ne zaman kabul edileceğini kontrol eder.';

  @override
  String get delayAfterMismatchDescription =>
      'Bir eşleşmemeden sonra tekrar dokunmadan önce beklemeniz gereken minimum süre. Eşleşmeyen kartlar görünür kalır ve henüz dokunmadıysanız 2,1 saniyede kendiliğinden geri döner.';

  @override
  String get gotIt => 'Anlaşıldı';

  @override
  String get authSignUpFailed => 'Kayıt başarısız. Lütfen tekrar deneyin.';

  @override
  String get authUnexpectedError => 'Beklenmeyen bir hata oluştu.';

  @override
  String get authSignInFailed => 'Giriş başarısız. Lütfen tekrar deneyin.';

  @override
  String get authSignInCancelled => 'Giriş iptal edildi.';

  @override
  String get authGoogleNoIdToken =>
      'Google girişi başarısız: ID token alınamadı.';

  @override
  String get authGoogleFailed =>
      'Google girişi başarısız. Lütfen tekrar deneyin.';

  @override
  String authGoogleError(String error) {
    return 'Google giriş hatası: $error';
  }

  @override
  String get authAppleNoIdentityToken =>
      'Apple girişi başarısız: kimlik tokenı alınamadı.';

  @override
  String get authAppleFailed =>
      'Apple girişi başarısız. Lütfen tekrar deneyin.';

  @override
  String authAppleError(String error) {
    return 'Apple giriş hatası: $error';
  }

  @override
  String get authInvalidCredentials => 'Geçersiz e-posta veya şifre.';

  @override
  String get authEmailNotConfirmed =>
      'Lütfen giriş yapmadan önce e-postanızı doğrulayın.';

  @override
  String get authUserAlreadyRegistered =>
      'Bu e-posta adresiyle zaten bir hesap mevcut.';

  @override
  String get authPasswordTooShort => 'Şifre en az 6 karakter olmalıdır.';

  @override
  String get authInvalidEmail => 'Lütfen geçerli bir e-posta adresi girin.';

  @override
  String get findOpponent => 'Rakip Bul';

  @override
  String get findOpponentDescription => 'Rastgele bir oyuncuyla eşleş';

  @override
  String get searching => 'Aranıyor...';

  @override
  String get opponentFound => 'Rakip bulundu!';

  @override
  String get cancelSearch => 'Aramayı İptal Et';

  @override
  String get inviteFriend => 'Arkadaş Davet Et';

  @override
  String get inviteFriendDescription => 'Biriyle kod paylaş';

  @override
  String get joinWithCode => 'Kodla Katıl';

  @override
  String get joinWithCodeDescription => 'Arkadaşının davet kodunu gir';

  @override
  String get lobbyWaitingForOpponent => 'Rakip bekleniyor...';

  @override
  String get lobbyShareCode => 'Bu kodu bir arkadaşınızla paylaşın';

  @override
  String get lobbyTapToCopy => 'Kopyalamak için dokunun';

  @override
  String get playWithFriendsRealtime => 'Arkadaşlarınla gerçek zamanlı oyna';

  @override
  String get createPrivateGame => 'Özel Oyun Oluştur';

  @override
  String get startNewGameInviteFriend =>
      'Yeni oyun başlat ve arkadaşını davet et';

  @override
  String get joinPrivateGame => 'Özel Oyuna Katıl';

  @override
  String get enterCodeToJoinFriend => 'Arkadaşına katılmak için kod gir';

  @override
  String get searchingForPlayers => 'Uygun oyuncular aranıyor...';

  @override
  String get noPlayersFoundCreateGame =>
      'Oyuncu bulunamadı. Oyun oluştur ve birinin katılmasını bekle!';

  @override
  String get lookingForOpponents => 'Rakip aranıyor...';

  @override
  String get gridSizeLabel => 'Izgara Boyutu';

  @override
  String get createAndWaitForOpponent => 'Oluştur ve Rakip Bekle';

  @override
  String get searchAgain => 'Tekrar Ara';

  @override
  String get setupGameInviteFriend => 'Oyunu kur ve arkadaşını davet et';

  @override
  String get inviteCodeLabel => 'Davet Kodu';

  @override
  String get someoneWillJoinSoon => 'Birisi yakında oyununuza katılacak';

  @override
  String get copy => 'Kopyala';

  @override
  String get share => 'Paylaş';

  @override
  String get publicGame => 'Herkese Açık Oyun';

  @override
  String get anyoneCanJoinThisGame => 'Herkes bu oyunu bulup katılabilir';

  @override
  String get opponentJoinedTitle => 'Rakip Katıldı!';

  @override
  String get readyToPlay => 'Oynamaya hazır';

  @override
  String get youFallbackName => 'Sen';

  @override
  String get waitingForHostToStart =>
      'Ev Sahibinin Oyunu Başlatması Bekleniyor!';

  @override
  String get joinedSuccessfully => 'Başarıyla katıldınız';

  @override
  String get leave => 'Ayrıl';

  @override
  String get hostCancelledGame => 'Ev sahibi oyunu iptal etti';

  @override
  String get failedToStartGame => 'Oyun başlatılamadı. Lütfen tekrar deneyin.';

  @override
  String get codeCopied => 'Kod kopyalandı!';

  @override
  String get gameNotFoundCheckCode =>
      'Oyun bulunamadı veya zaten başlamış. Kodu kontrol edip tekrar deneyin.';

  @override
  String get connectionLost => 'Bağlantı kesildi';

  @override
  String get opponentTimedOutMessage =>
      'Rakibiniz 60 saniyedir hamle yapmadı. Oyun sonlandırıldı.';

  @override
  String get enterTheCodeFromFriend => 'Arkadaşınızdan aldığınız kodu girin';

  @override
  String get turkce => 'Türkçe';

  @override
  String get english => 'English';

  @override
  String get languageSystem => 'Sistem';
}
